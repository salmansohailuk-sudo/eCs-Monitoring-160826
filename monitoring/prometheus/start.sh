#!/bin/sh

# Start CloudWatch exporter in background
java -jar /cloudwatch_exporter.jar --config.file=/etc/prometheus/cloudwatch.yml &

# Start Prometheus
exec prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/prometheus
