# RHOBS Observatorium Runbooks

<!-- TOC depthTo:2 -->
* [RHOBS Observatorium Runbooks](#rhobs-observatorium-runbooks)
  * [Quick Links](#quick-links)
  * [Verify components are running](#verify-components-are-running)
* [SLO Alerts](#slo-alerts)
  * [TelemeterServerMetricsUploadWriteAvailabilityErrorBudgetBurning](#telemeterservermetricsuploadwriteavailabilityerrorbudgetburning)
  * [TelemeterServerMetricsReceiveWriteAvailabilityErrorBudgetBurning](#telemeterservermetricsreceivewriteavailabilityerrorbudgetburning)
  * [TelemeterServerMetricsUploadWriteLatencyErrorBudgetBurning](#telemeterservermetricsuploadwritelatencyerrorbudgetburning)
  * [TelemeterServerMetricsReceiveWriteLatencyErrorBudgetBurning](#telemeterservermetricsreceivewritelatencyerrorbudgetburning)
  * [APIMetricsWriteAvailabilityErrorBudgetBurning](#apimetricswriteavailabilityerrorbudgetburning)
  * [APIMetricsWriteLatencyErrorBudgetBurning](#apimetricswritelatencyerrorbudgetburning)
  * [APIMetricsReadAvailabilityErrorBudgetBurning](#apimetricsreadavailabilityerrorbudgetburning)
  * [APIMetricsReadLatencyErrorBudgetBurning](#apimetricsreadlatencyerrorbudgetburning)
  * [APIRulesRawWriteAvailabilityErrorBudgetBurning](#apirulesrawwriteavailabilityerrorbudgetburning)
  * [APIRulesSyncAvailabilityErrorBudgetBurning](#apirulessyncavailabilityerrorbudgetburning)
  * [APIRulesReadAvailabilityErrorBudgetBurning](#apirulesreadavailabilityerrorbudgetburning)
  * [APIRulesRawReadAvailabilityErrorBudgetBurning](#apirulesrawreadavailabilityerrorbudgetburning)
  * [APIAlertmanagerAvailabilityErrorBudgetBurning](#apialertmanageravailabilityerrorbudgetburning)
  * [APIAlertmanagerNotificationsAvailabilityErrorBudgetBurning](#apialertmanagernotificationsavailabilityerrorbudgetburning)
* [Observatorium HTTP Traffic Alerts](#observatorium-http-traffic-alerts)
  * [ObservatoriumHttpTrafficErrorRateHigh](#observatoriumhttptrafficerrorratehigh)
* [Observatorium Proactive Monitoring Alerts](#observatorium-proactive-monitoring-alerts)
  * [ObservatoriumProActiveMetricsQueryErrorRateHigh](#observatoriumproactivemetricsqueryerrorratehigh)
* [Observatorium Tenants Alerts](#observatorium-tenants-alerts)
  * [ObservatoriumTenantsFailedOIDCRegistrations](#observatoriumtenantsfailedoidcregistrations)
  * [ObservatoriumTenantsSkippedDuringConfiguration](#observatoriumtenantsskippedduringconfiguration)
* [Observatorium Custom Metrics Alerts](#observatorium-custom-metrics-alerts)
  * [ObservatoriumNoStoreBlocksLoaded](#observatoriumnostoreblocksloaded)
  * [ObservatoriumNoRulesLoaded](#observatoriumnorulesloaded)
  * [ObservatoriumPersistentVolumeUsageHigh](#observatoriumpersistentvolumeusagehigh)
  * [ObservatoriumPersistentVolumeUsageCritical](#observatoriumpersistentvolumeusagecritical)
  * [ObservatoriumExpectedReplicasUnavailable](#observatoriumexpectedreplicasunavailable)
* [Observatorium Gubernator Alerts](#observatorium-gubernator-alerts)
  * [GubernatorIsDown](#gubernatorisdown)
* [Observatorium Obsctl Reloader Alerts](#observatorium-obsctl-reloader-alerts)
  * [ObsCtlIsDown](#obsctlisdown)
  * [ObsCtlRulesStoreServerError](#obsctlrulesstoreservererror)
  * [ObsCtlFetchRulesFailed](#obsctlfetchrulesfailed)
  * [ObsCtlRulesSetFailure](#obsctlrulessetfailure)
* [Observatorium Thanos Alerts](#observatorium-thanos-alerts)
  * [MandatoryThanosComponentIsDown](#mandatorythanoscomponentisdown)
  * [ThanosCompactIsDown](#thanoscompactisdown)
  * [ThanosQueryIsDown](#thanosqueryisdown)
  * [ThanosReceiveIsDown](#thanosreceiveisdown)
  * [ThanosStoreIsDown](#thanosstoreisdown)
  * [ThanosReceiveControllerIsDown](#thanosreceivecontrollerisdown)
  * [ThanosRuleIsDown](#thanosruleisdown)
  * [Thanos Compact](#thanos-compact)
  * [ThanosCompactMultipleRunning](#thanoscompactmultiplerunning)
  * [ThanosCompactHalted](#thanoscompacthalted)
  * [ThanosCompactHighCompactionFailures](#thanoscompacthighcompactionfailures)
  * [ThanosCompactBucketHighOperationFailures](#thanoscompactbuckethighoperationfailures)
  * [ThanosCompactHasNotRun](#thanoscompacthasnotrun)
  * [Thanos Query](#thanos-query)
  * [ThanosQueryHttpRequestQueryErrorRateHigh](#thanosqueryhttprequestqueryerrorratehigh)
  * [ThanosQueryGrpcServerErrorRate](#thanosquerygrpcservererrorrate)
  * [ThanosQueryGrpcClientErrorRate](#thanosquerygrpcclienterrorrate)
  * [ThanosQueryHighDNSFailures](#thanosqueryhighdnsfailures)
  * [ThanosQueryInstantLatencyHigh](#thanosqueryinstantlatencyhigh)
  * [Thanos Receive](#thanos-receive)
  * [ThanosReceiveHttpRequestErrorRateHigh](#thanosreceivehttprequesterrorratehigh)
  * [ThanosReceiveHttpRequestLatencyHigh](#thanosreceivehttprequestlatencyhigh)
  * [ThanosReceiveHighForwardRequestFailures](#thanosreceivehighforwardrequestfailures)
  * [ThanosReceiveHighHashringFileRefreshFailures](#thanosreceivehighhashringfilerefreshfailures)
  * [ThanosReceiveConfigReloadFailure](#thanosreceiveconfigreloadfailure)
  * [ThanosReceiveNoUpload](#thanosreceivenoupload)
  * [ThanosReceiveLimitsConfigReloadFailure](#thanosreceivelimitsconfigreloadfailure)
  * [ThanosReceiveLimitsHighMetaMonitoringQueriesFailureRate](#thanosreceivelimitshighmetamonitoringqueriesfailurerate)
  * [ThanosReceiveTenantLimitedByHeadSeries](#thanosreceivetenantlimitedbyheadseries)
  * [Thanos Store Gateway](#thanos-store-gateway)
  * [ThanosStoreGrpcErrorRate](#thanosstoregrpcerrorrate)
  * [ThanosStoreSeriesGateLatencyHigh](#thanosstoreseriesgatelatencyhigh)
  * [ThanosStoreBucketHighOperationFailures](#thanosstorebuckethighoperationfailures)
  * [ThanosStoreObjstoreOperationLatencyHigh](#thanosstoreobjstoreoperationlatencyhigh)
  * [Thanos Rule](#thanos-rule)
  * [ThanosRuleHighRuleEvaluationFailures](#thanosrulehighruleevaluationfailures)
  * [ThanosNoRuleEvaluations](#thanosnoruleevaluations)
  * [ThanosRuleRuleEvaluationLatencyHigh](#thanosruleruleevaluationlatencyhigh)
  * [ThanosRuleTSDBNotIngestingSamples](#thanosruletsdbnotingestingsamples)
  * [Thanos Receive Controller](#thanos-receive-controller)
  * [ThanosReceiveControllerReconcileErrorRate](#thanosreceivecontrollerreconcileerrorrate)
  * [ThanosReceiveControllerConfigmapChangeErrorRate](#thanosreceivecontrollerconfigmapchangeerrorrate)
  * [ThanosReceiveConfigStale](#thanosreceiveconfigstale)
  * [ThanosReceiveConfigInconsistent](#thanosreceiveconfiginconsistent)
* [Observatorium Alertmanager Alerts](#observatorium-alertmanager-alerts)
  * [AlertmanagerFailedReload](#alertmanagerfailedreload)
  * [AlertmanagerMembersInconsistent](#alertmanagermembersinconsistent)
  * [AlertmanagerFailedToSendAlerts](#alertmanagerfailedtosendalerts)
  * [AlertmanagerClusterFailedToSendAlerts](#alertmanagerclusterfailedtosendalerts)
  * [AlertmanagerConfigInconsistent](#alertmanagerconfiginconsistent)
  * [AlertmanagerClusterDown](#alertmanagerclusterdown)
  * [AlertmanagerClusterCrashlooping](#alertmanagerclustercrashlooping)
* [Observatorium Loki Alerts](#observatorium-loki-alerts)
  * [LokiRequestErrors](#lokirequesterrors)
  * [LokiRequestPanics](#lokirequestpanics)
  * [LokiRequestLatency](#lokirequestlatency)
  * [LokiTenantRateLimitWarning](#lokitenantratelimitwarning)
* [Escalations](#escalations)
<!-- /TOC -->

---

## Quick Links

- [RHOBS instance utilization dashboard](https://grafana.app-sre.devshift.net/d/dsqU07jVz/rhobs-instance-utilization-overview?orgId=1&refresh=10s)

### SLO Dashboards

#### Telemeter

- [Telemeter Production SLOs](https://grafana.app-sre.devshift.net/d/f9fa7677fb4a2669f123f9a0f2234b47/telemeter-production-slos)
- [Telemeter Staging SLOs](https://grafana.app-sre.devshift.net/d/080e53f245a15445bdf777ae0e66945d/telemeter-staging-slos?orgId=1)

#### MST

- [MST Production SLOs](https://grafana.app-sre.devshift.net/d/283e7002d85c08126681241df2fdb22b/mst-production-slos?orgId=1)
- [MST Staging SLOs](https://grafana.app-sre.devshift.net/d/92520ea4d6976f30d1618164e186ef9b/mst-stage-slos?orgId=1)

#### rhobsp02ue1

- [rhobsp02ue1 Production SLOs](https://grafana.app-sre.devshift.net/d/7f4df1c2d5518d5c3f2876ca9bb874a8/rhobsp02ue1-production-slos)

### Consoles

#### Telemeter

- [observatorium-production](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-production)
- [telemeter-production](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/telemeter-production)
- [observatorium-metrics-production](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-metrics-production)
- [observatorium-stage](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/k8s/cluster/projects/observatorium-stage)
- [telemeter-stage](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/k8s/cluster/projects/telemeter-stage)
- [observatorium-metrics-stage](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/k8s/cluster/projects/observatorium-metrics-stage)
- [telemeter-integration](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/k8s/cluster/projects/telemeter-integration)

#### MST

- [observatorium-mst-production](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-mst-production)
- [observatorium-mst-stage](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/k8s/cluster/projects/observatorium-mst-stage)

#### rhobsp02ue1

- [observatorium-mst-production](https://console-openshift-console.apps.rhobsp02ue1.y9ya.p1.openshiftapps.com/k8s/cluster/projects/observatorium-mst-production)

### Prometheii

- [telemeter-prod-01](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.expr=&g0.tab=1&g0.stacked=0&g0.show_exemplars=0&g0.range_input=1h) (MST and Telemeter prod instance)
- [app-sre-stage-01](https://prometheus.app-sre-stage-01.devshift.net/graph?g0.expr=&g0.tab=1&g0.stacked=0&g0.show_exemplars=0&g0.range_input=1h) (MST and Telemeter stage instance)
- [rhobsp02ue1](https://prometheus.rhobsp02ue1.devshift.net/graph?g0.expr=&g0.tab=1&g0.stacked=0&g0.show_exemplars=0&g0.range_input=1h)

### Miscellaneous

- [InfoGW Production](https://infogw-proxy.api.openshift.com/graph?g0.expr=&g0.tab=1&g0.stacked=0&g0.range_input=1h&g0.max_source_resolution=0s&g0.deduplicate=1&g0.partial_response=0&g0.store_matches=%5B%5D)
- [InfoGW Stage](https://infogw-proxy.api.stage.openshift.com/graph?g0.expr=&g0.tab=1&g0.stacked=0&g0.range_input=1h&g0.max_source_resolution=0s&g0.deduplicate=1&g0.partial_response=0&g0.store_matches=%5B%5D)
- [Telemeter Observatorium Production API](https://observatorium.api.openshift.com/)
- [Telemeter Observatorium Staging API](https://observatorium.api.stage.openshift.com/)
- [MST Observatorium Production API](https://observatorium-mst.api.openshift.com/)
- [MST Observatorium Staging API](https://observatorium-mst.api.stage.openshift.com/)
- [rhobsp02ue1 Observatorium Production API](https://rhobs.rhobsp02ue1.api.openshift.com/)
- [RHOBS Tenant Master Sheet](https://docs.google.com/spreadsheets/d/1SEw1fFASppT_mZOEW9-xQezLNH9DTtYPXSS0KkWLV04/edit)

## Verify components are running

Check targets are UP in app-sre Prometheus:

### Logs

- `loki-distributor`: <https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-loki-distributor-production%2f0>

- `loki-ingester`: <https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-loki-ingester-production%2f0>

- `loki-querier`: <https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-loki-querier-production%2f0>

- `loki-query-frontend`: <https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-loki-query-frontend-production%2f0>

- `loki-compactor`: <https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-loki-compactor-production%2f0>

### Metrics

- `thanos-querier`: <https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-thanos-querier-production%2f0>

- `thanos-receive`: <https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-thanos-receive-default-production%2f0>

- `thanos-store`: <https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-thanos-store-production%2f0>

- `thanos-receive-controller`: <https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-thanos-receive-controller-production%2f0>

- `thanos-compactor`: <https://prometheus.telemeter-prod-01.devshift.net/targets#job-app-sre-observability-production%2fobservatorium-thanos-compactor-production%2f0>

---

# SLO Alerts

## TelemeterServerMetricsUploadWriteAvailabilityErrorBudgetBurning

### Impact

Telemeter Server is currently failing to ingest metrics data via /upload endpoint over given time window.

### Summary

Telemeter Server is returning a high-enough level of 5XX responses to write requests that we are depleting our SLO error budget when ingesting metrics via /upload path.

### Severity

`critical`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))

### Steps

This alert indicates there is a problem on the metrics write path, so we need to verify the health of each of the involved components.

- Check on the health of Telemeter Server
  - Check the Telemeter [dashboard](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADJ/telemeter)
  - Check the logs of Telemeter Server pods.
    - Telemeter Server should log any 5XX requests.
  - Check authentication failures if any.
- Check on the health of the API.
  - Check the API [dashboard](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADX/api)
  - Check the logs on the API pods.
- Check on the health of Thanos Receive.
  - Check the Thanos Receive [dashboard](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive)
  - Check the logs of the Thanos Receive pods.
- Reach out to @observatorium-oncall or @observatorium-support in #forum-observatorium for help.

## TelemeterServerMetricsReceiveWriteAvailabilityErrorBudgetBurning

### Impact

Telemeter Server is currently failing to ingest metrics data via /metrics/v1/receive endpoint over given time window.

### Summary

Telemeter Server is returning a high-enough level of 5XX responses to write requests that we are depleting our SLO error budget when ingesting metrics via /metrics/v1/receive path.

### Severity

`critical`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))

### Steps

This alert indicates there is a problem on the metrics write path, so we need to verify the health of each of the involved components.

- Check on the health of Telemeter Server
  - Check the Telemeter [dashboard](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADJ/telemeter)
  - Check the logs of Telemeter Server pods.
    - Telemeter Server should log any 5XX requests.
  - Telemeter relays requests only in case of /metrics/v1/receive endpoint. Check [docs](https://github.com/openshift/telemeter/blob/master/README.md).
- Check on the health of the API.
  - Check the API [dashboard](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADX/api)
  - Check the logs on the API pods.
- Check on the health of Thanos Receive.
  - Check the Thanos Receive [dashboard](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive)
  - Check the logs of the Thanos Receive pods.
- Reach out to @observatorium-oncall or @observatorium-support in #forum-observatorium for help.

## TelemeterServerMetricsUploadWriteLatencyErrorBudgetBurning

### Impact

Telemeter Server /upload endpoint is taking longer than expected to ingest metrics data over given time window.

### Summary

Telemeter Server /upload is returning a high-enough level of slow responses to write requests that we are depleting our SLO error budget.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))

### Steps

- Check on the health of Telemeter Server
  - Check the Telemeter [dashboard](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADJ/telemeter)
  - Check the logs of Telemeter Server pods.
    - Telemeter Server should log any 5XX requests.
- Check on the health of the API.
  - Check the API [dashboard](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADX/api)
  - Check the logs on the API pods.
- Check on the health of Thanos Receive.
  - Check the Thanos Receive [dashboard](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive)
  - Check the logs of the Thanos Receive pods.
- Find and inspect a slow query in [Jaeger](https://observatorium-jaeger.api.openshift.com/search)
- Reach out to @observatorium-oncall or @observatorium-support in #forum-observatorium for help.

## TelemeterServerMetricsReceiveWriteLatencyErrorBudgetBurning

### Impact

Telemeter Server /metrics/v1/receive endpoint is taking longer than expected to ingest metrics data over given time window.

### Summary

Telemeter Server /metrics/v1/receive is returning a high-enough level of slow responses to write requests that we are depleting our SLO error budget.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))

### Steps

- Check on the health of Telemeter Server
  - Check the Telemeter [dashboard](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADJ/telemeter)
  - Check the logs of Telemeter Server pods.
    - Telemeter Server should log any 5XX requests.
  - Telemeter relays requests only in case of /metrics/v1/receive endpoint. Check [docs](https://github.com/openshift/telemeter/blob/master/README.md).
- Check on the health of the API.
  - Check the API [dashboard](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADX/api)
  - Check the logs on the API pods.
- Check on the health of Thanos Receive.
  - Check the Thanos Receive [dashboard](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive)
  - Check the logs of the Thanos Receive pods.
- Find and inspect a slow query in [Jaeger](https://observatorium-jaeger.api.openshift.com/search)
- Reach out to @observatorium-oncall or @observatorium-support in #forum-observatorium for help.

## APIMetricsWriteAvailabilityErrorBudgetBurning

### Impact

API is currently failing to ingest metrics data across given time window.

### Summary

API is returning a high-enough level of 5XX responses to write requests that we are depleting our SLO error budget.

### Severity

`critical`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))

### Steps

- Check on the health of the API.
  - Check the API [dashboard](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADX/api)
  - Check the logs on the API pods.
- Check on the health of Thanos Receive.
  - Check the Thanos Receive [dashboard](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive)
  - Check the logs of the Thanos Receive pods.
- Reach out to @observatorium-oncall or @observatorium-support in #forum-observatorium for help.

## APIMetricsWriteLatencyErrorBudgetBurning

### Impact

API is taking longer than expected to ingest metrics data.

### Summary

API is returning a high-enough level of slow responses to write requests that we are depleting our SLO error budget.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))

### Steps

- Check on the health of the API.
  - Check the API [dashboard](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADX/api)
  - Check the logs on the API pods.
- Check on the health of Thanos Receive.
  - Check the Thanos Receive [dashboard](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive)
  - Check the logs of the Thanos Receive pods.
- Reach out to @observatorium-oncall or @observatorium-support in #forum-observatorium for help.

## APIMetricsReadAvailabilityErrorBudgetBurning

### Impact

API is currently failing to respond to metrics read requests in given time window.

### Summary

API is returning a high-enough level of 5XX responses that we are depleting our SLO error budget.

### Severity

`critical`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))

### Steps

- Check on the health of the API.
  - Check the API [dashboard](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADX/api)
  - Check the logs on the API pods.
- Check on the health of Thanos Query Frontend.
  - Check the Thanos Query Frontend [dashboard](https://grafana.app-sre.devshift.net/d/303c4e660a475c4c8cf6aee97da3a24a/thanos-query-frontend)
  - Check the logs of the Thanos Query Frontend pods.
- Check on the health of Thanos Query.
  - Check the Thanos Query [dashboard](https://grafana.app-sre.devshift.net/d/af36c91291a603f1d9fbdabdd127ac4a/thanos-query)
  - Check the logs of the Thanos Query pods.
- Check on the health of Thanos Store.
  - Check the Thanos Store [dashboard](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store)
  - Check the logs of the Thanos Store pods.
- Reach out to @observatorium-oncall or @observatorium-support in #forum-observatorium for help.

## APIMetricsReadLatencyErrorBudgetBurning

### Impact

API is taking longer than expected to respond to metrics read requests.

### Summary

API is returning a high-enough level of slow responses to read requests that we are depleting our SLO error budget.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))

### Steps

- Check on the health of the API.
  - Check the API [dashboard](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADX/api)
  - Check the logs on the API pods.
- Check on the health of Thanos Query Frontend.
  - Check the Thanos Query Frontend [dashboard](https://grafana.app-sre.devshift.net/d/303c4e660a475c4c8cf6aee97da3a24a/thanos-query-frontend)
  - Check the logs of the Thanos Query Frontend pods.
- Check on the health of Thanos Query.
  - Check the Thanos Query [dashboard](https://grafana.app-sre.devshift.net/d/af36c91291a603f1d9fbdabdd127ac4a/thanos-query)
  - Check the logs of the Thanos Query pods.
- Check on the health of Thanos Store.
  - Check the Thanos Store [dashboard](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store)
  - Check the logs of the Thanos Store pods.
- Find and inspect a slow query in [Jaeger](https://observatorium-jaeger.api.openshift.com/search)
- Reach out to @observatorium-oncall or @observatorium-support in #forum-observatorium for help.

## APIRulesRawWriteAvailabilityErrorBudgetBurning

### Impact

API /rules/raw is currently failing to ingest rules in given time window.

### Summary

API /rules/raw is returning a high-enough level of 5XX responses to write requests that we are depleting our SLO error budget.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))

### Steps

- Check on the health of the API.
  - Check the API [dashboard](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADX/api)
  - Check the logs on the API pods.
- Reach out to @observatorium-oncall or @observatorium-support in #forum-observatorium for help.

## APIRulesSyncAvailabilityErrorBudgetBurning

### Impact

API is currently failing to sync rules that were ingested via /rules/raw endpoint to Thanos Rule in given time window.

### Summary

API is returning a high-enough level of 5XX responses of the /reload endpoint that we are depleting our SLO error budget.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))

### Steps

- Check health of Thanos Rule and Thanos Rule Syncer sidecar container.
  - Check the Thanos Rule [dashboard](https://grafana.app-sre.devshift.net/d/35da848f5f92b2dc612e0c3a0577b8a1/thanos-rule)
  - Check the logs on the Thanos Rule pods.
- Reach out to @observatorium-oncall or @observatorium-support in #forum-observatorium for help.

## APIRulesReadAvailabilityErrorBudgetBurning

### Impact

API is currently failing to respond to rules read requests in given time window.

### Summary

API is returning a high-enough level of 5XX responses that we are depleting our SLO error budget.

### Severity

`critical`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))

### Steps

- Check on the health of the API.
  - Check the API [dashboard](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADX/api)
  - Check the logs on the API pods.
- Check on the health of Thanos Rule.
  - Check the Thanos Rule [dashboard](https://grafana.app-sre.devshift.net/d/35da848f5f92b2dc612e0c3a0577b8a1/thanos-rule)
  - Check the logs of the Thanos Rule pods.
- Check on the health of Thanos Query Frontend.
  - Check the Thanos Query Frontend [dashboard](https://grafana.app-sre.devshift.net/d/303c4e660a475c4c8cf6aee97da3a24a/thanos-query-frontend)
  - Check the logs of the Thanos Query Frontend pods.
- Check on the health of Thanos Query.
  - Check the Thanos Query [dashboard](https://grafana.app-sre.devshift.net/d/af36c91291a603f1d9fbdabdd127ac4a/thanos-query)
  - Check the logs of the Thanos Query pods.
- Reach out to @observatorium-oncall or @observatorium-support in #forum-observatorium for help.

## APIRulesRawReadAvailabilityErrorBudgetBurning

### Impact

API is currently failing to respond to rules read requests to the /rules/raw endpoint in given time window.

### Summary

API is returning a high-enough level of 5XX responses that we are depleting our SLO error budget.

### Severity

`critical`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))

### Steps

- Check on the health of the API.
  - Check the API [dashboard](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADX/api)
  - Check the logs on the API pods.
- Reach out to @observatorium-oncall or @observatorium-support in #forum-observatorium for help.

## APIAlertmanagerAvailabilityErrorBudgetBurning

### Impact

Alerts triggered by Thanos Rule are not being sent to Observatorium Alertmanager in given time window.

### Summary

Thanos Rule is returning a high-enough level of dropped alerts that are depleting our SLO error budget.

### Severity

`critical`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))

### Steps

- Check on the health of Thanos Rule.
  - Check the Thanos Rule [dashboard](https://grafana.app-sre.devshift.net/d/35da848f5f92b2dc612e0c3a0577b8a1/thanos-rule) especially the `Alert Sent` and `Alert Queue` panels.
  - Check the logs on the Thanos Rule pods.
- Check on the health of Observatorium Alertmanager.
  - Check the Observatorium Alertmanager configuration and status:
    - [MST](https://observatorium-alertmanager-mst.api.openshift.com/#/status)
    - [Telemeter](https://observatorium-alertmanager.api.openshift.com/#/status)
- Reach out to @observatorium-oncall or @observatorium-support in #forum-observatorium for help.

## APIAlertmanagerNotificationsAvailabilityErrorBudgetBurning

### Impact

Notifications to specified receivers are failing to be sent by Observatorium Alertmanager in given time window.

### Summary

Observatorium Alertmanager is returning a high-enough level of failed notifications that are depleting our SLO error budget.

### Severity

`critical`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))

### Steps

- Check on the health of Observatorium Alertmanager.
  - Check the logs on the Observatorium Alertmanager pods.
- Check on the health of Observatorium Alertmanager.
  - Check the Observatorium Alertmanager configuration and status:
    - [MST](https://observatorium-alertmanager-mst.api.openshift.com/#/status)
    - [Telemeter](https://observatorium-alertmanager.api.openshift.com/#/status)
- Reach out to @observatorium-oncall or @observatorium-support in #forum-observatorium for help.

# Observatorium HTTP Traffic Alerts

## ObservatoriumHttpTrafficErrorRateHigh

### Impact

RHOBS API endpoints are either inaccessible to users or fail to serve the traffic as expected.

### Summary

Users of RHOBS are not able to access API endpoints for either reading, writing metrics and logs. The ha-proxy router at OpenShift Dedicated cluster where the RHOBS is deployed is not returning OK responses.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects))
- Access to Vault secret for `tenants.yaml` (link for [staging](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre-stage/telemeter-stage/observatorium-observatorium-api); for [production](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre/telemeter-production/observatorium-observatorium-api) you will most likely need to contact [App-SRE](https://coreos.slack.com/archives/CCRND57FW))

### Steps

- Check for any outage at Red Hat SSO.
- Check the Vault secret for `tenants.yaml` (link for [staging](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre-stage/telemeter-stage/observatorium-observatorium-api); for [production](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre/telemeter-production/observatorium-observatorium-api) for valid Yaml content, valid tenant name, auth information under 'oidc', 'opa' sections and rate limiting information under 'rateLimits' section.
- Check the logs of Observatorium API deployment's for telemeter tenant [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/observatorium-production/deployments/observatorium-observatorium-api)
- Check the logs of Observatorium UP deployment's for telemeter tenant [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/observatorium-production/deployments/observatorium-observatorium-up)
- Check the logs of Observatorium API deployment's for MST tenant [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/observatorium-mst-production/deployments/observatorium-observatorium-mst-api)
- Check the logs of Observatorium UP deployment's for MST tenant [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/observatorium-mst-production/deployments/observatorium-observatorium-up)

# Observatorium Proactive Monitoring Alerts

## ObservatoriumProActiveMetricsQueryErrorRateHigh

### Impact

Any of of the downstream Observatorium services can cause queries to fail.

### Summary

Metrics queries generated by Proactive monitoring are failing.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-mst-production))
- Access to Vault secret for `tenants.yaml` (link for [staging](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre-stage/telemeter-stage/observatorium-observatorium-api); for [production](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre/telemeter-production/observatorium-observatorium-api) you will most likely need to contact [App-SRE](https://coreos.slack.com/archives/CCRND57FW))

### Steps

- Check the Vault secret for `tenants.yaml` (link for [staging](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre-stage/telemeter-stage/observatorium-observatorium-api); for [production](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre/telemeter-production/observatorium-observatorium-api) for valid Yaml content, valid tenant name, auth information under 'oidc' and 'opa' sections and rate limiting information under 'rateLimits' section.
- Check the logs of Observatorium UP deployment's for telemeter tenant [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/observatorium-production/deployments/observatorium-observatorium-up)
- Check the logs of Observatorium API deployment's for telemeter tenant [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/observatorium-production/deployments/observatorium-observatorium-api)
- Check the logs of Observatorium UP deployment's for MST tenant [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/observatorium-mst-production/deployments/observatorium-observatorium-up)
- Check the logs of Observatorium API deployment's for MST tenant [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/observatorium-mst-production/deployments/observatorium-observatorium-mst-api)

# Observatorium Tenants Alerts

## ObservatoriumTenantsFailedOIDCRegistrations

### Impact

A tenant using OIDC provider for authentication failed to instantiate. Such tenant cannot write / read metrics or logs.

### Summary

There is either outage on the side of the OIDC provider or the tenant authorization is misconfigured.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-mst-production))
- Access to Vault secret for `tenants.yaml` (link for [staging](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre-stage/telemeter-stage/observatorium-observatorium-api); for [production](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre/telemeter-production/observatorium-observatorium-api) you will most likely need to contact [App-SRE](https://coreos.slack.com/archives/CCRND57FW))

### Steps

- Check the logs of Observatorium API deployment's [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-observatorium-api) to see the exact cause of failed OIDC registration.
- Check whether the particular OIDC provider is up and available and / or check external channels for any information about outages (e.g. emails about ongoing incident, provider's status page).
- If entries in `tenants.yaml` have been edited recently, ensure the tenants' configuration is valid. If not, correct the misconfigured entries and ask App-SRE to re-deploy the Observatorium API pods.

## ObservatoriumTenantsSkippedDuringConfiguration

### Impact

A tenant was skipped at the API start up beacuse it holds an invalid configuration. A tenant is therefore not able to communicate with the API.

### Summary

A tenant's configuration in `tenants.yaml` file is not valid.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-mst-production))
- Access to Vault secret for `tenants.yaml` (link for [staging](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre-stage/telemeter-stage/observatorium-observatorium-api); for [production](https://vault.devshift.net/ui/vault/secrets/app-interface/show/app-sre/telemeter-production/observatorium-observatorium-api) you will most likely need to contact [App-SRE](https://coreos.slack.com/archives/CCRND57FW))

### Steps

- Check the logs of Observatorium API deployment's [pods](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-observatorium-api) to see the exact cause of failed tenant registration.
- Check `tenants.yaml` in the Vault secret (see above for access) and ensure the tenants' configuration is valid. If not, correct the misconfigured entries and ask App-SRE to re-deploy the Observatorium API pods.

# Observatorium Custom Metrics Alerts

## ObservatoriumNoStoreBlocksLoaded

### Impact

Thanos Store blocks are not being loaded. This can indicate possible data loss.

### Summary

During the last 6 hours, not even a single Thanos Store block has been loaded.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Check the namespace of RHOBS causing this alert to fire.
- Check logs, configuration for Thanos compact, store and receive components for possible cause(s).
- Check Thanos compact Statefulset
  - Check dashboard of Thanos compact
  - Check the logs of Thanos compact pods for any errors.
  - Check for valid configuration as per <https://thanos.io/tip/components/compact.md/>
    - Object Store configuration (--objstore.config)
    - Downsampling configuration (--retention.resolution-\*)
      - Currently Thanos compact works as expected if the retention.resolution-raw, retention.resolution-5m and retention.resolution-1h are set for the same duration.
  - Also check guidelines for these downsampling Thanos compact command line args at: <https://thanos.io/tip/components/compact.md/> - --retention.resolution-5m needs more than 40 hours - --retention.resolution-1h needs to be more than 10 days
- Check Thanos store statefulset
  - Check the logs of Thanos store pods for any errors related to blocks loading from Object store.
  - Check for valid Object store configuration (--objstore.config) as per <https://thanos.io/tip/components/store.md/>
- Check Thanos receive Statefulset
  - Check the logs of Thanos receive pods for any errors related to blocks uploaded to Object store.
  - Check for valid Object store configuration (--objstore.config) as per <https://thanos.io/tip/components/receive.md/>

## ObservatoriumNoRulesLoaded

### Impact

Thanos Rulers have not loaded any rules. This can indicate possible data loss.

### Summary

The Thanos Ruler pods do not have any rules configured on them, which should not happen and could indicate possible data loss.

### Severity

`critical`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Check the namespace of RHOBS causing this alert to fire.
- Check logs, configuration for Thanos Ruler and rules-objstore components for possible cause(s).
- Check Thanos Rulers Statefulset
  - Check dashboard of Thanos Ruler
  - Check the logs of Thanos Ruler pods for any errors.
  - Check for valid configuration as per <https://thanos.io/tip/components/rule.md/>
- Check for presence of rule files in ConfigMaps.

## ObservatoriumPersistentVolumeUsageHigh

### Impact

A PVC belonging to an RHOBS service is filled beyond a comfortable level. If the volume is not increased, it might soon become critically filled.

### Summary

One or more PVCs are filled to more than 90%. The remaining free space might not suffice to handle the system's load for longer time.

### Severity

`warning`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Check the alert and establish which component is the one affected by the filled PVC
- Assess how much free space on the PVC is there left and how long will it last
- If extending the PVC is necessary, locate the affected deployment in the [AppSRE Interface](https://gitlab.cee.redhat.com/service/app-interface/-/tree/master/data/services/rhobs), depending on which namespace the alert is coming from
- Increase the size of the PVC by adjusting the relevant parameter in one of the `saas.yaml` files

## ObservatoriumPersistentVolumeUsageCritical

### Impact

A PVC belonging to an RHOBS service is critically filled - if the PVC fills beyoned this level, the functionality of the system will be impacted.

### Summary

One or more PVCs are filled to more than 95%. The remaining free space does not suffice to sustain the normal system load.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Check the alert and establish which component is the one affected by the filled PVC
- Check the pods belonging to the component and establish what object do they belong to
- Locate the affected deployment in the [AppSRE Interface](https://gitlab.cee.redhat.com/service/app-interface/-/tree/master/data/services/rhobs), depending on which namespace the alert is coming from
- Increase the size of the PVC by adjusting the relevant parameter in one of the `saas.yaml` files

## ObservatoriumExpectedReplicasUnavailable

### Impact

A StatefulSet belonging to the RHOBS service is not running the expected number of replicas for a prolonged period of time.
This may impact the metric query or ingest performance of the system.

### Summary

A StatefulSet has an undesired amount of replicas. This may be caused by a number of reasons, including:

1. Pod stuck in a terminating state.
2. Pod unable to be scheduled due to constraints on the cluster such as node capacity or resource limits.

### Severity

`critical`

### Access Required

- Console access to the cluster that runs Observatorium.
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Check the alert and establish which component is the one affected.
- Determine the reason for the missing replica(s).
- Act on the above information to address the issue.

# Observatorium Gubernator Alerts

## GubernatorIsDown

### Impact

Observatorium is not ingesting or giving access to data that belongs to the tenants with defined rate limits.

### Summary

Observatorium rate-limiting service is not working.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=%7Bjob%3D~%22observatorium-gubernator%22%7D&g0.tab=0).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-gubernator).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

# Observatorium Obsctl Reloader Alerts

## ObsCtlIsDown

### Impact

Tenant's rules are not being pushed to Observatorium, so they might be stale.

### Summary

The `obsctl-reloader` is most likely down, in a crashloop state.

### Severity

`critical`

### Access Required

- Console access to the production clusters (this system is't used in staging) that runs Observatorium (currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-mst-production) and [rhobsp0ue1 OSD](https://console-openshift-console.apps.rhobsp02ue1.y9ya.p1.openshiftapps.com/)).
- Edit access to the Observatorium namespaces:
  - `observatorium-mst-production`

### Steps

- In the OSD console for specific cluster, check the pods belonging to the `obsctl-reloader` deployment and establish what is causing the crashloop.
- Further actions will depend a lot on the root cause found and most likely be something we didn't go through before.

## ObsCtlRulesStoreServerError

### Impact

Tenant's rules are not being pushed to Observatorium, so they might be stale.

### Summary

Obsctl Reloader is not able to push rules to Observatorium. Potential causes could be:

- Failing tenant authentication due to bad credentials or issues with SSO.
- Internal server error in Observatorium API.

### Severity

`critical`

### Access Required

- Console access to the production clusters (this system is't used in staging) that runs Observatorium (currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-mst-production) and [rhobsp0ue1 OSD](https://console-openshift-console.apps.rhobsp02ue1.y9ya.p1.openshiftapps.com/)).
- Edit access to the Observatorium namespaces:
  - `observatorium-mst-production`

### Steps

- If the error is a 403, check the tenant credentials in the Vault path indicated in [App Interface](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/services/rhobs/observatorium-mst/namespaces/telemeter-prod-01/observatorium-mst-production.yml#L68). Verify if they are valid and can authenticate the tenant properly. This can be done using obsctl-reloader locally and details can be found in the [RHOBS Tenant Test & Verification document](https://docs.google.com/document/d/1iDUh-U7d2luwRBDl8ZkRancsMCePt2pu2NFSf63j10Q/edit#heading=h.bupciudrwmna). If credentials are invalid, identify the tenant and notify them in Slack.
- For any other status code, check the logs of the Observatorium API and obsctl-reloader pods in the namespace indicated in the alert. The logs should contain more details about the error.
- Ultimately you can check the tenant's rules by checking the PrometheusRule CRs in the namespace indicated in the alert.

## ObsCtlFetchRulesFailed

### Impact

Unable to fetch tenant's rules from the local cluster to process, so they might be stale.

### Summary

Obsctl Reloader is not able to fetch PrometheusRule CRs from the local cluster.

### Severity

`critical`

### Access Required

- Console access to the production clusters (this system is't used in staging) that runs Observatorium (currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-mst-production) and [rhobsp0ue1 OSD](https://console-openshift-console.apps.rhobsp02ue1.y9ya.p1.openshiftapps.com/)).
- Edit access to the Observatorium namespaces:
  - `observatorium-mst-production`

### Steps

- Check the logs of the Obsctl Reloader pods in the namespace indicated in the alert. The logs should contain the more details about the error.
- Ensure that the Obsctl Reloader deployment has a service account that can do `get, list, watch` on PrometheusRules.

## ObsCtlRulesSetFailure

### Impact

Unable to set tenant's rules in Observatorium, so they might be stale. Didn't even try to talk to the Observatorium API.

### Summary

Obsctl Reloader is not able to set PrometheusRule CRs in Observatorium due to a problem happening **before** sending the request.

### Severity

`warning`

### Access Required

- Console access to the production clusters (this system is't used in staging) that runs Observatorium (currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-mst-production) and [rhobsp0ue1 OSD](https://console-openshift-console.apps.rhobsp02ue1.y9ya.p1.openshiftapps.com/)).
- Edit access to the Observatorium namespaces:
  - `observatorium-mst-production`

### Steps

- For any other status code, check the logs of the Observatorium API and obsctl-reloader pods in the namespace indicated in the alert. The logs should contain more details about the error.
- Ultimately you can check the tenant's rules by checking the PrometheusRule CRs in the namespace indicated in the alert.

# Observatorium Thanos Alerts

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

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/dashboards/f/MQilB9tMk/observatorium) or [Prometheus](https://prometheus.telemeter-prod-01.devshift.net/targets).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## Thanos Compact

## ThanosCompactMultipleRunning

### Impact

Consumers see inconsistent/wrong metrics. Metrics in long term storage may be corrupted.

### Summary

Multiple replicas of Thanos Compact shouldn't be running. This leads data corruption.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/651943d05a8123e32867b4673963f42b/thanos-compact?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1h&g0.expr=sum(up%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D)&g0.tab=0>).
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

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

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

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/651943d05a8123e32867b4673963f42b/thanos-compact?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1h&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(prometheus_tsdb_compactions_failed_total%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(prometheus_tsdb_compactions_total%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0>).
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

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/651943d05a8123e32867b4673963f42b/thanos-compact?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1h&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_objstore_bucket_operation_failures_total%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_objstore_bucket_operations_total%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)%20&g0.tab=0>).
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

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/651943d05a8123e32867b4673963f42b/thanos-compact?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1h&g0.expr=(time()%20-%20max(thanos_objstore_bucket_last_successful_upload_time%7Bjob%3D~%22thanos-compactor.*%22%2Cnamespace%3D%22telemeter-production%22%7D))%0A%20%20%20%20%20%20%20%20%2F%2060%20%2F%2060&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-compact/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## Thanos Query

## ThanosQueryHttpRequestQueryErrorRateHigh

### Impact

Thanos Query is failing to handle a percentage of incoming query HTTP requests. Not all queries are being fulfilled.

### Summary

Thanos Queriers are failing to handle a percentage of incoming HTTP requests.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/98fde97ddeaf2981041745f1f2ba68c2/thanos-querier?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m&refresh=10s) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1y&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_server_handled_total%7Bgrpc_code%3D~%22Unknown%7CResourceExhausted%7CInternal%7CUnavailable%22%2C%20job%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_server_started_total%7Bjob%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-query).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosQueryGrpcServerErrorRate

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

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/98fde97ddeaf2981041745f1f2ba68c2/thanos-querier?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m&refresh=10s) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1y&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_server_handled_total%7Bgrpc_code%3D~%22Unknown%7CResourceExhausted%7CInternal%7CUnavailable%22%2C%20job%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_server_started_total%7Bjob%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-query).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosQueryGrpcClientErrorRate

### Impact

Consumers do not receive all available metrics. Queries are still being fulfilled, not all of them.
`e.g.` Grafana is not showing all available metrics.

### Summary

Thanos Queriers are failing to send or get response from query requests to components which conforms Store API (Store/Sidecar/Receive),
Certain amount of the requests that querier makes to other Store API components are failing, which means that most likely the other component having issues.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/98fde97ddeaf2981041745f1f2ba68c2/thanos-querier?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m&refresh=10s) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1y&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_client_handled_total%7Bgrpc_code!%3D%22OK%22%2C%20job%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_client_started_total%7Bjob%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-query).
- Inspect logs and events of depending jobs, like [store](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-store-shard-0), [receivers](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default) (There maybe more than one receive component and store shard deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive and store components).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosQueryHighDNSFailures

### Impact

Consumers do not receive all available metrics. Queries are still being fulfilled, not all of them.
`e.g.` Grafana is not showing all available metrics.

### Summary

Thanos Queriers are failing to discover components which conforms Store API (Store/Sidecar/Receive) to query.
Queriers use DNS Service discovery to discover related components.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/98fde97ddeaf2981041745f1f2ba68c2/thanos-querier?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m&refresh=10s) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1d&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_querier_store_apis_dns_failures_total%7Bjob%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_querier_store_apis_dns_lookups_total%7Bjob%3D~%22thanos-querier.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-query).
- Inspect logs and events of depending jobs, like [store](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-store-shard-0), [receivers](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default) (There maybe more than one receive component and store shard deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive components).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosQueryInstantLatencyHigh

### Impact

Consumers are waiting too long to get metrics.
`e.g.` Grafana is timing out or too slow to render panels.

### Summary

Thanos Queriers are slower than expected to conduct instant vector queries.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/98fde97ddeaf2981041745f1f2ba68c2/thanos-querier?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m&refresh=10s) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1d&g0.expr=histogram_quantile(0.99%2C%0A%20%20%20%20%20%20%20%20%20%20sum(http_request_duration_seconds_bucket%7Bjob%3D~"thanos-querier.*"%2Cnamespace%3D"telemeter-production"%2C%20handler%3D"query"%7D)%20by%20(job%2C%20le)%0A%20%20%20%20%20%20%20%20)&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-query).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## Thanos Receive

## ThanosReceiveHttpRequestErrorRateHigh

### Impact

Observatorium is failing to ingest metrics as Receive is failing to handle a certain percentage of HTTP requests.
`e.g.` Telemeter client is timing out or too slow to send metrics.

### Summary

Thanos Receives are failing to handle a certain percentage of HTTP remote write requests.
Thanos Receive ingests time series from Prometheus remote write or any other requester.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=10m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1d&g0.expr=histogram_quantile(0.99%2C%0A%20%20%20%20%20%20%20%20%20%20sum(http_request_duration_seconds_bucket%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%2C%20handler%3D%22receive%22%7D)%20by%20(job%2C%20le)%0A%20%20%20%20%20%20%20%20)%20&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default/pods). There maybe more than one receive component deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

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

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=10m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=1d&g0.expr=histogram_quantile(0.99%2C%0A%20%20%20%20%20%20%20%20%20%20sum(http_request_duration_seconds_bucket%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%2C%20handler%3D%22receive%22%7D)%20by%20(job%2C%20le)%0A%20%20%20%20%20%20%20%20)%20&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default/pods). There maybe more than one receive component deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

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

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=10m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_forward_requests_total%7Bresult%3D%22error%22%2C%20job%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_forward_requests_total%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default/pods). (There maybe more than one receive component deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosReceiveHighHashringFileRefreshFailures

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

Thanos Receives are failing to reload the hash-ring configuration files.
They might be using stale version of configuration.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=10m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_hashrings_file_errors_total%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_hashrings_file_refreshes_total%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default/pods). (There maybe more than one receive component deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Inspect logs, events and latest changes of [`thanos-receive-controller`](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-receive-controller)
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosReceiveConfigReloadFailure

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

Thanos Receives failed to reload the latest configuration files.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=10m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=avg(thanos_receive_config_last_reload_successful%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D)%20by%20(job)&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default/pods). (There maybe more than one receive component deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Inspect logs, events and latest changes of [`thanos-receive-controller`](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-receive-controller)
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosReceiveNoUpload

### Impact

### Summary

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Log onto the cluster and run: `oc rollout restart statefulset observatorium-thanos-receive-default`

NOTE: This must be done with a 4.x version of the oc client.

## ThanosReceiveLimitsConfigReloadFailure

### Impact

Observatorium is not rate limiting remote writes correctly.

### Summary

Thanos Receives component failed to reload the latest write limits configuration files. New write limits are not applied. Also, if running instances need to be restarted, they will not be able to start.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium MST in staging [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces)

### Steps

- Inspect one of the Thanos receive pods logs to find the error message when reloading the configuration. It should contain `error reloading tenant limits config`
job events in the OpenShift console or login to the cluster and run `oc get events -n observatorium-metrics-production --sort-by='{.lastTimestamp}'` to find the latest events.
- Using the event description about the failure to load the limits configuration, fix the issue by updating the limits configuration file using the `THANOS_RECEIVE_LIMIT_CONFIG` template parameter configured in `app-interface` repos in the `saas.yml` file.
- If a fix is not possible, revert the change that caused the issue so that the pod is able to restart if needed.

## ThanosReceiveLimitsHighMetaMonitoringQueriesFailureRate

### Impact

Observatorium is not applying head series limits correctly.

### Summary

Thanos Receives component failed to retrieve current head series count for each tenant using the configured meta-monitoring. As the head series count is not updated, the service is unable to apply rate limiting correctly.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium MST in staging [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces)

### Steps

- Inspect one of the Thanos receive pods logs to find the error message when failing to query meta-monitoring. It should contain `failed to query meta-monitoring`.
- If the cause is an invalid url or query configuration, update the limits configuration file using the `THANOS_RECEIVE_LIMIT_CONFIG` template parameter configured in `app-interface` repos in the `saas.yml` file. Update the values of the `meta_monitoring_url` and `meta_monitoring_limit_query` keys.
- If the cause comes from the meta-monitoring service, signal the issue to app-sre team.

## ThanosReceiveTenantLimitedByHeadSeries

### Impact

A tenant has its write requests limited due to high number of head series. Such tenant cannot make write requests containing new metrics.

### Summary

A tenant is writing too many metrics with high cardinality. This is causing high number of head series that is limited through the `head_series_limit` configuration option. Some metrics are not ingested and may be lost.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium MST in staging [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))

### Steps

- Increase the `head_series_limit` value in the limits configuration using the `THANOS_RECEIVE_LIMIT_CONFIG` template parameter configured in `app-interface` repos in the `saas.yml` file. If the tenant has no custom limits, add the tenant to the `tenants` object with an increased limit value.
- Once the change is merged, the new configuration is automatically deployed and reloaded by thanos receive.
- check the `thanos_receive_head_series_limited_requests_total` metric to see if the tenant is still being limited. If so, increase the limit again: `sum(rate(thanos_receive_head_series_limited_requests_total{tenant="<tenant>"}[5m])) by (job)`.
- After the incident is resolved, if the new limit is too big to ensure the stability of the system, contact the client to adapt their remote write configuration to conform to the limits.

## Thanos Store Gateway

## ThanosStoreGrpcErrorRate

### Impact

Consumers are not getting long term storage metrics.

### Summary

Thanos Stores are failing to handle incoming gRPC requests.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_server_handled_total%7Bgrpc_code%3D~%22Unknown%7CResourceExhausted%7CInternal%7CUnavailable%22%2C%20job%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(grpc_server_started_total%7Bjob%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-store-shard-0/pods). There maybe more than one store shard deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive and store components.
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosStoreSeriesGateLatencyHigh

### Impact

Consumers are waiting too long to get long term storage metrics.

### Summary

Thanos Stores are slower than expected to get series from buckets.
A store series gate is a limiter which limits the maximum amount of concurrent queries. Queries are waiting longer at the gate than expected, stores might be under heavy load. This could also cause high memory utilization.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Check saturation of stores, using [dashboards](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m), try scaling up if it's the issue.
- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=histogram_quantile(0.99%2C%0A%20%20%20%20%20%20%20%20%20%20sum(thanos_bucket_store_series_gate_duration_seconds_bucket%7Bjob%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D)%20by%20(job%2C%20le)%0A%20%20%20%20%20%20%20%20)&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-store-shard-0/pods). There maybe more than one store shard deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available store shards.
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosStoreBucketHighOperationFailures

### Impact

Consumers are not getting long term storage metrics.

### Summary

Thanos Stores are failing to conduct operations against buckets.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_objstore_bucket_operation_failures_total%7Bjob%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_objstore_bucket_operations_total%7Bjob%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)%20by%20(job)&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-store-shard-0/pods). There maybe more than one store shard deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available store shards.
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosStoreObjstoreOperationLatencyHigh

### Impact

Consumers are not getting long term storage metrics.

### Summary

Thanos Stores are slower than expected to conduct operations against buckets.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=histogram_quantile(0.99%2C%0A%20%20%20%20%20%20%20%20%20%20sum(thanos_objstore_bucket_operation_duration_seconds_bucket%7Bjob%3D~%22thanos-store.*%22%2Cnamespace%3D%22telemeter-production%22%7D)%20by%20(job%2C%20le)%0A%20%20%20%20%20%20%20%20)%20&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-store-shard-0/pods). There maybe more than one store shard deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available store shards.
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## Thanos Rule

## ThanosRuleHighRuleEvaluationFailures

## ThanosNoRuleEvaluations

## ThanosRuleRuleEvaluationLatencyHigh

### Impact

If the evaluation failures are too high are or the evaluation latency is too high, a _symptom_ is, that we may end up **losing data** or are **unable to alert**.

### Summary

Both Thanos Rule replicas fail to evaluate or too slow to evaluate certain recording rules or alerts.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

Thanos Rulers are querying Thanos Queriers like any other user of Thanos, in turn the Thanos Querier reaches out to the Thanos Store and Thanos Receivers.

- Check the [Thanos Rule dashboard](https://grafana.app-sre.devshift.net/d/35da848f5f92b2dc612e0c3a0577b8a1/thanos-rule?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) to get a general overview.
- Check the [Thanos Query dashboard](https://grafana.app-sre.devshift.net/d/af36c91291a603f1d9fbdabdd127ac4a/thanos-query?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m). Most likely you can focus on the Instant Query API RED metrics.
- Drill down into the [Thanos Store dashboard](https://grafana.app-sre.devshift.net/d/e832e8f26403d95fac0ea1c59837588b/thanos-store?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) and [Thanos Receiver dashboard](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m). Depending on which one of them has the same elevated error rate, concentrate on that component.
  - Probably, the Thanos Receiver is the problem, as the Thanos Ruler mostly looks at very recent data (like last 5min).
- Now that you, hopefully, know which component is causing the errors, dive into its logs, query it's raw metrics (check the dashboards as examples).
  - Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosRuleTSDBNotIngestingSamples

### Impact

Non-revertable gap in recording rules' data (dropped sample) or not evaluates alerts (missed alert).

### Summary

Both Thanos Rule replicas internal TSDB failed to ingest samples.

### Severity

`critical`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Recently we are hitting some issues where both replicas are stuck. We are investigating, but both replica pod restart mitigates the problem for some time (days). See: <https://issues.redhat.com/browse/OBS-210>
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatbility-thanos-rule/pods).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## Thanos Receive Controller

## ThanosReceiveControllerReconcileErrorRate

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

Thanos Receive Controller is failing to reconcile changes.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Make sure provided [configuration](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/configmaps/observatorium-thanos-receive-controller-tenants) is correct (There might be others, check all [configmaps](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/configmaps)).
- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/858503cdeb29690fd8946e038f01ba85/thanos-receive-controller?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=sum(rate(thanos_receive_controller_reconcile_errors_total%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%2F%0A%20%20%20%20%20%20%20%20%20%20on%20(namespace)%20group_left%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_controller_reconcile_attempts_total%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D))%0A%20%20%20%20%20%20%20%20%20&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-receive-controller).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosReceiveControllerConfigmapChangeErrorRate

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

Thanos Receive Controller is failing to change configmaps.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Make sure concerning `kube-apiserver` is accessible.
- Make sure provided [configuration](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/configmaps/observatorium-thanos-receive-controller-tenants) is correct (There might be others, check all [configmaps](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/configmaps)).
- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/858503cdeb29690fd8946e038f01ba85/thanos-receive-controller?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=sum(%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_controller_configmap_change_errors_total%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20%20%20on%20(namespace)%20group_left%0A%20%20%20%20%20%20%20%20%20%20rate(thanos_receive_controller_configmap_change_attempts_total%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D)%0A%20%20%20%20%20%20%20%20)&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-receive-controller).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosReceiveConfigStale

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

The configuration of the instances of Thanos Receive are old compare to Receive Controller configuration.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Make sure provided [configuration](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/configmaps/observatorium-thanos-receive-controller-tenants) is correct (There might be others, check all [configmaps](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/configmaps)).
- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/858503cdeb29690fd8946e038f01ba85/thanos-receive-controller?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=avg(thanos_receive_config_last_reload_success_timestamp_seconds%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D)%20by%20(namespace%2C%20job)%0A%20%20%20%20%20%20%20%20%20%20%3C%0A%20%20%20%20%20%20%20%20on(namespace)%0A%20%20%20%20%20%20%20%20thanos_receive_controller_configmap_last_reload_success_timestamp_seconds%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-receive-controller).
- Inspect logs and events of `receive` jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default/pods). (There maybe more than one receive component deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

## ThanosReceiveConfigInconsistent

### Impact

Observatorium is not ingesting metrics correctly.

### Summary

The configuration of the instances of Thanos Receive are not same with Receive Controller configuration.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/project-details/all-namespaces) and [app-sre-stage-0 OSD](https://console-openshift-console.apps.app-sre-stage-0.k3s7.p1.openshiftapps.com/project-details/all-namespaces))
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Make sure provided [configuration](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/configmaps/observatorium-thanos-receive-controller-tenants) is correct (There might be others, check all [configmaps](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/configmaps)).
- Inspect metrics of failing job using [dashboards](https://grafana.app-sre.devshift.net/d/858503cdeb29690fd8946e038f01ba85/thanos-receive-controller?orgId=1&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m) or [Prometheus](<https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=15m&g0.expr=avg(thanos_receive_config_hash%7Bjob%3D~%22thanos-receive.*%22%2Cnamespace%3D%22telemeter-production%22%7D)%20BY%20(namespace%2C%20job)%0A%20%20%20%20%20%20%20%20%20%20%2F%0A%20%20%20%20%20%20%20%20on%20(namespace)%0A%20%20%20%20%20%20%20%20group_left%0A%20%20%20%20%20%20%20%20thanos_receive_controller_configmap_hash%7Bjob%3D~%22thanos-receive-controller.*%22%2Cnamespace%3D%22telemeter-production%22%7D&g0.tab=0>).
- Inspect logs and events of failing jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/deployments/observatorium-thanos-receive-controller).
- Inspect logs and events of `receive` jobs, using [OpenShift console](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets/observatorium-thanos-receive-default/pods). (There maybe more than one receive component deployed, check all other [statefulsets](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/ns/telemeter-production/statefulsets) to find available receive components)).
- Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack, to get help in the investigation.

---

# Observatorium Alertmanager Alerts

## AlertmanagerFailedReload

### Impact

For users this means that their most recent update to alerts might not be currently in use. Ultimately, this means some of the alerts they have configured may not be firing as expected. Subsequent updates to Alertmanager configuration won't be picked up until the reload succeeds.

### Summary

For some reason, the Alertmanager failed to reload its configuration from disk. This means that any changes to alerts, inhibit rules, receivers etc will not be picked up until this is resolved.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- Check the Alertmanager configuration being mounted into the Observatorium Alertmanager pods through the OSD console.
- Check the definition of the Observatorium Alertmanager configuration in app-interface: https://gitlab.cee.redhat.com/service/app-interface/-/tree/master/resources/rhobs/production.

## AlertmanagerMembersInconsistent

### Impact

For users this means that some alerts routed to this Alertmanager might either not fire or stay stuck firing.

### Summary

A member of an Alertmanager cluster has not found all other cluster members.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium

### Steps

- In the OSD console for the affected cluster, find the Alertmanager Route. Check that it correctly points to the Alertmanager Service. Check that the Service correctly points to the **all** the Alertmanager pods. Find and open the Alertmanager's Route's URL to get to its UI, go to the "Status" tab, and note the IP addresses of the discovered Alertmanager instances. Check if they match the addresses of **all** the Alertmanager pods, none should be missing or mismatching.

## AlertmanagerFailedToSendAlerts

### Impact

For users, no impact since another instance of Alertmanager in the cluster should be able to send the notification, unless `AlertmanagerClusterFailedToSendAlerts` is also triggered.

### Summary

One of the Alertmanager instances in the cluster cannot send alerts to receivers.

### Severity

`medium`

### Access Required

- Console access to the cluster that runs Observatorium

### Steps

- Check the logs of the affected Alertmanager pod in the OSD console for related errors (authn/z, networking, firewall, rate limits, etc).

## AlertmanagerClusterFailedToSendAlerts

### Impact

For users, the alert notifications won't be delivered to their configured receivers.

### Summary

All instances in the Alertmanaget cluster failed to send notification to an specific receiver.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium

### Steps

- Check the logs of the affected Alertmanager pod in the OSD console for related errors (authn/z, networking, firewall, rate limits, etc).

## AlertmanagerConfigInconsistent

### Impact

Hard to predict without knowing what is different between configuration of the different instances. Nevertheless, in most cases alerts might be lost or routed to the incorrect receiver.

### Summary

The configuration of the Alertmanager instances inside the cluster have drifted.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium

### Steps

- In the OSD console of the affected cluster, find the Alertmanager pods. Check what is different in their Alertmanager configuration file -- it's mounted from a secret. Delete the pods and let them be recreated, this should ensure they load the same configuration.

## AlertmanagerClusterDown

### Impact

With less than 50% of the cluster nodes being healthy, the gossip protocol used by Alertmanager to synchronize state across the cluster won't work properly. This means:

* Some alerts may be missed or duplicated as different instances don't have a consistent view of state.
* Some alerts may get stuck in the "pending" state and never resolve if the instance handling them goes down.
* Silences and inhibitions may not propagate across the cluster, causing unexpected alerts to fire.

### Summary

More than 50% of the Alertmanager replicas in the cluster are down.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium

### Steps

* Open the OSD console for the affected cluster and try to diagnose why the Alertmanager pods aren't healthy and joining the cluster. Check the pods' logs and events for clues.

## AlertmanagerClusterCrashlooping

### Impact

For tenants, alerts could be notified multiple time unless pods are crashing too fast and no alerts can be sent.

### Summary

Alertmanager pods are crashlooping.

### Severity

`high`

### Access Required

- Console access to the cluster that runs Observatorium
- Edit access to the Observatorium namespaces:
  - `observatorium-metrics-stage`
  - `observatorium-metrics-production`
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

### Steps

- In the OSD console of the affected cluster, check the logs of the crashlooping Alertmanager pods for clues about the root cause. Common issues are: not enough memory allocated to the pod, configuration errors, lack of permissions, bugs in the Alertmanager code or Docker image.

# Observatorium Loki Alerts

## LokiRequestErrors

### Impact

For users this means that the service as being unavailable due to returning too many errors.

### Summary

For the set availability guarantees the Loki distributor/query-frontend/querier are returning too many http errors when processing requests.

### Severity

`info`

### Access Required

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-mst-production))
- Edit access to the Observatorium Logs namespaces:
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

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

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-mst-production))
- Edit access to the Observatorium Logs namespaces:
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

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

- Console access to the cluster that runs Observatorium (Currently [telemeter-prod-01 OSD](https://console-openshift-console.apps.telemeter-prod.a5j2.p1.openshiftapps.com/k8s/cluster/projects/observatorium-mst-production))
- Edit access to the Observatorium Logs namespaces:
  - `observatorium-mst-stage`
  - `observatorium-mst-production`

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

---

# Escalations

Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-observatorium`](https://slack.com/app_redirect?channel=forum-observatorium) at CoreOS Slack.
