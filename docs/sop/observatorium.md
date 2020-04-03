# SOP: Observatorium

<!-- TOC depthTo:2 -->

- Observatorium
    - [Verify components are running](#verify-components-are-running)
    - [ThanosCompactMultipleCompactsAreRunning](#thanoscompactmultiplecompactsarerunning)
    - [ThanosCompactIsNotRunning](#thanoscompactisnotrunning)
    - [ThanosCompactHalted](#thanoscompacthalted)
    - [ThanosCompactHighCompactionFailures](#thanoscompacthighcompactionfailures)
    - [ThanosCompactBucketHighOperationFailures](#thanoscompactbuckethighoperationfailures)
    - [ThanosCompactHasNotRun](#thanoscompacthasnotrun)
    - [ThanosQuerierGrpcServerErrorRate](#thanosqueriergrpcservererrorrate)
    - [ThanosQuerierGrpcClientErrorRate](#thanosqueriergrpcclienterrorrate)
    - [ThanosQuerierHighDNSFailures](#thanosquerierhighdnsfailures)
    - [ThanosQuerierInstantLatencyHigh](#thanosquerierinstantlatencyhigh)
    - [ThanosQuerierRangeLatencyHigh](#thanosquerierrangelatencyhigh)
    - [ThanosReceiveHttpRequestLatencyHigh](#thanosreceivehttprequestlatencyhigh)
    - [ThanosReceiveHighForwardRequestFailures](#thanosreceivehighforwardrequestfailures)
    - [ThanosReceiveHighHashringFileRefreshFailures](#thanosreceivehighhashringfilerefreshfailures)
    - [ThanosReceiveConfigReloadFailure](#thanosreceiveconfigreloadfailure)
    - [ThanosStoreGrpcErrorRate](#thanosstoregrpcerrorrate)
    - [ThanosStoreSeriesGateLatencyHigh](#thanosstoreseriesgatelatencyhigh)
    - [ThanosStoreBucketHighOperationFailures](#thanosstorebuckethighoperationfailures)
    - [ThanosStoreObjstoreOperationLatencyHigh](#thanosstoreobjstoreoperationlatencyhigh)
    - [ThanosReceiveControllerReconcileErrorRate](#thanosreceivecontrollerreconcileerrorrate)
    - [ThanosReceiveControllerConfigmapChangeErrorRate](#thanosreceivecontrollerconfigmapchangeerrorrate)
    - [ThanosReceiveConfigStale](#thanosreceiveconfigstale)
    - [ThanosReceiveConfigInconsistent](#thanosreceiveconfiginconsistent)

<!-- /TOC -->

---

## Verify components are running

Check targets are UP in app-sre Prometheus:

- `thanos-querier`: https://prometheus.app-sre.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-thanos-querier-production%2f0

- `thanos-receive`: https://prometheus.app-sre.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-thanos-receive-default-production%2f0

- `thanos-store`: https://prometheus.app-sre.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-thanos-store-production%2f0

- `thanos-receive-controller`: https://prometheus.app-sre.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-thanos-receive-controller-production%2f0

- `thanos-compactor`: https://prometheus.app-sre.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-thanos-compactor-production%2f0

---

## ThanosCompactMultipleCompactsAreRunning

### Impact

Consumers see inconsistent/wrong metrics. Metrics in long term storage may be corrupted.

### Summary

Multiple replicas of Thanos Compact shouldn't be running. This leads data corruption.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/651943d05a8123e32867b4673963f42b/thanos-compact?orgId=1&refresh=10s&var-datasource=app-sre-prometheus&var-namespace=&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=1h&g0.expr=sum(up%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-compactor/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

## ThanosCompactHalted

### Impact

Consumers are waiting too long to get long term storage metrics.

### Summary

Thanos Compact has failed to run and now is halted.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/651943d05a8123e32867b4673963f42b/thanos-compact?orgId=1&refresh=10s&var-datasource=app-sre-prometheus&var-namespace=&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=1h&g0.expr=thanos_compactor_halted%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-compactor/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

## ThanosCompactHighCompactionFailures

### Impact

Consumers are waiting too long to get long term storage metrics.

### Summary

Thanos Compact is failing to execute of compactions.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/651943d05a8123e32867b4673963f42b/thanos-compact?orgId=1&refresh=10s&var-datasource=app-sre-prometheus&var-namespace=&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=1h&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(prometheus_tsdb_compactions_failed_total%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(prometheus_tsdb_compactions_total%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-compactor/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

## ThanosCompactBucketHighOperationFailures

### Impact

Consumers are waiting too long to get long term storage metrics.

### Summary

Thanos Compact fails to execute operations against bucket.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/651943d05a8123e32867b4673963f42b/thanos-compact?orgId=1&refresh=10s&var-datasource=app-sre-prometheus&var-namespace=&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=1h&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_objstore_bucket_operation_failures_total%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_objstore_bucket_operations_total%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)%20&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-compactor/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

## ThanosCompactHasNotRun

### Impact

Consumers are waiting too long to get long term storage metrics.

### Summary

Thanos Compact has not uploaded anything for 24 hours.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/651943d05a8123e32867b4673963f42b/thanos-compact?orgId=1&refresh=10s&var-datasource=app-sre-prometheus&var-namespace=&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=1h&g0.expr=(time()%20-%20max(thanos_objstore_bucket_last_successful_upload_time%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D))%0A%20%20%20%20%20%20%20%20%2F%2060%20%2F%2060&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-compactor/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

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

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/98fde97ddeaf2981041745f1f2ba68c2/thanos-querier?orgId=1&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m&refresh=10s) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=1y&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_server_handled_total%7Bgrpc_code%3D~%22Unknown%7CResourceExhausted%7CInternal%7CUnavailable%22%2C%20job%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_server_started_total%7Bjob%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/deployments/thanos-querier/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

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

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/98fde97ddeaf2981041745f1f2ba68c2/thanos-querier?orgId=1&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m&refresh=10s) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=1y&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_client_handled_total%7Bgrpc_code!%3D%22OK%22%2C%20job%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_client_started_total%7Bjob%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/deployments/thanos-querier/pods).
- Inspect logs and events of depending jobs, like [store](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-store), [receivers](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-receive-default) (There maybe more than one receive component deployed, check all other [statefulsets](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets) to find available receive components).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

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

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/98fde97ddeaf2981041745f1f2ba68c2/thanos-querier?orgId=1&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m&refresh=10s) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=1d&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_querier_store_apis_dns_failures_total%7Bjob%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_querier_store_apis_dns_lookups_total%7Bjob%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/deployments/thanos-querier/pods).
- Inspect logs and events of depending jobs, like [store](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-store), [receivers](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-receive-default) (There maybe more than one receive component deployed, check all other [statefulsets](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets) to find available receive components).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

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

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/98fde97ddeaf2981041745f1f2ba68c2/thanos-querier?orgId=1&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m&refresh=10s) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=1d&g0.expr=histogram_quantile(0.99%2C%0A%20%20%20%20%20%20%20%20%20%20sum(http_request_duration_seconds_bucket%7Bjob%3D~"thanos-querier.*"%2Cnamespace%3D"telemeter-production"%2C%20handler%3D"query"%7D)%20by%20(job%2C%20le)%0A%20%20%20%20%20%20%20%20)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/deployments/thanos-querier/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

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

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/98fde97ddeaf2981041745f1f2ba68c2/thanos-querier?orgId=1&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m&refresh=10s) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=1d&g0.expr=histogram_quantile(0.99%2C%0A%20%20%20%20%20%20%20%20%20%20sum(http_request_duration_seconds_bucket%7Bjob%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%2C%20handler%3D%22query_range%22%7D)%20by%20(job%2C%20le)%0A%20%20%20%20%20%20%20%20)%20&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/deployments/thanos-querier/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

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

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=10m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=1d&g0.expr=histogram_quantile(0.99%2C%0A%20%20%20%20%20%20%20%20%20%20sum(http_request_duration_seconds_bucket%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%2C%20handler%3D%22receive%22%7D)%20by%20(job%2C%20le)%0A%20%20%20%20%20%20%20%20)%20&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-receive-default/pods). There maybe more than one receive component deployed, check all other [statefulsets](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

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

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=10m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=15m&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_forward_requests_total%7Bresult%3D%22error%22%2C%20job%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_forward_requests_total%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-receive-default/pods). (There maybe more than one receive component deployed, check all other [statefulsets](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

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

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=10m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=15m&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_hashrings_file_errors_total%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_hashrings_file_refreshes_total%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-receive-default/pods). (There maybe more than one receive component deployed, check all other [statefulsets](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Inspect logs, events and latest changes of [`thanos-receive-controller`](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/deployments/thanos-receive-controller/pods)
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

---

## ThanosReceiveConfigReloadFailure

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

Thanos Receives failed to reload the latest configuration files.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=10m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=15m&g0.expr=avg(thanos_receive_config_last_reload_successful%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-receive-default/pods). (There maybe more than one receive component deployed, check all other [statefulsets](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Inspect logs, events and latest changes of [`thanos-receive-controller`](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/deployments/thanos-receive-controller/pods)
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

---

## ThanosStoreGrpcErrorRate

### Impact

Consumers are not getting long term storage metrics.

### Summary

Thanos Stores are failing to handle incoming gRPC requests.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=15m&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_server_handled_total%7Bgrpc_code%3D~%22Unknown%7CResourceExhausted%7CInternal%7CUnavailable%22%2C%20job%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_server_started_total%7Bjob%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-store/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

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

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Check saturation of stores, using [dashboards](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m), try scaling up if it's the issue.
- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=15m&g0.expr=histogram_quantile(0.99%2C%0A%20%20%20%20%20%20%20%20%20%20sum(thanos_bucket_store_series_gate_duration_seconds_bucket%7Bjob%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D)%20by%20(job%2C%20le)%0A%20%20%20%20%20%20%20%20)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-store/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

---

## ThanosStoreBucketHighOperationFailures

### Impact

Consumers are not getting long term storage metrics.

### Summary

Thanos Stores are failing to conduct operations against buckets.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=15m&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_objstore_bucket_operation_failures_total%7Bjob%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_objstore_bucket_operations_total%7Bjob%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-store/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

---

## ThanosStoreObjstoreOperationLatencyHigh

### Impact

Consumers are not getting long term storage metrics.

### Summary

Thanos Stores are slower than expected to conduct operations against buckets.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=15m&g0.expr=histogram_quantile(0.99%2C%0A%20%20%20%20%20%20%20%20%20%20sum(thanos_objstore_bucket_operation_duration_seconds_bucket%7Bjob%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D)%20by%20(job%2C%20le)%0A%20%20%20%20%20%20%20%20)%20&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-store/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

---

## ThanosReceiveControllerReconcileErrorRate

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

Thanos Receive Controller is failing to reconcile changes.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Make sure provided [configuration](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/configmaps/observatorium-tenants) is correct (There might be others, check all [configmaps](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/configmaps)).
- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/858503cdeb29690fd8946e038f01ba85/thanos-receive-controller?orgId=1&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=15m&g0.expr=sum(rate(thanos_receive_controller_reconcile_errors_total%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%2F%0A%20%20%20%20%20%20%20%20%20%20on%20(namespace)%20group_left%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_controller_reconcile_attempts_total%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D))%0A%20%20%20%20%20%20%20%20%20&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/deployments/thanos-receive-controller/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

---

## ThanosReceiveControllerConfigmapChangeErrorRate

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

Thanos Receive Controller is failing to change configmaps.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Make sure concerning `kube-apiserver` is accessible.
- Make sure provided [configuration](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/configmaps/observatorium-tenants) is correct (There might be others, check all [configmaps](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/configmaps)).
- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/858503cdeb29690fd8946e038f01ba85/thanos-receive-controller?orgId=1&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=15m&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_controller_configmap_change_errors_total%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20on%20(namespace)%20group_left%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_controller_configmap_change_attempts_total%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/deployments/thanos-receive-controller/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

---

## ThanosReceiveConfigStale

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

The configuration of the instances of Thanos Receive are old compare to Receive Controller configuration.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Make sure provided [configuration](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/configmaps/observatorium-tenants) is correct (There might be others, check all [configmaps](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/configmaps)).
- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/858503cdeb29690fd8946e038f01ba85/thanos-receive-controller?orgId=1&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=15m&g0.expr=avg(thanos_receive_config_last_reload_success_timestamp_seconds%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D)%20by%20(namespace%2C%20job)%0A%20%20%20%20%20%20%20%20%20%20%3C%0A%20%20%20%20%20%20%20%20on(namespace)%0A%20%20%20%20%20%20%20%20thanos_receive_controller_configmap_last_reload_success_timestamp_seconds%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/deployments/thanos-receive-controller/pods).
- Inspect logs and events of `receive` jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-receive-default/pods). (There maybe more than one receive component deployed, check all other [statefulsets](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

---

## ThanosReceiveConfigInconsistent

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

The configuration of the instances of Thanos Receive are not same with Receive Controller configuration.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [app-sre OSD](https://admin-console.app-sre.openshift.com/status/ns/telemeter-production))
- Edit access to the Telemeter namespaces (Observatorium uses Telemeter namespaces):
  - `telemeter-stage`
  - `telemeter-production`

### Steps

- Make sure provided [configuration](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/configmaps/observatorium-tenants) is correct (There might be others, check all [configmaps](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/configmaps)).
- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/858503cdeb29690fd8946e038f01ba85/thanos-receive-controller?orgId=1&var-datasource=app-sre-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](https://prometheus.app-sre.devshift.net/graph?g0.range_input=15m&g0.expr=avg(thanos_receive_config_hash%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D)%20BY%20(namespace%2C%20job)%0A%20%20%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20on%20(namespace)%0A%20%20%20%20%20%20%20%20group_left%0A%20%20%20%20%20%20%20%20thanos_receive_controller_configmap_hash%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/deployments/thanos-receive-controller/pods).
- Inspect logs and events of `receive` jobs, using [OpenShift console](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets/thanos-receive-default/pods). (There maybe more than one receive component deployed, check all other [statefulsets](https://admin-console.app-sre.openshift.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack, to get help in the investigation.

---

## Escalations

Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack.
