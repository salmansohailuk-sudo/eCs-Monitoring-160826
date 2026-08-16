FROM prom/cloudwatch-exporter:latest

COPY config.yml /config/config.yml

EXPOSE 9106

CMD ["/bin/sh", "-c", "java -jar /cloudwatch_exporter.jar 9106 /config/config.yml"]