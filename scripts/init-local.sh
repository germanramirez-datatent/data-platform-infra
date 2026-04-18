#!/bin/bash
set -e

echo "Setup MinIO local..."

mc alias set local http://localhost:9000 minioadmin minioadmin

echo "Creando buckets..."
mc mb --ignore-existing local/raw
mc mb --ignore-existing local/curated
mc mb --ignore-existing local/athena-results

echo "Buckets creados:"
mc ls local