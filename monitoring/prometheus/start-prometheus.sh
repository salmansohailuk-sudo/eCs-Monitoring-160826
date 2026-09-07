#!/bin/sh

set -e

echo "Starting Prometheus..."
echo "Using configuration: ${CONFIG_FILE}"

exec /bin/prometheus \
  --config.file="${CONFIG_FILE}" \
  --storage.tsdb.path=/prometheus
