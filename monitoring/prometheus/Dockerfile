FROM prom/prometheus:latest

# Copy both Prometheus configurations into the image
COPY prometheus.yml /etc/prometheus/prometheus.yml
COPY prometheus.ecs.yml /etc/prometheus/prometheus.ecs.yml

EXPOSE 9090

# Default configuration for EC2
ENV CONFIG_FILE=/etc/prometheus/prometheus.yml

CMD ["sh", "-c", "exec /bin/prometheus --config.file=${CONFIG_FILE} --storage.tsdb.path=/prometheus"]
