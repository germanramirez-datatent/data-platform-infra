#!/bin/bash
# init-local.sh — levanta el entorno local completo desde cero
# Ejecutar desde la raíz del proyecto data-platform-infra/
# Uso: bash scripts/init-local.sh

set -e  # detener en cualquier error

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[init]${NC} $1"; }
warn() { echo -e "${YELLOW}[warn]${NC} $1"; }
error() { echo -e "${RED}[error]${NC} $1"; exit 1; }

# ─── 1. Verificar prerequisitos ───────────────────────────────────────────────

log "Verificando prerequisitos..."

command -v docker   >/dev/null 2>&1 || error "Docker no está instalado"
command -v k3d      >/dev/null 2>&1 || error "k3d no está instalado"
command -v kubectl  >/dev/null 2>&1 || error "kubectl no está instalado"
command -v helm     >/dev/null 2>&1 || error "helm no está instalado"
command -v mc       >/dev/null 2>&1 || error "mc (MinIO client) no está instalado"

docker info >/dev/null 2>&1 || error "Docker Desktop no está corriendo"

log "Prerequisitos OK"

# ─── 2. Cluster k3d ───────────────────────────────────────────────────────────

if k3d cluster list | grep -q "data-platform"; then
    log "Cluster 'data-platform' ya existe — saltando creación"
else
    log "Creando cluster k3d..."
    k3d cluster create data-platform \
        --agents 1 \
        --port "8080:80@loadbalancer"
    log "Cluster creado"
fi

# ─── 3. Argo Workflows ────────────────────────────────────────────────────────

log "Instalando Argo Workflows..."

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1
helm repo update >/dev/null 2>&1

kubectl create namespace argo --dry-run=client -o yaml | kubectl apply -f -

if helm status argo-workflows -n argo >/dev/null 2>&1; then
    log "Argo Workflows ya está instalado — ejecutando upgrade..."
    helm upgrade argo-workflows argo/argo-workflows \
        --namespace argo \
        --set "server.authModes={server}" \
        --set workflow.serviceAccount.create=true \
        --values ../data-platform-infra/modules/argo/values.yaml 2>/dev/null || \
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

log "Argo Workflows listo"

# ─── 4. Recursos de Kubernetes ────────────────────────────────────────────────

log "Aplicando recursos de Kubernetes..."

WORKFLOWS_DIR="../data-platform-workflows"

kubectl apply -f "${WORKFLOWS_DIR}/rbac/workflow-rbac.yaml"
kubectl apply -f "${WORKFLOWS_DIR}/minio/minio.yaml"
kubectl apply -f "${WORKFLOWS_DIR}/simulation-api/simulation-api.yaml"

log "Recursos aplicados"

# ─── 5. Secret de MinIO ───────────────────────────────────────────────────────

log "Configurando secret de MinIO..."

kubectl create secret generic minio-credentials \
    --from-literal=access_key=minioadmin \
    --from-literal=secret_key=minioadmin \
    --namespace argo \
    --dry-run=client -o yaml | kubectl apply -f -

log "Secret configurado"

# ─── 6. Esperar a que los pods estén listos ───────────────────────────────────

log "Esperando a que los pods estén Running..."

kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=argo-workflows-server \
    -n argo --timeout=120s >/dev/null 2>&1 || \
kubectl wait --for=condition=ready pod \
    -l app=argo-workflows-server \
    -n argo --timeout=120s >/dev/null 2>&1 || \
warn "Timeout esperando argo-server — verifica con: kubectl get pods -n argo"

kubectl wait --for=condition=ready pod \
    -l app=minio \
    -n argo --timeout=60s >/dev/null 2>&1 || \
warn "Timeout esperando minio — verifica con: kubectl get pods -n argo"

kubectl wait --for=condition=ready pod \
    -l app=simulation-api \
    -n argo --timeout=60s >/dev/null 2>&1 || \
warn "Timeout esperando simulation-api — verifica con: kubectl get pods -n argo"

# ─── 7. Importar imágenes Docker al cluster ───────────────────────────────────

log "Importando imágenes Docker al cluster..."

for image in python-ingestor:local simulation-api:local data-quality:local; do
    if docker image inspect "$image" >/dev/null 2>&1; then
        log "Importando $image..."
        k3d image import "$image" -c data-platform
    else
        warn "Imagen $image no encontrada en Docker local — reconstruye con: docker build"
    fi
done

# ─── 8. Buckets de MinIO ──────────────────────────────────────────────────────

log "Configurando buckets de MinIO..."

# port-forward temporal para mc
kubectl -n argo port-forward deployment/minio 9000:9000 &
PF_PID=$!
sleep 3  # esperar a que el port-forward esté listo

mc alias set local http://localhost:9000 minioadmin minioadmin >/dev/null 2>&1

mc mb --ignore-existing local/raw
mc mb --ignore-existing local/curated
mc mb --ignore-existing local/athena-results

kill $PF_PID 2>/dev/null || true

log "Buckets creados:"
echo "  raw, curated, athena-results"

# ─── 9. Aplicar CronWorkflow ──────────────────────────────────────────────────

log "Aplicando CronWorkflow..."
kubectl apply -f "${WORKFLOWS_DIR}/crons/daily-traffic.yaml"

# ─── 10. Resumen ──────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN} Entorno local listo${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Pods corriendo:"
kubectl get pods -n argo --no-headers | awk '{printf "  %-50s %s\n", $1, $3}'
echo ""
echo "Port-forwards necesarios (ejecutar en terminales separadas):"
echo "  kubectl -n argo port-forward deployment/argo-workflows-server 2746:2746"
echo "  kubectl -n argo port-forward deployment/minio 9000:9000"
echo "  kubectl -n argo port-forward deployment/minio 9001:9001"
echo ""
echo "UIs disponibles (después de port-forwards):"
echo "  Argo UI:   http://localhost:2746"
echo "  MinIO UI:  http://localhost:9001  (minioadmin / minioadmin)"
echo ""
echo "Ejecutar DAG manualmente:"
echo "  argo submit data-platform-workflows/pipelines/ingest-traffic-dag.yaml -n argo --watch"
echo ""
