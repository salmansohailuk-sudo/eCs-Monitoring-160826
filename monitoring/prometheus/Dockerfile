#FROM prom/prometheus:latest
## Docker for EC2 config
#ARG CONFIG_FILE=prometheus.yml

## Docker config for ECS
## ARG CONFIG_FILE=prometheus.ecs.yml

#COPY ${CONFIG_FILE} /etc/prometheus/prometheus.yml

#EXPOSE 9090

#CMD ["--config.file=/etc/prometheus/prometheus.yml", "--storage.tsdb.path=/prometheus"]

FROM prom/prometheus:latest

# Copy Prometheus config
ARG CONFIG_FILE=prometheus.yml
COPY ${CONFIG_FILE} /etc/prometheus/prometheus.yml

# Copy CloudWatch exporter config
COPY cloudwatch.yml /etc/prometheus/cloudwatch.yml

# ---------------------------------------------------------
# FIX: Correct CloudWatch exporter JAR
# ---------------------------------------------------------
ADD https://github.com/prometheus/cloudwatch_exporter/releases/download/v0.15.5/cloudwatch_exporter-0.15.5.jar /cloudwatch_exporter.jar

# ---------------------------------------------------------
# Add entrypoint script
# ---------------------------------------------------------
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 9090

# ---------------------------------------------------------
# FIX: Correct CMD (no /bin/sh -c)
# ---------------------------------------------------------
CMD ["/start.sh"]
