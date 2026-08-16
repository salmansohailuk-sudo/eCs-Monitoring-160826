FROM prom/cloudwatch-exporter:latest

COPY config.yml /config/config.yml

EXPOSE 9106

CMD ["/cloudwatch_exporter", "9106", "/config/config.yml"]
