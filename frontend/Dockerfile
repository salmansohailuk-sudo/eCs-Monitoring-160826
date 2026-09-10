
#FROM nginx:alpine
#RUN rm -f /etc/nginx/conf.d/default.conf
#COPY default.conf /etc/nginx/conf.d/default.conf
#COPY 20-backend-url.sh /docker-entrypoint.d/20-backend-url.sh
#COPY . /usr/share/nginx/html
#EXPOSE 80


FROM nginx:alpine

# ---------------------------------------------------------
# (NO CHANGE) Remove default nginx config
# ---------------------------------------------------------
RUN rm -f /etc/nginx/conf.d/default.conf

# ---------------------------------------------------------
# (NO CHANGE) Copy your existing nginx config
# ---------------------------------------------------------
COPY default.conf /etc/nginx/conf.d/default.conf

# ---------------------------------------------------------
# (NO CHANGE) Backend URL injection script
# ---------------------------------------------------------
COPY 20-backend-url.sh /docker-entrypoint.d/20-backend-url.sh

# ---------------------------------------------------------
# (NO CHANGE) Copy your frontend build
# ---------------------------------------------------------
COPY . /usr/share/nginx/html

# ---------------------------------------------------------
# CHANGE: Install nginx-prometheus-exporter
# This replaces the separate nginx-exporter container.
# Alpine needs curl + chmod.
# ---------------------------------------------------------
RUN apk add --no-cache curl \
    && curl -L -o /usr/bin/nginx-exporter \
       https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v0.11.0/nginx-prometheus-exporter \
    && chmod +x /usr/bin/nginx-exporter

# ---------------------------------------------------------
# CHANGE: Run Nginx + exporter inside SAME container
# Previously only Nginx ran.
# ---------------------------------------------------------
CMD ["/bin/sh", "-c", "\
  nginx -g 'daemon off;' & \
  nginx-exporter -nginx.scrape-uri http://localhost/nginx_status \
"]

# ---------------------------------------------------------
# (NO CHANGE) Expose port 80
# ---------------------------------------------------------
EXPOSE 80
