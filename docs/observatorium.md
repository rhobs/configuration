# Observatorium

Observatorium is a collection of services unified behind a single API to provide a scalable, multi-tenant observability platform for ingesting and querying logs and metrics and other observability signals. Its [documentation can be found on github](https://github.com/observatorium/docs)

## Rate limits

Observatorium implements rate limits through [Gubernator](https://github.com/mailgun/gubernator). The rate limits are configured per tenant in [app-interface](https://gitlab.cee.redhat.com/service/app-interface/blob/a711b7dbb690d8f7575d4614a89fb22a1ad68285/data/services/rhobs/observatorium-mst/cicd/saas-tenants.yaml#L40).

# Observatorium Metrics

Observatorium Metrics, which is a general-purpose, scalable, multi-tenant, observability platform for ingesting and querying metrics. Its [documentation can be found on github](https://github.com/observatorium/observatorium/blob/main/docs/design/metrics.md)

# Observatorium Logs

Observatorium logs implements a logging solution to allow multiple instances of OCP clusters store their logs to a central location. It is itself built on Observatorirum and Loki, which is a scalable multi-tenant platform for ingesting and querying logs. Its [documentation can be found on github](https://github.com/observatorium/docs/blob/master/design/logs.md). Loki's documentation be found on [Grafana Loki Documentation](https://grafana.com/docs/loki/latest/configuration/) page.

![high level architecture](observatorium-logs.png)

# Resources

## Endpoints

| Endpoint | Description | URL |
|---|---|---|
| observatorium-logs | The Observatorium Logs API | https://observatorium.api.openshift.com/api/logs/v1/\<TENANT NAME\>/loki/api/v1/\<RESOURCE\> |
| observatorium-metrics | The Observatorium Metrics API | https://observatorium.api.openshift.com/api/metrics/v1/\<TENANT NAME\>/api/v1/\<RESOURCE\> |

## Source Code

| Resource | Location |
|---|---|
| API | https://github.com/observatorium/api |
| API OPA-AMS | https://github.com/observatorium/opa-ams |
| Config | https://github.com/observatorium/configuration |
| Upstream config | https://github.com/observatorium/observatorium |


## Dependencies
| Dependency | Description |
|---|---|
| sso.redhat.com | Authentication provider |
| AMS | Authorization provider |
