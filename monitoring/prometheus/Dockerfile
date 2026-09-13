FROM eclipse-temurin:17-jre-alpine

ARG PROM_VERSION=3.5.4

# get prometheus binary
RUN apk add --no-cache curl tar \
    && curl -L -o prometheus.tar.gz https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz \
    && tar -xzf prometheus.tar.gz \
    && mv prometheus-${PROM_VERSION}.linux-amd64/prometheus /bin/prometheus \
    && mv prometheus-${PROM_VERSION}.linux-amd64/promtool /bin/promtool \
    && rm -rf prometheus.tar.gz prometheus-${PROM_VERSION}.linux-amd64

# prometheus config
ARG CONFIG_FILE=prometheus.yml
COPY ${CONFIG_FILE} /etc/prometheus/prometheus.yml

# cloudwatch exporter config + jar
COPY cloudwatch.yml /etc/cloudwatch-exporter/cloudwatch.yml
ADD https://github.com/prometheus/cloudwatch_exporter/releases/download/v0.15.5/cloudwatch_exporter-0.15.5-jar-with-dependencies.jar /cloudwatch_exporter.jar

# script that starts both
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 9090 9106

ENTRYPOINT ["/start.sh"]
