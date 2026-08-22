#!/bin/bash

set -e

# =====================================================
# Load environment
# =====================================================

if [ ! -f .env ]; then
    echo "ERROR: .env file not found."
    exit 1
fi

set -a
source .env
set +a


# =====================================================
# Validate variables
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
# Generate BASE_URL
# =====================================================

BASE_URL="http://${ALB_DNS}"

export EC2_PUBLIC_IP
export ALB_DNS
export BASE_URL


echo ""
echo "=============================================="
echo " ECS MONITORING LOCAL REDEPLOY"
echo "=============================================="
echo ""
echo "EC2 Public IP : $EC2_PUBLIC_IP"
echo "ALB DNS       : $ALB_DNS"
echo "BASE URL      : $BASE_URL"
echo ""


# =====================================================
# Stop existing containers
# =====================================================

echo "Stopping existing containers..."

docker-compose down --remove-orphans


# =====================================================
# Build
# =====================================================

echo ""
echo "Building images..."

docker-compose build --no-cache


# =====================================================
# Start
# =====================================================

echo ""
echo "Starting containers..."

docker-compose up -d


# =====================================================
# Wait
# =====================================================

echo ""
echo "Waiting for containers..."

sleep 10


# =====================================================
# Status
# =====================================================

echo ""
echo "=============================================="
echo " CONTAINER STATUS"
echo "=============================================="

docker-compose ps


# =====================================================
# Test URLs
# =====================================================

echo ""
echo "=============================================="
echo " TEST URLS"
echo "=============================================="

echo ""
echo "Frontend:"
echo "http://${EC2_PUBLIC_IP}"

echo ""
echo "Backend health:"
echo "http://${EC2_PUBLIC_IP}:5000/health"

echo ""
echo "Backend metrics:"
echo "http://${EC2_PUBLIC_IP}:5000/metrics"

echo ""
echo "CloudWatch Exporter:"
echo "http://${EC2_PUBLIC_IP}:9106/metrics"

echo ""
echo "Prometheus:"
echo "http://${EC2_PUBLIC_IP}:9090"

echo ""
echo "Prometheus Targets:"
echo "http://${EC2_PUBLIC_IP}:9090/targets"

echo ""
echo "Grafana:"
echo "http://${EC2_PUBLIC_IP}:3000"

echo ""
echo "ALB:"
echo "http://${ALB_DNS}"

echo ""
echo "=============================================="
echo " REDEPLOY COMPLETE"
echo "=============================================="
