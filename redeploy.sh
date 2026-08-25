#!/bin/bash

set -e


# =====================================================
# LOAD ENVIRONMENT
# =====================================================

if [ ! -f .env ]; then

    echo "ERROR: .env file not found."

    exit 1

fi


set -a
source .env
set +a


# =====================================================
# VALIDATE REQUIRED VARIABLES
# =====================================================

if [ -z "$EC2_PUBLIC_IP" ]; then

    echo "ERROR: EC2_PUBLIC_IP is not set in .env"

    exit 1

fi


if [ -z "$ALB_DNS" ]; then

    echo "ERROR: ALB_DNS is not set in .env"

    exit 1

fi


# =====================================================
# EC2 PUBLIC URL
#
# Do NOT force BASE_URL to ALB.
#
# app.py supports:
#
# EC2:
#   EC2_PUBLIC_IP
#
# ECS:
#   ALB_DNS
#
# =====================================================

BASE_URL="http://${EC2_PUBLIC_IP}"

export EC2_PUBLIC_IP
export ALB_DNS
export BASE_URL


echo ""
echo "=============================================="
echo " E-COMMERCE MONITORING LOCAL REDEPLOY"
echo "=============================================="
echo ""

echo "EC2 Public IP : $EC2_PUBLIC_IP"

echo "ALB DNS       : $ALB_DNS"

echo "BASE URL      : $BASE_URL"

echo ""


# =====================================================
# SHOW COMPOSE CONFIG
# =====================================================

echo "Checking Docker Compose configuration..."

docker compose config >/dev/null

echo "Docker Compose configuration: OK"


# =====================================================
# STOP EXISTING CONTAINERS
# =====================================================

echo ""
echo "Stopping existing containers..."

docker compose down --remove-orphans


# =====================================================
# BUILD
# =====================================================

echo ""
echo "Building images..."

docker compose build --no-cache


# =====================================================
# START
# =====================================================

echo ""
echo "Starting containers..."

docker compose up -d


# =====================================================
# WAIT
# =====================================================

echo ""
echo "Waiting for containers..."

sleep 15


# =====================================================
# STATUS
# =====================================================

echo ""
echo "=============================================="
echo " CONTAINER STATUS"
echo "=============================================="

docker compose ps


# =====================================================
# NGINX EXPORTER TEST
# =====================================================

echo ""
echo "=============================================="
echo " NGINX EXPORTER"
echo "=============================================="

echo ""

echo "Nginx exporter container:"

docker compose ps nginx-exporter


echo ""

echo "Nginx exporter metrics:"

curl -fsS http://localhost:9113/metrics \
    | head -20 || true


# =====================================================
# NGINX STATUS TEST FROM FRONTEND CONTAINER
# =====================================================

echo ""
echo "=============================================="
echo " NGINX STATUS TEST"
echo "=============================================="

docker compose exec -T frontend \
    wget -qO- http://localhost/nginx_status || true


# =====================================================
# BACKEND TEST
# =====================================================

echo ""
echo "=============================================="
echo " BACKEND"
echo "=============================================="

echo ""

echo "Backend health:"

curl -fsS \
    http://${EC2_PUBLIC_IP}:5000/health || true


echo ""

echo "Database health:"

curl -fsS \
    http://${EC2_PUBLIC_IP}:5000/health/db || true


echo ""

echo "Backend metrics:"

curl -fsS \
    http://${EC2_PUBLIC_IP}:5000/metrics \
    | head -20 || true


# =====================================================
# CLOUDWATCH EXPORTER
# =====================================================

echo ""
echo "=============================================="
echo " CLOUDWATCH EXPORTER"
echo "=============================================="

curl -fsS \
    http://${EC2_PUBLIC_IP}:9106/metrics \
    | head -20 || true


# =====================================================
# PROMETHEUS
# =====================================================

echo ""
echo "=============================================="
echo " PROMETHEUS"
echo "=============================================="

echo ""

echo "Prometheus:"

echo "http://${EC2_PUBLIC_IP}:9090"

echo ""

echo "Prometheus Targets:"

echo "http://${EC2_PUBLIC_IP}:9090/targets"


# =====================================================
# GRAFANA
# =====================================================

echo ""
echo "=============================================="
echo " GRAFANA"
echo "=============================================="

echo ""

echo "Grafana:"

echo "http://${EC2_PUBLIC_IP}:3000"


# =====================================================
# FRONTEND
# =====================================================

echo ""
echo "=============================================="
echo " FRONTEND"
echo "=============================================="

echo ""

echo "Frontend:"

echo "http://${EC2_PUBLIC_IP}"


# =====================================================
# ALB
# =====================================================

echo ""
echo "=============================================="
echo " ALB"
echo "=============================================="

echo ""

echo "ALB:"

echo "http://${ALB_DNS}"


# =====================================================
# COMPLETE
# =====================================================

echo ""
echo "=============================================="
echo " REDEPLOY COMPLETE"
echo "=============================================="
echo ""
