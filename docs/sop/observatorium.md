# SOP: Observatorium

<!-- TOC depthTo:2 -->

- Observatorium
    - [Verify components are running](#verify-components-are-running)
- Observatorium Proactive Monitoring
    - [ObservatoriumHttpTrafficErrorRateHigh](#observatoriumhttptrafficerrorratehigh)    
    - [ObservatoriumProActiveMetricsQueryErrorRateHigh](#observatoriumproactivemetricsqueryerrorratehigh)    
- Observatorium Tenants
    - [ObservatoriumTenantsFailedOIDCRegistrations](#observatoriumtenantsfailedoidcregistrations)
- Observatorium Logs
    - [LokiRequestErrors](#lokirequesterrors)
    - [LokiRequestPanics](#lokirequestpanics)
    - [LokiRequestLatency](#lokirequestlatency)
    - [LokiTenantRateLimitWarning](#lokitenantratelimitwarning)
    - [ObservatoriumAPILogsErrorsSLOBudgetBurn](#observatoriumapilogserrorsslobudgetburn)
- Observatorium Metrics
    - [ThanosCompactMultipleRunning](#thanoscompactmultiplerunning)
    - [ThanosCompactIsNotRunning](#thanoscompactisnotrunning)
    - [ThanosCompactHalted](#thanoscompacthalted)
    - [ThanosCompactHighCompactionFailures](#thanoscompacthighcompactionfailures)
    - [ThanosCompactBucketHighOperationFailures](#thanoscompactbuckethighoperationfailures)
    - [ThanosCompactHasNotRun](#thanoscompacthasnotrun)
    - [ThanosCompactIsDown](#thanoscompactisdown)
    - [ThanosQuerierGrpcServerErrorRate](#thanosqueriergrpcservererrorrate)
    - [ThanosQuerierGrpcClientErrorRate](#thanosqueriergrpcclienterrorrate)
    - [ThanosQuerierHighDNSFailures](#thanosquerierhighdnsfailures)
    - [ThanosQuerierInstantLatencyHigh](#thanosquerierinstantlatencyhigh)
    - [ThanosQuerierRangeLatencyHigh](#thanosquerierrangelatencyhigh)
    - [ThanosQuerierIsDown](#thanosqueryisdown)
    - [ThanosReceiveHttpRequestLatencyHigh](#thanosreceivehttprequestlatencyhigh)
    - [ThanosReceiveHighForwardRequestFailures](#thanosreceivehighforwardrequestfailures)
    - [ThanosReceiveHighHashringFileRefreshFailures](#thanosreceivehighhashringfilerefreshfailures)
    - [ThanosReceiveConfigReloadFailure](#thanosreceiveconfigreloadfailure)
    - [ThanosReceiveIsDown](#thanosreceiveisdown)
    - [ThanosStoreGrpcErrorRate](#thanosstoregrpcerrorrate)
    - [ThanosStoreSeriesGateLatencyHigh](#thanosstoreseriesgatelatencyhigh)
    - [ThanosStoreBucketHighOperationFailures](#thanosstorebuckethighoperationfailures)
    - [ThanosStoreObjstoreOperationLatencyHigh](#thanosstoreobjstoreoperationlatencyhigh)
    - [ThanosStoreIsDown](#thanosstoreisdown)
    - [ThanosReceiveControllerReconcileErrorRate](#thanosreceivecontrollerreconcileerrorrate)
    - [ThanosReceiveControllerConfigmapChangeErrorRate](#thanosreceivecontrollerconfigmapchangeerrorrate)
    - [ThanosReceiveControllerIsDown](#thanosreceivecontrollerisdown)
    - [ThanosReceiveConfigStale](#thanosreceiveconfigstale)
    - [ThanosReceiveConfigInconsistent](#thanosreceiveconfiginconsistent)
    - [ThanosReceiveNoUpload](#thanosreceivenoupload)
    - [ThanosRuleHighRuleEvaluationFailures](#thanosrulehighruleevaluationfailures)
    - [ThanosNoRuleEvaluations](#thanosnoruleevaluations)
    - [ThanosRuleRuleEvaluationLatencyHigh](#thanosruleruleevaluationlatencyhigh)
    - [ThanosRuleTSDBNotIngestingSamples](#thanosruletsdbnotingestingsamples)
    - [ThanosRuleIsDown](#thanosruleisdown)
    - [ObservatoriumAPIMetricsErrorsSLOBudgetBurn](#observatoriumapimetricserrorsslobudgetburn)
    - [GubernatorIsDown](#gubernatorisdown)
    - [Escalations](#escalations)

<!-- /TOC -->

---

## Verify components are running

Check targets are UP in app-sre Prometheus:

### Logs

- `loki-distributor`: https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-loki-distributor-production%2f0

- `loki-ingester`: https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-loki-ingester-production%2f0

- `loki-querier`: https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-loki-querier-production%2f0

- `loki-query-frontend`: https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-loki-query-frontend-production%2f0

- `loki-compactor`: https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-loki-compactor-production%2f0

### Metrics

- `thanos-querier`: https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-thanos-querier-production%2f0

- `thanos-receive`: https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-thanos-receive-default-production%2f0

- `thanos-store`: https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-thanos-store-production%2f0

- `thanos-receive-controller`: https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-thanos-receive-controller-production%2f0

- `thanos-compactor`: https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-thanos-compactor-production%2f0


---

## ObservatoriumHttpTrafficErrorRateHigh

### Impact

RHOBS API endpoints are either inaccessible to users or fail to serve the traffic as expected.

### Summary

Users of RHOBS are not able to access API endpoints for either reading, writing metrics. The ha-proxy router at OpenShift Dedicated cluster where the RHOBS is deployed is not returning OK responses.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-logs-production))
- Access to Vault secret for `tenants.yaml` (link for [staging](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre-stage/telemeter-stage/observatorium-observatorium-api); for [production](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre/telemeter-production/observatorium-observatorium-api) you will most likely need to contact [App-SRE](https://coreos.slack.com/archives/CCRND57FW))

### Steps
- Check for any outage at Red Hat SSO.
- Check the Vault secret for `tenants.yaml` (link for [staging](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre-stage/telemeter-stage/observatorium-observatorium-api); for [production](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre/telemeter-production/observatorium-observatorium-api) for valid Yaml content, valid tenant name, auth information under 'oidc', 'opa' sections and rate limiting information under 'rateLimits' section.
- Check the logs of Observatorium API deployment's for telemeter tenant [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/observatorium-production/deployments/observatorium-observatorium-api)
- Check the logs of Observatorium UP deployment's for telemeter tenant [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/observatorium-production/deployments/observatorium-observatorium-up)
- Check the logs of Observatorium API deployment's for MST tenant [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/observatorium-mst-production/deployments/observatorium-observatorium-mst-api)
- Check the logs of Observatorium UP deployment's for MST tenant [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/observatorium-mst-production/deployments/observatorium-observatorium-up)


## ObservatoriumProActiveMetricsQueryErrorRateHigh

### Impact

Any of of the downstream Observatorium services can cause queries to fail.

### Summary

Metrics queries generated by Proactive monitoring are failing.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-logs-production))
- Access to Vault secret for `tenants.yaml` (link for [staging](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre-stage/telemeter-stage/observatorium-observatorium-api); for [production](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre/telemeter-production/observatorium-observatorium-api) you will most likely need to contact [App-SRE](https://coreos.slack.com/archives/CCRND57FW))

### Steps
- Check the Vault secret for `tenants.yaml` (link for [staging](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre-stage/telemeter-stage/observatorium-observatorium-api); for [production](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre/telemeter-production/observatorium-observatorium-api) for valid Yaml content, valid tenant name, auth information under 'oidc' and 'opa' sections and rate limiting information under 'rateLimits' section.
- Check the logs of Observatorium UP deployment's for telemeter tenant [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/observatorium-production/deployments/observatorium-observatorium-up)
- Check the logs of Observatorium API deployment's for telemeter tenant [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/observatorium-production/deployments/observatorium-observatorium-api)
- Check the logs of Observatorium UP deployment's for MST tenant [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/observatorium-mst-production/deployments/observatorium-observatorium-up)
- Check the logs of Observatorium API deployment's for MST tenant [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/observatorium-mst-production/deployments/observatorium-observatorium-mst-api)

---
## ObservatoriumTenantsFailedOIDCRegistrations

### Impact

A tenant using OIDC provider for authentication failed to instantiate. Such tenant cannot write / read metrics or logs.

### Summary

There is either outage on the side of the OIDC provider or the tenant authorization is misconfigured.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-logs-production))
- Access to Vault secret for `tenants.yaml` (link for [staging](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre-stage/telemeter-stage/observatorium-observatorium-api); for [production](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre/telemeter-production/observatorium-observatorium-api) you will most likely need to contact [App-SRE](https://coreos.slack.com/archives/CCRND57FW))

### Steps

- Check the logs of Observatorium API deployment's [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-observatorium-api) to see the exact cause of failed OIDC registration.
- Check whether the particular OIDC provider is up and available and / or check external channels for any information about outages (e.g. emails about ongoing incident, provider's status page).
- If entries in `tenants.yaml` have been edited recently, ensure the tenants' configuration is valid. If not, correct the misconfigured entries and ask App-SRE to re-deploy the Observatorium API pods.

---

## LokiRequestErrors

### Impact

For users this means that the service as being unavailable due to returning too many errors.

### Summary

For the set availability guarantees the Loki distributor/query-frontend/querier are returning too many http errors when processing requests.

### Severity

`info`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-logs-production))
- Edit access to the Observatorium Logs namespaces:
  - `observatorium-logs-stage`
  - `observatorium-logs-production`

### Steps

- The api proxies requests to the Loki query-frontend or queriers (only for `tail` endpoint) and the Loki distributor so check the logs of all components.
- The Loki distributor and querier requests data downstream from the Loki ingester or directly from the S3 bucket so check ingester logs and S3 connectivity.
- Inspect the metrics for the api [dashboards](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADX/api?orgId=1&refresh=1m)
- Inspect the metrics for the Loki query-frontend/querier
- Inspect the metrics for the Loki distributor/ingester

## LokiRequestPanics

### Impact

For users this means that the service as being unavailable due to components failing with panics.

### Summary

For the set availability guarantees the Loki distributor/query-frontend/querier are producing too many panics when processing requests.

### Severity

`info`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-logs-production))
- Edit access to the Observatorium Logs namespaces:
  - `observatorium-logs-stage`
  - `observatorium-logs-production`

### Steps

- The api proxies requests to the Loki query-frontend or queriers (only for `tail` endpoint) and the Loki distributor so check the logs of all components.
- The Loki distributor and querier requests data downstream from the Loki ingester so check ingester logs.

## LokiRequestLatency

### Impact

For users this means the service as returning logs data too slow or timeouts.

### Summary

Loki components are slower than expected to conduct queries or process ingested streams.

### Severity

`info`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-logs-production))
- Edit access to the Observatorium Logs namespaces:
  - `observatorium-logs-stage`
  - `observatorium-logs-production`

### Steps

- The api proxies requests to the Loki query-frontend or queriers (only for `tail` endpoint) and the Loki distributor so check the logs of all components.
- The Loki distributor and querier requests data downstream from the Loki ingester or directly from the S3 bucket so check ingester logs and S3 connectivity.
- Inspect the metrics for the api [dashboards](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADX/api?orgId=1&refresh=1m)
- Inspect the metrics for the Loki query-frontend/querier
- Inspect the metrics for the Loki distributor/ingester

## LokiTenantRateLimitWarning

### Impact

For users this means the service as applying back-pressure on the log ingestion clients by returning 429 status codes.

### Summary

Loki components are behaving normal and as expected.

### Severity

`medium`

### Steps

- Inspect the tenant ID for the ingester [limits](https://grafana.app-sre.devshift.net/d/f6fe30815b172c9da7e813c15ddfe607/loki-operational?orgId=1&refresh=30s&var-logs=&var-metrics=telemeter-prod-01-prometheus&var-namespace=observatorium-logs-production&from=now-1h&to=now) panel.
- Contact the tenant administrator to adapt the client configuration.

## ObservatoriumAPILogsErrorsSLOBudgetBurn

### Impact

SLO breach or complete outage for ingesting and/or querying logs data.
For users this is means that the service as being unavailable due to returning too many errors.

### Summary

For the set availability guarantees the observatorium api or the Loki distributor/query-frontend/querier are returning too many http errors when processing requests.

### Severity

`high`

### Steps

- The api proxies requests to the Loki query-frontend or queriers (only for `tail` endpoint) and the Loki distributor so check the logs of all components.
- The Loki distributor and querier requests data downstream from the Loki ingester or directly from the S3 bucket so check ingester logs and S3 connectivity.
- Inspect the metrics for the api [dashboards](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADX/api?orgId=1&refresh=1m)
- Inspect the metrics for the Loki query-frontend/querier
- Inspect the metrics for the Loki distributor/ingester

---

## ThanosCompactMultipleCompactsAreRunning

### Impact

Consumers see inconsistent/wrong metrics. Metrics in long term storage may be corrupted.

### Summary

Multiple replicas of Thanos Compact shouldn't be running. This leads data corruption.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/651943d05a8123e32867b4673963f42b/thanos-compact?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1h&g0.expr=sum(up%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-compact/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosCompactHalted

### Impact

Consumers are waiting too long to get long term storage metrics.

### Summary

Thanos Compact has failed to run and now is halted.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/651943d05a8123e32867b4673963f42b/thanos-compact?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1h&g0.expr=thanos_compactor_halted%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-compact/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosCompactHighCompactionFailures

### Impact

Consumers are waiting too long to get long term storage metrics.

### Summary

Thanos Compact is failing to execute of compactions.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/651943d05a8123e32867b4673963f42b/thanos-compact?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1h&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(prometheus_tsdb_compactions_failed_total%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(prometheus_tsdb_compactions_total%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-compact/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosCompactBucketHighOperationFailures

### Impact

Consumers are waiting too long to get long term storage metrics.

### Summary

Thanos Compact fails to execute operations against bucket.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/651943d05a8123e32867b4673963f42b/thanos-compact?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1h&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_objstore_bucket_operation_failures_total%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_objstore_bucket_operations_total%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)%20&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-compact/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosCompactHasNotRun

### Impact

Consumers are waiting too long to get long term storage metrics.

### Summary

Thanos Compact has not uploaded anything for 24 hours.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/651943d05a8123e32867b4673963f42b/thanos-compact?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1h&g0.expr=(time()%20-%20max(thanos_objstore_bucket_last_successful_upload_time%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D))%0A%20%20%20%20%20%20%20%20%2F%2060%20%2F%2060&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-compact/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosQuerierGrpcServerErrorRate

### Impact

Consumers do not receive all available metrics. Queries are still being fulfilled, not all of them.
`e.g.` Grafana is not showing all available metrics.

### Summary

Thanos Queriers are failing to handle incoming gRPC requests.
Thanos Query implements Store API, which means it serves metrics from its connected stores.
Indicated query job/pod having issues.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/98fde97ddeaf2981041745f1f2ba68c2/thanos-querier?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m&refresh=10s) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1y&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_server_handled_total%7Bgrpc_code%3D~%22Unknown%7CResourceExhausted%7CInternal%7CUnavailable%22%2C%20job%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_server_started_total%7Bjob%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-query).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosQuerierGrpcClientErrorRate

### Impact

Consumers do not receive all available metrics. Queries are still being fulfilled, not all of them.
`e.g.` Grafana is not showing all available metrics.

### Summary

Thanos Queriers are failing to send or get response from query requests to components which conforms Store API (Store/Sidecar/Receive),
Certain amount of the requests that querier makes to other Store API components are failing, which means that most likely the other component having issues.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/98fde97ddeaf2981041745f1f2ba68c2/thanos-querier?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m&refresh=10s) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1y&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_client_handled_total%7Bgrpc_code!%3D%22OK%22%2C%20job%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_client_started_total%7Bjob%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-query).
- Inspect logs and events of depending jobs, like [store](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-store-shard-0), [receivers](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default) (There maybe more than one receive component and store shard deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive and store components).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosQuerierHighDNSFailures

### Impact

Consumers do not receive all available metrics. Queries are still being fulfilled, not all of them.
`e.g.` Grafana is not showing all available metrics.

### Summary

Thanos Queriers are failing to discover components which conforms Store API (Store/Sidecar/Receive) to query.
Queriers use DNS Service discovery to discover related components.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/98fde97ddeaf2981041745f1f2ba68c2/thanos-querier?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m&refresh=10s) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1d&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_querier_store_apis_dns_failures_total%7Bjob%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_querier_store_apis_dns_lookups_total%7Bjob%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-query).
- Inspect logs and events of depending jobs, like [store](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-store-shard-0), [receivers](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default) (There maybe more than one receive component and store shard deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive components).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosQuerierInstantLatencyHigh

### Impact

Consumers are waiting too long to get metrics.
`e.g.` Grafana is timing out or too slow to render panels.

### Summary

Thanos Queriers are slower than expected to conduct instant vector queries.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/98fde97ddeaf2981041745f1f2ba68c2/thanos-querier?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m&refresh=10s) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1d&g0.expr=histogram_quantile(0.99%2C%0A%20%20%20%20%20%20%20%20%20%20sum(http_request_duration_seconds_bucket%7Bjob%3D~"thanos-querier.*"%2Cnamespace%3D"telemeter-production"%2C%20handler%3D"query"%7D)%20by%20(job%2C%20le)%0A%20%20%20%20%20%20%20%20)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-query).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosQuerierRangeLatencyHigh

### Impact

Consumers are waiting too long to get metrics.
`e.g.` Grafana is timing out or too slow to render panels.

### Summary

Thanos Queriers are slower than expected to conduct range vector queries.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/98fde97ddeaf2981041745f1f2ba68c2/thanos-querier?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m&refresh=10s) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1d&g0.expr=histogram_quantile(0.99%2C%0A%20%20%20%20%20%20%20%20%20%20sum(http_request_duration_seconds_bucket%7Bjob%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%2C%20handler%3D%22query_range%22%7D)%20by%20(job%2C%20le)%0A%20%20%20%20%20%20%20%20)%20&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-query).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosReceiveHttpRequestLatencyHigh

### Impact

Observatorium is too slow to ingest metrics.
`e.g.` Telemeter client is timing out or too slow to send metrics.

### Summary

Thanos Receives are slower than expected to handle incoming requests.
Thanos Receive ingests time series from Prometheus remote write or any other requester.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=10m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1d&g0.expr=histogram_quantile(0.99%2C%0A%20%20%20%20%20%20%20%20%20%20sum(http_request_duration_seconds_bucket%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%2C%20handler%3D%22receive%22%7D)%20by%20(job%2C%20le)%0A%20%20%20%20%20%20%20%20)%20&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default/pods). There maybe more than one receive component deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosReceiveHighForwardRequestFailures

### Impact

Observatorium is not ingesting all metrics.
It might lose data.

### Summary

Thanos Receives are failing to forward incoming requests to other receive nodes in the hash-ring.
Some of Thanos Receives in the hash-ring might be failing.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=10m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_forward_requests_total%7Bresult%3D%22error%22%2C%20job%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_forward_requests_total%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default/pods). (There maybe more than one receive component deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosReceiveHighHashringFileRefreshFailures

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

Thanos Receives are failing to reload the hash-ring configuration files.
They might be using stale version of configuration.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=10m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_hashrings_file_errors_total%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_hashrings_file_refreshes_total%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default/pods). (There maybe more than one receive component deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Inspect logs, events and latest changes of [`thanos-receive-controller`](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-receive-controller)
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosReceiveConfigReloadFailure

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

Thanos Receives failed to reload the latest configuration files.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=10m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=avg(thanos_receive_config_last_reload_successful%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default/pods). (There maybe more than one receive component deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Inspect logs, events and latest changes of [`thanos-receive-controller`](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-receive-controller)
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosStoreGrpcErrorRate

### Impact

Consumers are not getting long term storage metrics.

### Summary

Thanos Stores are failing to handle incoming gRPC requests.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_server_handled_total%7Bgrpc_code%3D~%22Unknown%7CResourceExhausted%7CInternal%7CUnavailable%22%2C%20job%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_server_started_total%7Bjob%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-store-shard-0/pods). There maybe more than one store shard deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive and store components.
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosStoreSeriesGateLatencyHigh

### Impact

Consumers are waiting too long to get long term storage metrics.

### Summary

Thanos Stores are slower than expected to get series from buckets.
A store series gate is a limiter which limits the maximum amount of concurrent queries. Queries are waiting longer at the gate than expected, stores might be under heavy load. This could also cause high memory utilization.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Check saturation of stores, using [dashboards](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m), try scaling up if it's the issue.
- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=histogram_quantile(0.99%2C%0A%20%20%20%20%20%20%20%20%20%20sum(thanos_bucket_store_series_gate_duration_seconds_bucket%7Bjob%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D)%20by%20(job%2C%20le)%0A%20%20%20%20%20%20%20%20)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-store-shard-0/pods). There maybe more than one store shard deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available store shards.
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosStoreBucketHighOperationFailures

### Impact

Consumers are not getting long term storage metrics.

### Summary

Thanos Stores are failing to conduct operations against buckets.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_objstore_bucket_operation_failures_total%7Bjob%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_objstore_bucket_operations_total%7Bjob%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-store-shard-0/pods). There maybe more than one store shard deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available store shards.
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosStoreObjstoreOperationLatencyHigh

### Impact

Consumers are not getting long term storage metrics.

### Summary

Thanos Stores are slower than expected to conduct operations against buckets.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=histogram_quantile(0.99%2C%0A%20%20%20%20%20%20%20%20%20%20sum(thanos_objstore_bucket_operation_duration_seconds_bucket%7Bjob%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D)%20by%20(job%2C%20le)%0A%20%20%20%20%20%20%20%20)%20&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-store-shard-0/pods). There maybe more than one store shard deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available store shards.
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosReceiveControllerReconcileErrorRate

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

Thanos Receive Controller is failing to reconcile changes.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Make sure provided [configuration](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/configmaps/observatorium-thanos-receive-controller-tenants) is correct (There might be others, check all [configmaps](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/configmaps)).
- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/858503cdeb29690fd8946e038f01ba85/thanos-receive-controller?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=sum(rate(thanos_receive_controller_reconcile_errors_total%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%2F%0A%20%20%20%20%20%20%20%20%20%20on%20(namespace)%20group_left%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_controller_reconcile_attempts_total%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D))%0A%20%20%20%20%20%20%20%20%20&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-receive-controller).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosReceiveControllerConfigmapChangeErrorRate

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

Thanos Receive Controller is failing to change configmaps.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Make sure concerning `kube-apiserver` is accessible.
- Make sure provided [configuration](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/configmaps/observatorium-thanos-receive-controller-tenants) is correct (There might be others, check all [configmaps](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/configmaps)).
- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/858503cdeb29690fd8946e038f01ba85/thanos-receive-controller?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_controller_configmap_change_errors_total%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20on%20(namespace)%20group_left%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_controller_configmap_change_attempts_total%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-receive-controller).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosReceiveConfigStale

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

The configuration of the instances of Thanos Receive are old compare to Receive Controller configuration.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Make sure provided [configuration](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/configmaps/observatorium-thanos-receive-controller-tenants) is correct (There might be others, check all [configmaps](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/configmaps)).
- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/858503cdeb29690fd8946e038f01ba85/thanos-receive-controller?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=avg(thanos_receive_config_last_reload_success_timestamp_seconds%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D)%20by%20(namespace%2C%20job)%0A%20%20%20%20%20%20%20%20%20%20%3C%0A%20%20%20%20%20%20%20%20on(namespace)%0A%20%20%20%20%20%20%20%20thanos_receive_controller_configmap_last_reload_success_timestamp_seconds%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-receive-controller).
- Inspect logs and events of `receive` jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default/pods). (There maybe more than one receive component deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosReceiveConfigInconsistent

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

The configuration of the instances of Thanos Receive are not same with Receive Controller configuration.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Make sure provided [configuration](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/configmaps/observatorium-thanos-receive-controller-tenants) is correct (There might be others, check all [configmaps](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/configmaps)).
- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/858503cdeb29690fd8946e038f01ba85/thanos-receive-controller?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=avg(thanos_receive_config_hash%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D)%20BY%20(namespace%2C%20job)%0A%20%20%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20on%20(namespace)%0A%20%20%20%20%20%20%20%20group_left%0A%20%20%20%20%20%20%20%20thanos_receive_controller_configmap_hash%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-receive-controller).
- Inspect logs and events of `receive` jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default/pods). (There maybe more than one receive component deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosRuleHighRuleEvaluationFailures
## ThanosNoRuleEvaluations
## ThanosRuleRuleEvaluationLatencyHigh

### Impact

If the evaluation failures are too high are or the evaluation latency is too high, a *symptom* is, that we may end up **losing data** or are **unable to alert**.

### Summary

Both Thanos Rule replicas fail to evaluate or too slow to evaluate certain recording rules or alerts.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

Thanos Rulers are querying Thanos Queriers like any other user of Thanos, in turn the Thanos Querier reaches out to the Thanos Store and Thanos Receivers.

- Check the [Thanos Rule dashboard](https://grafana.app-sre.devshift.net/d/35da848f5f92b2dc612e0c3a0577b8a1/thanos-rule?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) to get a general overview.
- Check the [Thanos Query dashboard](https://grafana.app-sre.devshift.net/d/af36c91291a603f1d9fbdabdd127ac4a/thanos-query?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m). Most likely you can focus on the Instant Query API RED metrics.
- Drill down into the [Thanos Store dashboard](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) and [Thanos Receiver dashboard](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m). Depending on which one of them has the same elevated error rate, concentrate on that component.
   - Probably, the Thanos Receiver is the problem, as the Thanos Ruler mostly looks at very recent data (like last 5min).
- Now that you, hopefully, know which component is causing the errors, dive into its logs, query it's raw metrics (check the dashboards as examples).
   - Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ThanosReceiveNoUpload

### Impact

### Summary

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Log onto the cluster and run: `oc rollout restart statefulset observatorium-thanos-receive-default`

NOTE: This must be done with a 4.x version of the oc client.

---

## ThanosRuleTSDBNotIngestingSamples

### Impact

Non-revertable gap in recording rules' data (dropped sample) or not evaluates alerts (missed alert).

### Summary

Both Thanos Rule replicas internal TSDB failed to ingest samples.

### Severity

`critical`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Recently we are hitting some issues where both replicas are stuck. We are investigating, but both replica pod restart mitigates the problem for some time (days). See: https://issues.redhat.com/browse/OBS-210
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatbility-thanos-rule/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## MandatoryThanosComponentIsDown
## ThanosCompactIsDown
## ThanosQueryIsDown
## ThanosReceiveIsDown
## ThanosStoreIsDown
## ThanosReceiveControllerIsDown
## ThanosRuleIsDown

### Impact

The Observatorium service is degraded. It might not be fulling all the promised functionality.

### Summary

Respective component that is supposed to be running is not running.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/dashboards/f/MQilB9tMk/observatorium) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/targets).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## ObservatoriumAPIMetricsErrorsSLOBudgetBurn

### Impact

SLO breach or complete outage for ingesting and/or querying metrics data.
For users this is means that the service as being unavailable due to returning too many errors.

### Summary

For the set availability guarantees the observatorium api or the thanos receiver/qerier are returning too many http errors when processing requests.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- The api proxies requests to the thanos querier and the thanos receiver so check the logs of all components.
- Inspect the metrics for the api [dashboards](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADX/api?orgId=1&refresh=1m)
- Inspect the metrics for the thanos querier [dashboards](https://grafana.app-sre.devshift.net/d/98fde97ddeaf2981041745f1f2ba68c2/thanos-querier?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus)
- Inspect the metrics for the thanos receiver [dashboards](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus)

---

## GubernatorIsDown

### Impact

Observatorium is not ingesting or giving access to data that belongs to the tenants with defined rate limits.

### Summary

Observatorium rate-limiting service is not working.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=%7Bjob%3D~%22observatorium-gubernator%22%7D&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-gubernator).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

## Escalations

Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack.
