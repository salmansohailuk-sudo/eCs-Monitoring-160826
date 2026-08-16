#!/bin/bash

set -e

# =========================================================
# Configuration
# =========================================================

AWS_REGION="us-east-1"

echo ""
echo "=========================================="
echo " AWS / ECR Configuration"
echo "=========================================="

AWS_ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "ERROR: Unable to determine AWS Account ID."
    exit 1
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "AWS Account : ${AWS_ACCOUNT_ID}"
echo "AWS Region  : ${AWS_REGION}"
echo "ECR Registry: ${ECR_REGISTRY}"


# =========================================================
# Image Names
# =========================================================

FRONTEND_IMAGE="ecomm-frontend"
BACKEND_IMAGE="ecomm-backend"
GRAFANA_IMAGE="monitoring-grafana"
PROMETHEUS_IMAGE="monitoring-prometheus"
CLOUDWATCH_EXPORTER_IMAGE="monitoring-cloudwatch-exporter"


# =========================================================
# Login to Amazon ECR
# =========================================================

echo ""
echo "=========================================="
echo " Logging into Amazon ECR"
echo "=========================================="

aws ecr get-login-password \
    --region "${AWS_REGION}" | \
docker login \
    --username AWS \
    --password-stdin "${ECR_REGISTRY}"

echo "ECR login successful."


# =========================================================
# Create ECR Repositories
# =========================================================

echo ""
echo "=========================================="
echo " Creating ECR Repositories"
echo "=========================================="

REPOSITORIES=(
    "${FRONTEND_IMAGE}"
    "${BACKEND_IMAGE}"
    "${GRAFANA_IMAGE}"
    "${PROMETHEUS_IMAGE}"
    "${CLOUDWATCH_EXPORTER_IMAGE}"
)

for REPO in "${REPOSITORIES[@]}"; do

    if aws ecr describe-repositories \
        --repository-names "${REPO}" \
        --region "${AWS_REGION}" \
        > /dev/null 2>&1; then

        echo "Already exists: ${REPO}"

    else

        echo "Creating: ${REPO}"

        aws ecr create-repository \
            --repository-name "${REPO}" \
            --region "${AWS_REGION}" \
            > /dev/null

        echo "Created: ${REPO}"

    fi

done


# =========================================================
# Check Local Images
# =========================================================

echo ""
echo "=========================================="
echo " Checking Local Images"
echo "=========================================="

REQUIRED_IMAGES=(
    "${FRONTEND_IMAGE}:latest"
    "${BACKEND_IMAGE}:latest"
    "${GRAFANA_IMAGE}:latest"
    "${PROMETHEUS_IMAGE}:latest"
    "${CLOUDWATCH_EXPORTER_IMAGE}:latest"
)

for IMAGE in "${REQUIRED_IMAGES[@]}"; do

    if ! docker image inspect "${IMAGE}" > /dev/null 2>&1; then
        echo ""
        echo "ERROR: Local image not found:"
        echo "${IMAGE}"
        echo ""
        exit 1
    fi

    echo "Found: ${IMAGE}"

done


# =========================================================
# Tag Images
# =========================================================

echo ""
echo "=========================================="
echo " Tagging Five Images"
echo "=========================================="

echo "Tagging Frontend..."

docker tag \
    "${FRONTEND_IMAGE}:latest" \
    "${ECR_REGISTRY}/${FRONTEND_IMAGE}:latest"


echo "Tagging Backend..."

docker tag \
    "${BACKEND_IMAGE}:latest" \
    "${ECR_REGISTRY}/${BACKEND_IMAGE}:latest"


echo "Tagging Grafana..."

docker tag \
    "${GRAFANA_IMAGE}:latest" \
    "${ECR_REGISTRY}/${GRAFANA_IMAGE}:latest"


echo "Tagging Prometheus..."

docker tag \
    "${PROMETHEUS_IMAGE}:latest" \
    "${ECR_REGISTRY}/${PROMETHEUS_IMAGE}:latest"


echo "Tagging CloudWatch Exporter..."

docker tag \
    "${CLOUDWATCH_EXPORTER_IMAGE}:latest" \
    "${ECR_REGISTRY}/${CLOUDWATCH_EXPORTER_IMAGE}:latest"


echo ""
echo "All five images tagged successfully."


# =========================================================
# Push Images
# =========================================================

echo ""
echo "=========================================="
echo " Pushing Five Images to ECR"
echo "=========================================="


echo ""
echo "Pushing Frontend..."

docker push \
    "${ECR_REGISTRY}/${FRONTEND_IMAGE}:latest"


echo ""
echo "Pushing Backend..."

docker push \
    "${ECR_REGISTRY}/${BACKEND_IMAGE}:latest"


echo ""
echo "Pushing Grafana..."

docker push \
    "${ECR_REGISTRY}/${GRAFANA_IMAGE}:latest"


echo ""
echo "Pushing Prometheus..."

docker push \
    "${ECR_REGISTRY}/${PROMETHEUS_IMAGE}:latest"


echo ""
echo "Pushing CloudWatch Exporter..."

docker push \
    "${ECR_REGISTRY}/${CLOUDWATCH_EXPORTER_IMAGE}:latest"


# =========================================================
# Complete
# =========================================================

echo ""
echo "=========================================="
echo " ECR PUSH COMPLETE"
echo "=========================================="

echo ""
echo "Images pushed:"
echo ""

echo "${ECR_REGISTRY}/ecomm-frontend:latest"
echo "${ECR_REGISTRY}/ecomm-backend:latest"
echo "${ECR_REGISTRY}/monitoring-grafana:latest"
echo "${ECR_REGISTRY}/monitoring-prometheus:latest"
echo "${ECR_REGISTRY}/monitoring-cloudwatch-exporter:latest"

echo ""
echo "=========================================="
echo " Done"
echo "=========================================="