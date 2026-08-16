# eCs-Monitoring-160826

project/
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