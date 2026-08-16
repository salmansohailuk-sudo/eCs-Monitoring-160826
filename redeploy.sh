#!/bin/bash
echo "🔧 Stopping and removing old containers, images, volumes..."
docker-compose down --rmi all --volumes --remove-orphans

echo "🚀 Building and starting new containers..."
docker-compose up --build -d

echo "✅ Redeploy complete."
