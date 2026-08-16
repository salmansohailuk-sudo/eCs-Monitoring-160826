eCs-Monitoring-160826

AWS ECS application and monitoring project using Docker, Prometheus, Grafana, and CloudWatch Exporter.

IMPORTANT: Before deploying, you must update the root .env file and the monitoring/prometheus/Dockerfile with the correct ALB configuration.

Project Structure
eCs-Monitoring-160826/
│
├── docker-compose.yml
├── create-directories.sh
├── ecr-tag-push.sh
├── README-ECS.md
├── .env
│
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   └── ...
│
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py
│   └── ...
│
└── monitoring/
    │
    ├── grafana/
    │   └── Dockerfile
    │
    ├── prometheus/
    │   ├── Dockerfile
    │   └── prometheus.yml
    │
    └── cloudwatch-exporter/
        ├── Dockerfile
        └── config.yml
