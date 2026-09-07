FROM prom/prometheus:latest

# Copy both Prometheus configurations
COPY prometheus.yml /etc/prometheus/prometheus.yml
COPY prometheus.ecs.yml /etc/prometheus/prometheus.ecs.yml

# Copy startup script
COPY start-prometheus.sh /start-prometheus.sh

RUN chmod +x /start-prometheus.sh

EXPOSE 9090

# Default = EC2 configuration
ENV CONFIG_FILE=/etc/prometheus/prometheus.yml

ENTRYPOINT ["/start-prometheus.sh"]
