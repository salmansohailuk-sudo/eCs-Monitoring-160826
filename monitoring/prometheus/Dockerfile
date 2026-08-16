FROM prom/prometheus:latest

COPY prometheus.yml /etc/prometheus/prometheus.yml

EXPOSE 9090

CMD [
  "/bin/prometheus",
  "--config.file=/etc/prometheus/prometheus.yml",
  "--storage.tsdb.path=/prometheus",
  "--web.external-url=http://albtest-1244121495.us-east-1.elb.amazonaws.com/prometheus/",
  "--web.route-prefix=/prometheus"
]
