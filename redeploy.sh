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
# LOCAL EC2 BASE URL
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
# CHECK COMPOSE
# =====================================================

echo "Checking Docker Compose configuration..."

docker compose config >/dev/null

echo "Docker Compose configuration: OK"


# =====================================================
# STOP EXISTING STACK
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
echo "Waiting for containers to start..."

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
# NGINX EXPORTER
# =====================================================

echo ""
echo "=============================================="
echo " NGINX EXPORTER"
echo "=============================================="

echo ""
echo "Nginx exporter container:"

docker compose ps nginx-exporter


echo ""
echo "Nginx exporter logs:"

docker compose logs --tail=20 nginx-exporter


# =====================================================
# TEST NGINX STATUS DIRECTLY
# =====================================================

echo ""
echo "=============================================="
echo " NGINX STATUS"
echo "=============================================="

echo ""
echo "Testing frontend /nginx_status..."

if timeout 5 docker compose exec -T frontend \
    wget -qO- http://localhost/nginx_status
then
    echo ""
    echo "Nginx status endpoint: OK"
else
    echo ""
    echo "WARNING: Nginx /nginx_status is not responding."
fi


# =====================================================
# TEST NGINX EXPORTER
# =====================================================

echo ""
echo "=============================================="
echo " NGINX EXPORTER METRICS"
echo "=============================================="

echo ""
echo "Testing exporter metrics endpoint..."

if timeout 10 curl -fsS \
    http://localhost:9113/metrics \
    -o /tmp/nginx-exporter-metrics
then

    echo "Nginx exporter metrics endpoint: OK"

    echo ""
    echo "Nginx exporter metrics:"
    head -20 /tmp/nginx-exporter-metrics

    echo ""

    echo "nginx_up metric:"

    grep "^nginx_up" /tmp/nginx-exporter-metrics || \
        echo "WARNING: nginx_up metric not found."

else

    echo "WARNING: Nginx exporter metrics endpoint did not respond within 10 seconds."

    echo ""
    echo "The exporter container is running, but its Nginx scrape may not be working yet."

fi


# =====================================================
# TEST EXPORTER -> FRONTEND
# =====================================================

echo ""
echo "=============================================="
echo " EXPORTER -> FRONTEND TEST"
echo "=============================================="

echo ""

if timeout 5 docker exec monitoring-nginx-exporter \
    wget -qO- http://frontend/nginx_status
then

    echo ""
    echo "Exporter can reach frontend /nginx_status: OK"

else

    echo ""
    echo "WARNING: exporter cannot reach frontend /nginx_status."

fi


# =====================================================
# BACKEND
# =====================================================

echo ""
echo "=============================================="
echo " BACKEND"
echo "=============================================="

echo ""
echo "Backend health:"

timeout 5 curl -fsS \
    http://${EC2_PUBLIC_IP}:5000/health || \
    echo "WARNING: Backend health check failed."


echo ""
echo "Database health:"

timeout 10 curl -fsS \
    http://${EC2_PUBLIC_IP}:5000/health/db || \
    echo "WARNING: Database health check failed."


echo ""
echo "Backend metrics:"

timeout 5 curl -fsS \
    http://${EC2_PUBLIC_IP}:5000/metrics \
    | head -20 || \
    echo "WARNING: Backend metrics check failed."


# =====================================================
# CLOUDWATCH EXPORTER
# =====================================================

echo ""
echo "=============================================="
echo " CLOUDWATCH EXPORTER"
echo "=============================================="

echo ""

timeout 10 curl -fsS \
    http://${EC2_PUBLIC_IP}:9106/metrics \
    | head -20 || \
    echo "WARNING: CloudWatch exporter metrics check failed."


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

echo ""

if timeout 5 curl -fsS \
    http://localhost:9090/-/ready
then
    echo ""
    echo "Prometheus: READY"
else
    echo ""
    echo "WARNING: Prometheus readiness check failed."
fi


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

echo ""

if timeout 5 curl -fsS \
    http://localhost:3000/api/health
then
    echo ""
    echo "Grafana: READY"
else
    echo ""
    echo "WARNING: Grafana health check failed."
fi


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

echo ""

if timeout 5 curl -fsS \
    http://localhost/health
then
    echo ""
    echo "Frontend: READY"
else
    echo ""
    echo "WARNING: Frontend health check failed."
fi


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

echo "All containers have been started."

echo ""
echo "Containers:"

docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=============================================="
