#!/bin/bash

set -e

echo "=========================================="
echo " Creating Project Directory Structure"
echo "=========================================="

# =========================================================
# Main project directories
# =========================================================

mkdir -p frontend
mkdir -p backend

# =========================================================
# Monitoring directories
# =========================================================

mkdir -p monitoring/grafana
mkdir -p monitoring/prometheus
mkdir -p monitoring/cloudwatch-exporter

# =========================================================
# Create monitoring files if they don't exist
# =========================================================

touch monitoring/grafana/Dockerfile

touch monitoring/prometheus/Dockerfile
touch monitoring/prometheus/prometheus.yml

touch monitoring/cloudwatch-exporter/Dockerfile
touch monitoring/cloudwatch-exporter/config.yml

# =========================================================
# Root project files
# =========================================================

touch docker-compose.yml
touch README-ECS.md
touch ecr-tag-push.sh

echo ""
echo "=========================================="
echo " Directory Structure"
echo "=========================================="

if command -v tree >/dev/null 2>&1; then
    tree .
else
    find . -maxdepth 3 -type f | sort
fi

echo ""
echo "=========================================="
echo " Directory creation complete"
echo "=========================================="