FROM prom/cloudwatch-exporter:latest

COPY config.yml /config/config.yml

EXPOSE 9106

ENTRYPOINT ["java", "-jar", "/cloudwatch_exporter.jar"]

CMD ["9106", "/config/config.yml"]