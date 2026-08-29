FROM nginx:alpine

RUN rm -f /etc/nginx/conf.d/default.conf

COPY default.conf /etc/nginx/conf.d/default.conf

COPY 20-backend-url.sh /docker-entrypoint.d/20-backend-url.sh

COPY . /usr/share/nginx/html

EXPOSE 80
