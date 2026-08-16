# README 2 --- ECS Fargate Monitoring with Service Connect + Cloud Map

## Purpose

This architecture keeps Grafana, Prometheus, and CloudWatch Exporter as
**three separate ECS services**.

ECS Service Connect provides the internal service-to-service
connectivity.

AWS Cloud Map provides the namespace/service discovery layer used by
Service Connect.

The result is:

``` text
Grafana
   |
   | http://prometheus:9090
   v
Prometheus
   |
   | http://cloudwatch-exporter:9106
   v
CloudWatch Exporter
```

This is the more modular architecture.

------------------------------------------------------------------------

# 1. Final Architecture

``` text
                         INTERNET
                            |
                            v
                           ALB
                            |
             +--------------+--------------+
             |                             |
             v                             v
         /grafana*                     /prometheus*
             |                             |
             v                             v
       grafana-tg                    prometheus-tg
             |                             |
             v                             v
       Grafana ECS                   Prometheus ECS
             |                             |
             |                             |
             +---- Service Connect --------+
                                           |
                                           |
                              cloudwatch-exporter
                                           |
                                           v
                              CloudWatch Exporter ECS
                                           |
                                           v
                                     AWS CloudWatch
```

Internal DNS:

``` text
prometheus
cloudwatch-exporter
```

External access:

``` text
http://CURRENT-ALB-DNS/grafana/
http://CURRENT-ALB-DNS/prometheus/
```

CloudWatch Exporter remains private.

------------------------------------------------------------------------

# 2. Important Difference From the Combined Architecture

In this architecture:

``` text
Grafana
   |
   | DNS
   v
prometheus:9090
```

and:

``` text
Prometheus
   |
   | DNS
   v
cloudwatch-exporter:9106
```

This requires ECS Service Connect.

Do not expect the ECS service name alone to create DNS.

For example:

``` text
prometheus-service
```

does not automatically mean:

``` text
prometheus
```

is resolvable.

Service Connect creates the service endpoint and client alias.

------------------------------------------------------------------------

# 3. Existing ECS Services

Keep:

``` text
frontendservice
backendservice
```

Create/use:

``` text
grafana-service
prometheus-service
cloudwatch-exporter-service
```

The existing task definitions already contain named port mappings
suitable for Service Connect:

``` text
grafana-3000-tcp
prometheus-9090-tcp
cloudwatch-exporter-9106-tcp
```

The Service Connect `portName` must match the named port mapping in the
task definition. AWS documents this requirement.

------------------------------------------------------------------------

# 4. Create the Cloud Map Namespace

Go to:

**AWS Console → Cloud Map**

Choose:

**Namespaces**

Choose:

**Create namespace**

Select the option for a namespace that can be used with ECS/Service
Connect.

Namespace name:

``` text
monitoring
```

Region:

``` text
us-east-1
```

Create the namespace.

------------------------------------------------------------------------

# 5. Important Cloud Map Rule

Do not manually create:

``` text
prometheus
cloudwatch-exporter
```

Cloud Map services if you are using ECS Service Connect.

Service Connect creates/manages the Cloud Map services associated with
its service configuration.

AWS Service Connect uses a Cloud Map namespace and creates the
service-discovery resources for configured Service Connect services.
citeturn0search1turn0search7

------------------------------------------------------------------------

# 6. Configure the ECS Cluster

Go to:

**AWS Console → ECS → Clusters → testcluster**

Open:

**Configuration**

Find:

**Service Connect defaults**

Set the default namespace to:

``` text
monitoring
```

If the namespace already exists, select it.

AWS supports configuring a default Service Connect namespace at the ECS
cluster level. citeturn0search8

------------------------------------------------------------------------

# 7. Configure Prometheus Service First

Go to:

**ECS → Clusters → testcluster → Services**

Select:

``` text
prometheus-service
```

Choose:

**Update**

Find:

**Service Connect**

Turn it on.

Select:

``` text
Client and server
```

Prometheus needs to be a server because Grafana will connect to it.

------------------------------------------------------------------------

# 8. Select the Namespace

Choose:

``` text
monitoring
```

Use the same namespace for all three monitoring services.

------------------------------------------------------------------------

# 9. Configure Prometheus Service Connect Endpoint

Under the Service Connect service configuration select:

``` text
Port:
prometheus-9090-tcp
```

This must match your task definition.

Set:

``` text
Discovery name:
prometheus
```

Set the client alias/DNS name:

``` text
prometheus
```

Port:

``` text
9090
```

The important result is:

``` text
http://prometheus:9090
```

AWS Service Connect supports client aliases so applications can use
short DNS names. citeturn0search1

------------------------------------------------------------------------

# 10. Update Prometheus

Choose:

**Update Service**

ECS will create a new deployment.

Wait until:

``` text
1/1 tasks running
```

and the deployment is stable.

Service Connect adds a managed proxy to the service tasks, so a new
deployment is expected.

------------------------------------------------------------------------

# 11. Configure CloudWatch Exporter Service

Go to:

**ECS → Clusters → testcluster → Services**

Select:

``` text
cloudwatch-exporter-service
```

Choose:

**Update**

Find:

**Service Connect**

Turn it on.

Select:

``` text
Client and server
```

------------------------------------------------------------------------

# 12. Select the Namespace

Choose:

``` text
monitoring
```

Do not create a second namespace.

------------------------------------------------------------------------

# 13. Configure CloudWatch Exporter Endpoint

Select:

``` text
Port:
cloudwatch-exporter-9106-tcp
```

Set:

``` text
Discovery name:
cloudwatch-exporter
```

Set client alias/DNS name:

``` text
cloudwatch-exporter
```

Port:

``` text
9106
```

The resulting internal endpoint is:

``` text
http://cloudwatch-exporter:9106
```

------------------------------------------------------------------------

# 14. Update CloudWatch Exporter

Choose:

**Update Service**

Wait for:

``` text
1/1 tasks running
```

and a stable deployment.

------------------------------------------------------------------------

# 15. Configure Grafana Service

Go to:

**ECS → Clusters → testcluster → Services**

Select:

``` text
grafana-service
```

Choose:

**Update**

Find:

**Service Connect**

Turn it on.

Select:

``` text
Client only
```

Grafana only needs to connect to Prometheus.

------------------------------------------------------------------------

# 16. Select the Namespace

Choose:

``` text
monitoring
```

Grafana must use the same namespace as Prometheus.

Conceptually:

``` text
Grafana
   |
   +---- monitoring namespace
              |
              v
          prometheus
```

------------------------------------------------------------------------

# 17. Do Not Create a Grafana Service Connect Server Endpoint

Grafana is:

``` text
Client only
```

It does not need to expose a Service Connect service.

Its public access continues through the existing ALB:

``` text
ALB
 |
 /grafana*
 |
 v
grafana-tg
 |
 v
Grafana :3000
```

------------------------------------------------------------------------

# 18. Update Grafana Service

Choose:

**Update Service**

Wait until the deployment becomes stable.

------------------------------------------------------------------------

# 19. Final Service Connect Configuration

You should now have:

## Grafana

``` text
Service:
grafana-service

Service Connect:
ON

Mode:
Client only

Namespace:
monitoring
```

## Prometheus

``` text
Service:
prometheus-service

Service Connect:
ON

Mode:
Client and server

Namespace:
monitoring

Port:
prometheus-9090-tcp

DNS:
prometheus

Port:
9090
```

## CloudWatch Exporter

``` text
Service:
cloudwatch-exporter-service

Service Connect:
ON

Mode:
Client and server

Namespace:
monitoring

Port:
cloudwatch-exporter-9106-tcp

DNS:
cloudwatch-exporter

Port:
9106
```

------------------------------------------------------------------------

# 20. Prometheus Configuration

Because Prometheus is now a Service Connect client, configure the
CloudWatch Exporter target as:

``` yaml
- job_name: "cloudwatch-exporter"
  static_configs:
    - targets:
        - "cloudwatch-exporter:9106"
```

Do not use:

``` text
localhost:9106
```

in this architecture.

That would only be correct if Prometheus and CloudWatch Exporter were in
the same ECS task.

------------------------------------------------------------------------

# 21. Grafana Data Source

Open:

``` text
http://CURRENT-ALB-DNS/grafana/
```

Go to:

**Connections → Data Sources → Prometheus**

URL:

``` text
http://prometheus:9090
```

Click:

**Save & Test**

Expected:

``` text
Successfully queried the Prometheus API.
```

This is the configuration that currently fails because Service
Connect/DNS has not yet been configured.

------------------------------------------------------------------------

# 22. ALB Configuration

Keep the existing ALB.

Create/use:

``` text
grafana-tg
```

Port:

``` text
3000
```

Health check:

``` text
/api/health
```

Create/use:

``` text
prometheus-tg
```

Port:

``` text
9090
```

Health check:

``` text
/-/healthy
```

Fargate uses `awsvpc`, so target groups must use IP targets.
citeturn0search0turn0search12

------------------------------------------------------------------------

# 23. ALB Listener Rules

Go to:

**EC2 → Load Balancers → Your ALB → Listeners → HTTP :80**

Configure:

``` text
/grafana*
    ↓
grafana-tg
```

and:

``` text
/prometheus*
    ↓
prometheus-tg
```

Keep the existing frontend default rule.

------------------------------------------------------------------------

# 24. Security Groups

Grafana:

``` text
TCP 3000
Source: ALB Security Group
```

Prometheus:

``` text
TCP 9090
Source: ALB Security Group
```

Additionally allow:

``` text
TCP 9090
Source: Grafana/monitoring ECS Security Group
```

for Grafana → Prometheus.

CloudWatch Exporter:

``` text
TCP 9106
Source: Prometheus/monitoring ECS Security Group
```

Do not expose:

``` text
3000
9090
9106
```

to:

``` text
0.0.0.0/0
```

------------------------------------------------------------------------

# 25. Test Service Connect DNS

After all three services have been updated and are running, use ECS Exec
from the Grafana task.

Enter the Grafana container.

Test:

``` text
prometheus
```

The expected result is that the name resolves.

Then test:

``` text
http://prometheus:9090/-/healthy
```

Expected:

``` text
Prometheus Server is Healthy.
```

------------------------------------------------------------------------

# 26. Test Prometheus → CloudWatch Exporter

Use ECS Exec into the Prometheus task.

Test:

``` text
http://cloudwatch-exporter:9106/metrics
```

Expected:

``` text
Prometheus-format metrics
```

Then open Prometheus:

``` text
http://CURRENT-ALB-DNS/prometheus/
```

Go to:

**Status → Targets**

Expected:

``` text
cloudwatch-exporter
UP
```

------------------------------------------------------------------------

# 27. Cloud Map Verification

Go to:

**AWS Console → Cloud Map → Namespaces**

Open:

``` text
monitoring
```

You should see Service Connect-managed service discovery resources
associated with:

``` text
prometheus
cloudwatch-exporter
```

The important distinction is:

``` text
Cloud Map
    |
    | namespace
    v
Service Connect
    |
    +---- prometheus
    |
    +---- cloudwatch-exporter
```

You normally do not manually maintain these services when ECS Service
Connect owns them.

------------------------------------------------------------------------

# 28. DNS Names

Applications should use the configured Service Connect client aliases:

``` text
prometheus
```

and:

``` text
cloudwatch-exporter
```

Therefore:

Grafana:

``` text
http://prometheus:9090
```

Prometheus:

``` text
http://cloudwatch-exporter:9106
```

Do not use the ALB for these internal connections.

------------------------------------------------------------------------

# 29. Do Not Use the ECS Service Names as the DNS Names

Do not assume:

``` text
prometheus-service
```

will resolve.

Do not assume:

``` text
cloudwatch-exporter-service
```

will resolve.

The Service Connect client aliases are explicitly configured as:

``` text
prometheus
cloudwatch-exporter
```

AWS notes that clients resolve the configured `dnsName` client aliases
rather than the discovery name itself. citeturn0search1turn0search7

------------------------------------------------------------------------

# 30. Existing Task Definitions

Your current task definitions already have the required named port
mappings:

``` text
Grafana:
grafana-3000-tcp

Prometheus:
prometheus-9090-tcp

CloudWatch Exporter:
cloudwatch-exporter-9106-tcp
```

Therefore, for this architecture, you should not need to rebuild the
Docker images merely to enable Service Connect.

The ECS service configuration is the important change.

------------------------------------------------------------------------

# 31. Production Architecture

``` text
                         INTERNET
                            |
                            v
                           ALB
                            |
             +--------------+--------------+
             |                             |
             v                             v
         /grafana*                     /prometheus*
             |                             |
             v                             v
          Grafana                      Prometheus
          Service                       Service
             |                             |
             |                             |
             +-------- Service Connect -----+
                                           |
                                           v
                                  CloudWatch Exporter
                                      Service
                                           |
                                           v
                                      CloudWatch
```

Service Connect namespace:

``` text
monitoring
```

Client aliases:

``` text
prometheus
cloudwatch-exporter
```

------------------------------------------------------------------------

# 32. Combined Architecture vs Service Connect

  Feature                  Combined task          Service Connect
  ------------------------ ---------------------- -----------------------
  ECS services             1 monitoring service   3 monitoring services
  Task definitions         1                      3
  Grafana → Prometheus     localhost              Service Connect DNS
  Prometheus → Exporter    localhost              Service Connect DNS
  Cloud Map                No                     Yes
  Service Connect          No                     Yes
  Independent scaling      No                     Yes
  Independent deployment   No                     Yes
  Failure isolation        Lower                  Better
  Setup complexity         Low                    Higher
  Good for testing         Excellent              Good
  Good for production      Basic                  Better

------------------------------------------------------------------------

# 33. Which Architecture Should You Use?

For your current test environment:

``` text
Recommended first:
Combined monitoring task
```

This is the easiest way to get the monitoring stack working.

For a more production-style architecture:

``` text
Recommended second:
Separate ECS services
+
Service Connect
+
Cloud Map namespace
+
prometheus DNS
+
cloudwatch-exporter DNS
```

------------------------------------------------------------------------

# 34. Success Criteria

The Service Connect architecture is complete when:

-   [ ] Cloud Map namespace `monitoring` exists
-   [ ] ECS cluster uses the namespace
-   [ ] Grafana Service Connect is enabled
-   [ ] Grafana is Client only
-   [ ] Prometheus Service Connect is enabled
-   [ ] Prometheus is Client and server
-   [ ] Prometheus endpoint is `prometheus`
-   [ ] CloudWatch Exporter Service Connect is enabled
-   [ ] CloudWatch Exporter is Client and server
-   [ ] CloudWatch Exporter endpoint is `cloudwatch-exporter`
-   [ ] Grafana resolves `prometheus`
-   [ ] Grafana can query Prometheus
-   [ ] Prometheus resolves `cloudwatch-exporter`
-   [ ] Prometheus target is UP
-   [ ] CloudWatch Exporter returns metrics
-   [ ] `/grafana/` works through the ALB
-   [ ] `/prometheus/` works through the ALB
-   [ ] CloudWatch Exporter is not publicly exposed
