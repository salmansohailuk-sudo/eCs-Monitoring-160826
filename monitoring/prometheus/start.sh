#!/bin/sh

# run cloudwatch exporter in background
java -jar /cloudwatch_exporter.jar 9106 /etc/cloudwatch-exporter/cloudwatch.yml &

# run prometheus in foreground (keeps container running)
exec /bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/prometheus \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.console.templates=/etc/prometheus/consoles
