FROM prom/prometheus:latest

# Docker for EC2 config - uncomment as needed.
ARG CONFIG_FILE=prometheus.yml

# Docker config for ECS - uncomment as needed.
#ARG CONFIG_FILE=prometheus.ecs.yml

COPY ${CONFIG_FILE} /etc/prometheus/prometheus.yml
EXPOSE 9090
CMD ["--config.file=/etc/prometheus/prometheus.yml", "--storage.tsdb.path=/prometheus"]
