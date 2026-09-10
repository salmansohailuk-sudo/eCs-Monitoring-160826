#FROM prom/prometheus:latest
## Docker for EC2 config
#ARG CONFIG_FILE=prometheus.yml

## Docker config for ECS
## ARG CONFIG_FILE=prometheus.ecs.yml

#COPY ${CONFIG_FILE} /etc/prometheus/prometheus.yml

#EXPOSE 9090

#CMD ["--config.file=/etc/prometheus/prometheus.yml", "--storage.tsdb.path=/prometheus"]


#==============
FROM prom/prometheus:latest

# ---------------------------------------------------------
# (NO CHANGE) Docker for EC2 config
# ---------------------------------------------------------
ARG CONFIG_FILE=prometheus.yml

# ---------------------------------------------------------
# (NO CHANGE) Docker config for ECS (commented)
# ---------------------------------------------------------
# ARG CONFIG_FILE=prometheus.ecs.yml

# ---------------------------------------------------------
# (NO CHANGE) Copy Prometheus config
# ---------------------------------------------------------
COPY ${CONFIG_FILE} /etc/prometheus/prometheus.yml

# ---------------------------------------------------------
# CHANGE: Add CloudWatch exporter JAR
# This replaces the separate cloudwatch-exporter container.
# ---------------------------------------------------------
ADD https://github.com/prometheus/cloudwatch_exporter/releases/download/v0.15.5/cloudwatch_exporter-0.15.5.jar /cloudwatch_exporter.jar

# ---------------------------------------------------------
# (NO CHANGE) Expose Prometheus port
# ---------------------------------------------------------
EXPOSE 9090

# ---------------------------------------------------------
# CHANGE: Run Prometheus + CloudWatch exporter together
# Previously CMD only launched Prometheus.
# ---------------------------------------------------------
CMD ["/bin/sh", "-c", "\
  java -jar /cloudwatch_exporter.jar --config.file=/etc/prometheus/cloudwatch.yml & \
  prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus \
"]
