FROM nginx:alpine

# nginx config
RUN rm -f /etc/nginx/conf.d/default.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# injects backend URL at container start
COPY 20-backend-url.sh /docker-entrypoint.d/20-backend-url.sh

# frontend build
COPY . /usr/share/nginx/html

# nginx-prometheus-exporter (runs in same container as nginx)
RUN apk add --no-cache curl tar \
    && curl -L -o nginx-exporter.tar.gz \
       https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v0.11.0/nginx-prometheus-exporter_0.11.0_linux_amd64.tar.gz \
    && tar -xzf nginx-exporter.tar.gz \
    && mv nginx-prometheus-exporter /usr/bin/nginx-exporter \
    && chmod +x /usr/bin/nginx-exporter \
    && rm -f nginx-exporter.tar.gz

# run nginx + exporter together
CMD ["/bin/sh", "-c", "nginx -g 'daemon off;' & nginx-exporter -nginx.scrape-uri http://localhost/nginx_status"]

EXPOSE 80
