#!/bin/bash
# init-local.sh — bootstraps the complete local development environment
# Can be run from any directory
# Usage: bash /path/to/data-platform-infra/scripts/init-local.sh

set -e  # exit on any error

# ─── resolve paths relative to this script's location ────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
WORKFLOWS_DIR="$(dirname "$INFRA_DIR")/data-platform-workflows"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${GREEN}[init]${NC} $1"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $1"; }
error() { echo -e "${RED}[error]${NC} $1"; exit 1; }

# ─── 1. verify prerequisites ──────────────────────────────────────────────────

log "Checking prerequisites..."

command -v docker   >/dev/null 2>&1 || error "Docker is not installed"
command -v k3d      >/dev/null 2>&1 || error "k3d is not installed"
command -v kubectl  >/dev/null 2>&1 || error "kubectl is not installed"
command -v helm     >/dev/null 2>&1 || error "helm is not installed"
command -v mc       >/dev/null 2>&1 || error "mc (MinIO client) is not installed"

docker info >/dev/null 2>&1 || error "Docker Desktop is not running"

log "Prerequisites OK"

# ─── 2. k3d cluster ───────────────────────────────────────────────────────────

if k3d cluster list | grep -q "data-platform"; then
    log "Cluster 'data-platform' already exists — skipping creation"
else
    log "Creating k3d cluster..."
    k3d cluster create data-platform \
        --agents 1 \
        --port "8080:80@loadbalancer"
    log "Cluster created"
fi

# ─── 3. Argo Workflows ────────────────────────────────────────────────────────

log "Installing Argo Workflows..."

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1
helm repo update >/dev/null 2>&1

kubectl create namespace argo --dry-run=client -o yaml | kubectl apply -f -

if helm status argo-workflows -n argo >/dev/null 2>&1; then
    log "Argo Workflows already installed — running upgrade..."
    helm upgrade argo-workflows argo/argo-workflows \
        --namespace argo \
        --set "server.authModes={server}" \
        --set workflow.serviceAccount.create=true \
        --values "${INFRA_DIR}/modules/argo/values.yaml" 2>/dev/null || \
    helm upgrade argo-workflows argo/argo-workflows \
        --namespace argo \
        --set "server.authModes={server}" \
        --set workflow.serviceAccount.create=true
else
    helm install argo-workflows argo/argo-workflows \
        --namespace argo \
        --set "server.authModes={server}" \
        --set workflow.serviceAccount.create=true
fi

log "Argo Workflows ready"

# ─── 4. Kubernetes resources ──────────────────────────────────────────────────

log "Applying Kubernetes resources..."

kubectl apply -f "${WORKFLOWS_DIR}/rbac/workflow-rbac.yaml"
kubectl apply -f "${WORKFLOWS_DIR}/minio/minio.yaml"
kubectl apply -f "${WORKFLOWS_DIR}/simulation-api/simulation-api.yaml"

log "Resources applied"

# ─── 5. MinIO secret ──────────────────────────────────────────────────────────

log "Configuring MinIO secret..."

kubectl create secret generic minio-credentials \
    --from-literal=access_key=minioadmin \
    --from-literal=secret_key=minioadmin \
    --namespace argo \
    --dry-run=client -o yaml | kubectl apply -f -

log "Secret configured"

# ─── 6. wait for pods to be ready ─────────────────────────────────────────────

log "Waiting for pods to be Running..."

kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=argo-workflows-server \
    -n argo --timeout=120s >/dev/null 2>&1 || \
kubectl wait --for=condition=ready pod \
    -l app=argo-workflows-server \
    -n argo --timeout=120s >/dev/null 2>&1 || \
warn "Timeout waiting for argo-server — check with: kubectl get pods -n argo"

kubectl wait --for=condition=ready pod \
    -l app=minio \
    -n argo --timeout=60s >/dev/null 2>&1 || \
warn "Timeout waiting for minio — check with: kubectl get pods -n argo"

kubectl wait --for=condition=ready pod \
    -l app=simulation-api \
    -n argo --timeout=60s >/dev/null 2>&1 || \
warn "Timeout waiting for simulation-api — check with: kubectl get pods -n argo"

# ─── 7. import Docker images into the cluster ─────────────────────────────────

log "Importing Docker images into the cluster..."

for image in python-ingestor:local simulation-api:local data-quality:local; do
    if docker image inspect "$image" >/dev/null 2>&1; then
        log "Importing $image..."
        k3d image import "$image" -c data-platform
    else
        warn "Image $image not found in local Docker — rebuild with: docker build"
    fi
done

# ─── 8. MinIO buckets ─────────────────────────────────────────────────────────

log "Configuring MinIO buckets..."

# temporary port-forward for mc
kubectl -n argo port-forward deployment/minio 9000:9000 &
PF_PID=$!
sleep 3  # wait for port-forward to be ready

mc alias set local http://localhost:9000 minioadmin minioadmin >/dev/null 2>&1

mc mb --ignore-existing local/raw
mc mb --ignore-existing local/curated
mc mb --ignore-existing local/athena-results

kill $PF_PID 2>/dev/null || true

log "Buckets created: raw, curated, athena-results"

# ─── 9. apply CronWorkflow ────────────────────────────────────────────────────

log "Applying CronWorkflow..."
kubectl apply -f "${WORKFLOWS_DIR}/crons/daily-traffic.yaml"

# ─── 10. summary ──────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN} Local environment ready${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Running pods:"
kubectl get pods -n argo --no-headers | awk '{printf "  %-50s %s\n", $1, $3}'
echo ""
echo "Required port-forwards (run in separate terminals):"
echo "  kubectl -n argo port-forward deployment/argo-workflows-server 2746:2746"
echo "  kubectl -n argo port-forward deployment/minio 9000:9000"
echo "  kubectl -n argo port-forward deployment/minio 9001:9001"
echo ""
echo "Available UIs (after port-forwards):"
echo "  Argo UI:   http://localhost:2746"
echo "  MinIO UI:  http://localhost:9001  (minioadmin / minioadmin)"
echo ""
echo "Run DAG manually:"
echo "  argo submit ${WORKFLOWS_DIR}/pipelines/ingest-traffic-dag.yaml -n argo --watch"
echo ""
