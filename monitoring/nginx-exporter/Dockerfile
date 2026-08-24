FROM nginx/nginx-prometheus-exporter:1.4.2

EXPOSE 9113

ENTRYPOINT ["/usr/bin/nginx-prometheus-exporter"]

CMD ["-nginx.scrape-uri=http://frontend/nginx_status"]
