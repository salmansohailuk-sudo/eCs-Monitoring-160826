FROM prom/prometheus:latest
ARG CONFIG_FILE=prometheus.yml
COPY ${CONFIG_FILE} /etc/prometheus/prometheus.yml
EXPOSE 9090
CMD ["--config.file=/etc/prometheus/prometheus.yml", "--storage.tsdb.path=/prometheus"]
