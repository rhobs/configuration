local loki = (import 'github.com/grafana/loki/production/loki-mixin/mixin.libsonnet');
local slo = import 'github.com/metalmatze/slo-libsonnet/slo-libsonnet/slo.libsonnet';
local lokiTenants = import './observatorium-logs/loki-tenant-alerts.libsonnet';
local utils = import './utils.jsonnet';

local config = (import 'config.libsonnet') {
  thanos+: {
    query+:: {
      p99QueryLatencyThreshold: 90,
    },
    store+:: {
      // NOTICE: Check tail latency for tuning the threshold.
      // https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=6h&g0.expr=histogram_quantile(0.99%2C%20sum%20by%20(job%2C%20le)%20(rate(thanos_objstore_bucket_operation_duration_seconds_bucket%7Bjob%3D~%22observatorium-thanos-store.*%22%7D%5B5m%5D)))&g0.tab=0
      bucketOpsP99LatencyThreshold: 7,
    },
  },
};

local absent(name, job) = {
  prometheusAlerts+:: {
    groups+: [
      {
        name: '%s-absent' % name,
        rules: [
          {
            alert: '%sIsDown' % name,
            expr: |||
              absent(up{job="%s"} == 1)
            ||| % job,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: '%s has disappeared from Prometheus target discovery.' % name,
            },
          },
        ],
      },
    ],
  },
};

// Add dashboards and runbook anntotations.
// Overwrite severity to medium and high.
local appSREOverwrites(environment) = {
  local dashboardDatasource = function(environment) {
    datasource:
      if
        environment == 'stage' then 'app-sre-stage-01-prometheus'
      else if
        environment == 'production' then 'telemeter-prod-01-prometheus'
      else error 'no datasource for environment %s' % environment,
  },

  local dashboardID = function(name, environment) {
    id:
      if
        name == 'thanos-query' then '98fde97ddeaf2981041745f1f2ba68c2'
      else if
        name == 'thanos-compact' then '651943d05a8123e32867b4673963f42b'
      else if
        name == 'thanos-receive' then '916a852b00ccc5ed81056644718fa4fb'
      else if
        name == 'thanos-store' then 'e832e8f26403d95fac0ea1c59837588b'
      else if
        name == 'thanos-rule' then '35da848f5f92b2dc612e0c3a0577b8a1'
      else if
        name == 'thanos-receive-controller' then 'no-dashboard'
      else if
        name == 'thanos-component-absent' then 'no-dashboard'
      else if
        name == 'observatorium-metrics' then 'no-dashboard'
      else if
        name == 'observatorium-tenants' then 'no-dashboard'
      else if
        name == 'observatorium-http-traffic' then 'no-dashboard'
      else if
        name == 'observatorium-proactive-monitoring' then 'no-dashboard'
      else if
        std.startsWith(name, 'observatorium-api') then 'Tg-mH0rizaSJDKSADX'
      else if
        std.startsWith(name, 'telemeter') then 'Tg-mH0rizaSJDKSADJ'
      else if
        std.startsWith(name, 'loki_tenant') then 'f6fe30815b172c9da7e813c15ddfe607'
      else if
        std.startsWith(name, 'loki') then 'Lg-mH0rizaSJDKSADX'
      else if
        std.startsWith(name, 'rhobs-telemeter') && environment == 'production' then 'f9fa7677fb4a2669f123f9a0f2234b47'
      else if
        std.startsWith(name, 'rhobs-telemeter') && environment == 'stage' then '080e53f245a15445bdf777ae0e66945d'
      else if
        std.startsWith(name, 'rhobs-mst') && environment == 'production' then '283e7002d85c08126681241df2fdb22b'
      else if
        std.startsWith(name, 'rhobs-mst') && environment == 'stage' then '92520ea4d6976f30d1618164e186ef9b'
      else if
        std.startsWith(name, 'gubernator') then 'no-dashboard'
      else error 'no dashboard id for group %s' % name,
  },

  local setSeverity = function(label, environment, alertName) {
    label:
      if
        std.startsWith(alertName, 'Loki') then 'info'
      else if
        label == 'critical' then
        if
          environment == 'stage' then 'high'
        else if
          // For thanos, page only for `ThanosNoRuleEvaluations`.
          std.startsWith(alertName, 'Thanos') && alertName != 'ThanosNoRuleEvaluations' then 'high'
        else label
      else if
        label == 'warning' then 'medium'
      else 'high',
  },

  local setServiceLabel = function(alertName) {
    label:
      if std.length(std.findSubstr('Logs', alertName)) > 0 || std.length(std.findSubstr('Loki', alertName)) > 0
      then 'observatorium-logs'
      else 'telemeter',
  },

  local pruneUnsupportedLabels = function(labels) {
    // Prune selector label because not allowed by AppSRE
    labels: std.prune(labels {
      group: null,
      container: null,
      client: null,
    }),
  },

  groups: [
    g {
      rules: [
        if std.objectHas(r, 'alert') then
          r {
            annotations+:
              {
                // Message is a required field. Upstream thanos-mixin doesn't have it.
                message: if std.objectHasAll(self, 'description') then self.description else r.annotations.message,
              } +
              if std.length(std.findSubstr('Logs', r.alert)) > 0 then
                {
                  runbook: 'https://github.com/rhobs/configuration/blob/main/docs/sop/observatorium.md#%s' % std.asciiLower(r.alert),
                  dashboard: 'https://grafana.app-sre.devshift.net/d/%s/api-logs?orgId=1&refresh=1m&var-datasource=%s&var-namespace={{$labels.namespace}}' % [
                    dashboardID('loki', environment).id,
                    dashboardDatasource(environment).datasource,
                  ],
                }
              else if std.startsWith(g.name, 'telemeter') then
                {
                  runbook: 'https://github.com/rhobs/configuration/blob/main/docs/sop/telemeter.md#%s' % std.asciiLower(r.alert),
                  dashboard: 'https://grafana.app-sre.devshift.net/d/%s/telemeter?orgId=1&refresh=1m&var-datasource=%s' % [
                    dashboardID(g.name, environment).id,
                    dashboardDatasource(environment).datasource,
                  ],
                }
              else if std.startsWith(g.name, 'loki_tenant') then
                {
                  runbook: 'https://github.com/rhobs/configuration/blob/main/docs/sop/observatorium.md#%s' % std.asciiLower(r.alert),
                  dashboard: 'https://grafana.app-sre.devshift.net/d/%s/%s?orgId=1&refresh=10s&var-metrics=%s&var-namespace={{$labels.namespace}}' % [
                    dashboardID(g.name, environment).id,
                    g.name,
                    dashboardDatasource(environment).datasource,
                  ],
                }
              else
                {
                  runbook: 'https://github.com/rhobs/configuration/blob/main/docs/sop/observatorium.md#%s' % std.asciiLower(r.alert),
                  dashboard: 'https://grafana.app-sre.devshift.net/d/%s/%s?orgId=1&refresh=10s&var-datasource=%s&var-namespace={{$labels.namespace}}&var-job=All&var-pod=All&var-interval=5m' % [
                    dashboardID(g.name, environment).id,
                    g.name,
                    dashboardDatasource(environment).datasource,
                  ],
                },
            labels: pruneUnsupportedLabels(r.labels {
              service: setServiceLabel(r.alert).label,
              severity: setSeverity(r.labels.severity, environment, r.alert).label,
            }).labels,
          } else r {
          labels: pruneUnsupportedLabels(r.labels).labels,
        }
        for r in super.rules
      ],
    }
    for g in super.groups
  ],
} + {
  groups: [
    g {
      rules: std.filter(
        function(r) !(
          std.objectHas(r, 'alert') && (
            // Using multi-burnrate SLO alerts for these.
            r.alert == 'ThanosQueryHttpRequestQueryRangeErrorRateHigh' ||
            r.alert == 'ThanosQueryRangeLatencyHigh' ||
            r.alert == 'ThanosStoreSeriesGateLatencyHigh' ||
            // These components arent' deployed.
            r.alert == 'ThanosSidecarIsDown' ||
            r.alert == 'ThanosBucketReplicateIsDown'
          )
        ),
        super.rules,
      ),
    }
    for g in super.groups
  ],
};

local renderRules(name, mixin) = {
  apiVersion: 'monitoring.coreos.com/v1',
  kind: 'PrometheusRule',
  metadata: {
    name: name,
    labels: {
      prometheus: 'app-sre',
      role: 'recording-rules',
    },
  },
  spec: mixin.prometheusRules,
};

local renderAlerts(name, environment, mixin) = {
  apiVersion: 'monitoring.coreos.com/v1',
  kind: 'PrometheusRule',
  metadata: {
    name: name,
    labels: {
      prometheus: 'app-sre',
      role: 'alert-rules',
    },
  },

  spec: mixin {
    prometheusAlerts+:: appSREOverwrites(environment),
  }.prometheusAlerts,
};

{
  // This function is required to convert the output format of the slo-libsonnet library to the format expected
  // for the prometheus rules file.
  local flatten(originalSLOs) = {
    prometheusAlerts+:: {
      groups: [
        {
          local slos = [
            slo.alerts + slo.recordingrules
            for slo in group.slos
          ],

          name: group.name,
          rules: std.flattenArrays(slos),
        }
        for group in originalSLOs
      ],
    },
  },

  // This set of SLOs are driven by the RHOBS Service Level Objectives document
  // https://docs.google.com/document/d/1wJjcpgg-r8rlnOtRiqWGv0zwr1MB6WwkQED1XDWXVQs/edit

  local telemeterServerSLOs = [
    {
      name: 'rhobs-telemeter-telemeter-server-metrics-write-availability.slo',
      slos: [
        slo.errorburn({
          alertName: 'TelemeterServerMetricsWriteAvailabilityErrorBudgetBurning',
          alertMessage: 'Telemeter Server /upload or /receive is burning too much error budget to guarantee availability SLOs',
          metric: 'haproxy_server_http_responses_total',
          selectors: ['route=~"telemeter-server-upload|telemeter-server-metrics-v1-receive"', 'code=~"^(2..|3..|5..)$"'],
          errorSelectors: ['code="5xx"'],
          target: 0.95,
        }),
      ],
    },
    {
      name: 'rhobs-telemeter-telemeter-server-metrics-write-latency.slo',
      slos: [
        slo.latencyburn({
          alertName: 'TelemeterServerMetricsWriteLatencyErrorBudgetBurning',
          alertMessage: 'Telemeter Server /upload or /receive is burning too much error budget to guarantee latency SLOs',
          metric: 'http_request_duration_seconds',
          // We can't use !~ operator in these selectors
          selectors: ['job="telemeter-server"', 'handler=~"upload|receive"', 'code=~"^(2..|3..|5..)$"'],
          latencyTarget: 5,
          latencyBudget: 0.1,  // The budget is 1 - SLO
        }),
      ],
    },
  ],

  local apiSLOs = function(instance, upNamespace, metricsNamespace, apiJob) {
    local apiJobSelector = 'job="' + apiJob + '"',
    local upNamespaceSelector = 'namespace="' + upNamespace + '"',

    slos: [
      {
        name: 'rhobs-' + instance + '-api-metrics-write-availability.slo',
        slos: [
          slo.errorburn({
            alertName: 'APIMetricsWriteAvailabilityErrorBudgetBurning',
            alertMessage: 'API /receive handler is burning too much error budget to guarantee availability SLOs',
            metric: 'http_requests_total',
            selectors: [apiJobSelector, 'handler=~"receive"', 'code=~"^(2..|3..|5..)$"'],
            errorSelectors: ['code=~"5.+"'],
            target: 0.95,
          }),
        ],
      },
      {
        name: 'rhobs-' + instance + '-api-metrics-write-latency.slo',
        slos: [
          slo.latencyburn({
            alertName: 'APIMetricsWriteLatencyErrorBudgetBurning',
            alertMessage: 'API /receive handler is burning too much error budget to guarantee latency SLOs',
            metric: 'http_request_duration_seconds',
            // We can't use !~ operator in these selectors
            selectors: [apiJobSelector, 'handler="receive"', 'code=~"^(2..|3..|5..)$"'],
            latencyTarget: 5,
            latencyBudget: 0.1,  // The budget is 1 - SLO
          }),
        ],
      },
      {
        name: 'rhobs-' + instance + '-api-metrics-read-availability.slo',
        slos: [
          slo.errorburn({
            alertName: 'APIMetricsReadAvailabilityErrorBudgetBurning',
            alertMessage: 'API /query handler is burning too much error budget to guarantee availability SLOs',
            metric: 'http_requests_total',
            selectors: [apiJobSelector, 'handler="query"', 'code=~"^(2..|3..|5..)$"'],
            errorSelectors: ['code=~"5.+"'],
            target: 0.95,
          }),
          slo.errorburn({
            alertName: 'APIMetricsReadAvailabilityErrorBudgetBurning',
            alertMessage: 'API /query_range handler is burning too much error budget to guarantee availability SLOs',
            metric: 'http_requests_total',
            selectors: [apiJobSelector, 'handler="query_range"', 'code=~"^(2..|3..|5..)$"'],
            errorSelectors: ['code=~"5.+"'],
            target: 0.95,
          }),
        ],
      },
      {
        name: 'rhobs-' + instance + '-api-metrics-read-latency.slo',
        slos: [
          slo.latencyburn({
            alertName: 'APIMetricsReadLatencyErrorBudgetBurning',
            alertMessage: 'API /query endpoint is burning too much error budget to guarantee latency SLOs',
            metric: 'up_custom_query_duration_seconds',
            selectors: ['query="query-path-sli-1M-samples"', upNamespaceSelector],
            latencyTarget: 10,
            latencyBudget: 0.1,  // The budget is 1 - SLO
          }),
          slo.latencyburn({
            alertName: 'APIMetricsReadLatencyErrorBudgetBurning',
            alertMessage: 'API /query endpoint is burning too much error budget to guarantee latency SLOs',
            metric: 'up_custom_query_duration_seconds',
            selectors: ['query="query-path-sli-10M-samples"', upNamespaceSelector],
            latencyTarget: 30,
            latencyBudget: 0.1,  // The budget is 1 - SLO
          }),
          slo.latencyburn({
            alertName: 'APIMetricsReadLatencyErrorBudgetBurning',
            alertMessage: 'API /query endpoint is burning too much error budget to guarantee latency SLOs',
            metric: 'up_custom_query_duration_seconds',
            // We can't use !~ operator in these selectors
            selectors: ['query="query-path-sli-100M-samples"', upNamespaceSelector],
            latencyTarget: 120,
            latencyBudget: 0.1,  // The budget is 1 - SLO
          }),
        ],
      },
      {
        name: 'rhobs-' + instance + '-api-rules-raw-write-availability.slo',
        slos: [
          slo.errorburn({
            alertName: 'APIRulesRawWriteAvailabilityErrorBudgetBurning',
            alertMessage: 'API /rules/raw endpoint is burning too much error budget to guarantee availability SLOs',
            metric: 'http_requests_total',
            selectors: [apiJobSelector, 'group="metricsv1"', 'handler="rules-raw"', 'code=~"^(2..|3..|5..)$"', 'method=~"PUT"'],
            errorSelectors: ['code=~"5.+"'],
            target: 0.95,
          }),
        ],
      },
      {
        name: 'rhobs-' + instance + '-api-rules-sync-availability.slo',
        slos: [
          slo.errorburn({
            alertName: 'APIRulesSyncAvailabilityErrorBudgetBurning',
            alertMessage: 'API /reload endpoint is burning too much error budget to guarantee availability SLOs',
            metric: 'client_api_requests_total',
            selectors: ['client="reload"', 'container="thanos-rule-syncer"', 'namespace="' + utils.instanceNamespace(instance, metricsNamespace, upNamespace) + '"', 'code=~"^(2..|3..|5..)$"'],
            errorSelectors: ['code=~"5.+"'],
            target: 0.95,
          }),
        ],
      },
      {
        name: 'rhobs-' + instance + '-api-rules-read-availability.slo',
        slos: [
          slo.errorburn({
            alertName: 'APIRulesReadAvailabilityErrorBudgetBurning',
            alertMessage: 'API /rules endpoint is burning too much error budget to guarantee availability SLOs',
            metric: 'http_requests_total',
            selectors: [apiJobSelector, 'group="metricsv1"', 'handler=~"rules"', 'code=~"^(2..|3..|5..)$"'],
            errorSelectors: ['code=~"5.+"'],
            target: 0.90,
          }),
        ],
      },
      {

        name: 'rhobs-' + instance + '-api-rules-raw-read-availability.slo',
        slos: [
          slo.errorburn({
            alertName: 'APIRulesRawReadAvailabilityErrorBudgetBurning',
            alertMessage: 'API /rules/raw endpoint is burning too much error budget to guarantee availability SLOs',
            metric: 'http_requests_total',
            selectors: [apiJobSelector, 'group="metricsv1"', 'handler=~"rules-raw"', 'code=~"^(2..|3..|5..)$"'],
            errorSelectors: ['code=~"5.+"'],
            target: 0.90,
          }),
        ],
      },
      {
        name: 'rhobs-' + instance + '-api-alerting-availability.slo',
        slos: [
          slo.errorburn({
            alertName: 'APIAlertmanagerAvailabilityErrorBudgetBurning',
            alertMessage: 'API Thanos Rule failing to send alerts to Alertmanager and is burning too much error budget to guarantee availability SLOs',
            metric: 'thanos_alert_sender_alerts_dropped_total',
            selectors: ['container="thanos-rule"', 'namespace="' + utils.instanceNamespace(instance, metricsNamespace, upNamespace) + '"'],
            target: 0.95,
          }),
          slo.errorburn({
            alertName: 'APIAlertmanagerNotificationsAvailabilityErrorBudgetBurning',
            alertMessage: 'API Alertmanager failing to deliver alerts to upstream targets and is burning too much error budget to guarantee availability SLOs',
            metric: 'alertmanager_notifications_failed_total',
            selectors: ['service="observatorium-alertmanager"', 'namespace="' + utils.instanceNamespace(instance, metricsNamespace, upNamespace) + '"'],
            target: 0.95,
          }),
        ],
      },
    ],
  },

  local mstStageSLOs = apiSLOs('mst', 'observatorium-mst-stage', 'observatorium-mst-stage', 'observatorium-observatorium-mst-api').slos,
  local mstProductionSLOs = apiSLOs('mst', 'observatorium-mst-production', 'observatorium-mst-production', 'observatorium-observatorium-mst-api').slos,

  'rhobs-slos-mst-stage.prometheusrules': renderAlerts('rhobs-slos-mst-stage', 'stage', flatten(mstStageSLOs)),
  'rhobs-slos-mst-production.prometheusrules': renderAlerts('rhobs-slos-mst-production', 'production', flatten(mstProductionSLOs)),

  local telemeterStageSLOs = telemeterServerSLOs + apiSLOs('telemeter', 'observatorium-stage', 'observatorium-metrics-stage', 'observatorium-observatorium-api').slos,
  local telemeterProductionSLOs = telemeterServerSLOs + apiSLOs('telemeter', 'observatorium-production', 'observatorium-metrics-production', 'observatorium-observatorium-api').slos,

  'rhobs-slos-telemeter-stage.prometheusrules': renderAlerts('rhobs-slos-telemeter-stage', 'stage', flatten(telemeterStageSLOs)),
  'rhobs-slos-telemeter-production.prometheusrules': renderAlerts('rhobs-slos-telemeter-production', 'production', flatten(telemeterProductionSLOs)),
}

{
  local thanosAlerts =
    (import 'github.com/thanos-io/thanos/mixin/alerts/absent.libsonnet') +
    (import 'github.com/thanos-io/thanos/mixin/alerts/compact.libsonnet') +
    (import 'github.com/thanos-io/thanos/mixin/alerts/query.libsonnet') +
    (import 'github.com/thanos-io/thanos/mixin/alerts/receive.libsonnet') +
    (import 'github.com/thanos-io/thanos/mixin/alerts/store.libsonnet') +
    (import 'github.com/thanos-io/thanos/mixin/alerts/rule.libsonnet') +
    (import 'github.com/observatorium/thanos-receive-controller/jsonnet/thanos-receive-controller-mixin/mixin.libsonnet') +
    config.thanos,

  'observatorium-thanos-stage.prometheusrules': renderAlerts('observatorium-thanos-stage', 'stage', thanosAlerts),
  'observatorium-thanos-production.prometheusrules': renderAlerts('observatorium-thanos-production', 'production', thanosAlerts),
}

{
  local obsSLOs(name) = {
    local logsGroup = 'logsv1',
    local metricsGroup = 'metricsv1',
    // local metricLatency = 'http_request_duration_seconds',
    local metricError = 'http_requests_total',
    local writeMetricsSelector(group) = {
      selectors: ['group="%s"' % group, 'handler="receive"', 'job="%s"' % name],
    },
    local queryMetricsSelector(group) = {
      selectors: ['group="%s"' % group, 'handler=~"query|query_legacy"', 'job="%s"' % name],
    },
    local queryRangeMetricsSelector(group) = {
      selectors: ['group="%s"' % group, 'handler="query_range"', 'job="%s"' % name],
    },
    local pushLogsSelector(group) = {
      selectors: ['group="%s"' % group, 'handler="push"', 'job="%s"' % name],
    },
    local queryLogsSelector(group) = {
      selectors: ['group="%s"' % group, 'handler=~"query|label|labels|label_values"', 'job="%s"' % name],
    },
    local queryRangeLogsSelector(group) = {
      selectors: ['group="%s"' % group, 'handler="query_range"', 'job="%s"' % name],
    },
    local tailLogsSelector(group) = {
      selectors: ['group="%s"' % group, 'handler="tail|prom_tail"', 'job="%s"' % name],
    },

    local alertNameLogsErrors = 'ObservatoriumAPILogsErrorsSLOBudgetBurn',
    local alertNameMetricsErrors = 'ObservatoriumAPIMetricsErrorsSLOBudgetBurn',
    // local alertNameLatency = 'ObservatoriumAPILatencySLOBudgetBurn',

    errorBurn:: [
      {
        name: 'observatorium-api-write-metrics-errors.slo',
        config: writeMetricsSelector(metricsGroup) {
          alertName: alertNameMetricsErrors,
          metric: metricError,
          target: 0.99,
        },
      },
      {
        name: 'observatorium-api-query-metrics-errors.slo',
        config: queryMetricsSelector(metricsGroup) {
          alertName: alertNameMetricsErrors,
          metric: metricError,
          target: 0.95,
        },
      },
      {
        name: 'observatorium-api-query-range-metrics-errors.slo',
        config: queryRangeMetricsSelector(metricsGroup) {
          alertName: alertNameMetricsErrors,
          metric: metricError,
          target: 0.90,
        },
      },
      {
        name: 'observatorium-api-push-logs-errors.slo',
        config: pushLogsSelector(logsGroup) {
          alertName: alertNameLogsErrors,
          metric: metricError,
          target: 0.90,
        },
      },
      {
        name: 'observatorium-api-query-logs-errors.slo',
        config: queryLogsSelector(logsGroup) {
          alertName: alertNameLogsErrors,
          metric: metricError,
          target: 0.90,
        },
      },
      {
        name: 'observatorium-api-query-range-logs-errors.slo',
        config: queryRangeLogsSelector(logsGroup) {
          alertName: alertNameLogsErrors,
          metric: metricError,
          target: 0.90,
        },
      },
      {
        name: 'observatorium-api-tail-logs-errors.slo',
        config: tailLogsSelector(logsGroup) {
          alertName: alertNameLogsErrors,
          metric: metricError,
          target: 0.90,
        },
      },
    ],

    // TODO: add these only when we have enough metrics to have an SLO
    //   latencyBurn:: [
    //     {
    //       name: 'observatorium-api-write-latency-low.slo',
    //       config: writeMetricsSelector {
    //         alertName: alertNameLatency,
    //         metric: metricLatency,
    //         latencyTarget: '0.2',
    //         latencyBudget: 1 - 0.95,
    //       },
    //     },
    //     {
    //       name: 'observatorium-api-write-latency-high.slo',
    //       config: writeMetricsSelector {
    //         alertName: alertNameLatency,
    //         metric: metricLatency,
    //         latencyTarget: '1',
    //         latencyBudget: 1 - 0.99,
    //       },
    //     },
    //     {
    //       name: 'observatorium-api-query-latency-low.slo',
    //       config: queryMetricsSelector {
    //         alertName: alertNameLatency,
    //         metric: metricLatency,
    //         latencyTarget: '1',
    //         latencyBudget: 1 - 0.95,
    //       },
    //     },
    //     {
    //       name: 'observatorium-api-query-latency-high.slo',
    //       config: queryMetricsSelector {
    //         alertName: alertNameLatency,
    //         metric: metricLatency,
    //         latencyTarget: '2.5',
    //         latencyBudget: 1 - 0.99,
    //       },
    //     },
    //     {
    //       name: 'observatorium-api-query-range-latency-low.slo',
    //       config: queryRangeMetricsSelector {
    //         alertName: alertNameLatency,
    //         metric: metricLatency,
    //         latencyTarget: '60',
    //         latencyBudget: 1 - 0.90,
    //       },
    //     },
    //     {
    //       name: 'observatorium-api-query-range-latency-high.slo',
    //       config: queryRangeMetricsSelector {
    //         alertName: alertNameLatency,
    //         metric: metricLatency,
    //         latencyTarget: '120',
    //         latencyBudget: 1 - 0.95,
    //       },
    //     },
    //   ],
  },

  local api = {
    prometheusAlerts+:: {
      groups: [
        // TODO: add these only when we have enough metrics to have an SLO
        //   {
        //     name: s.name,
        //     local d = slo.latencyburn(s.config),
        //     rules:
        //       d.recordingrules +
        //       d.alerts,
        //   }
        //   for s in obsSLOs.latencyBurn
        // ] + [
        {
          local d = slo.errorburn(s.config),
          name: s.name,
          rules:
            d.recordingrules +
            d.alerts,
        }
        // NOTICE: Templating systems conflicting here.
        // The value of obs.manifests['api-service'].metadata.name was used.
        // That value is no OBSERVATORIUM_API_IDENTIFIER
        // So passing it here manually.
        for s in obsSLOs('observatorium-observatorium-api').errorBurn
      ],
    },
  },

  'observatorium-api-stage.prometheusrules': renderAlerts('observatorium-api-stage', 'stage', api),
  'observatorium-api-production.prometheusrules': renderAlerts('observatorium-api-production', 'production', api),
}

{
  'observatorium-logs-recording-rules.prometheusrules': renderRules('observatorium-logs-recording-rules', loki),

  local obsLogsStageEnv = 'observatorium-mst-stage',
  local obsLogsStage = loki + lokiTenants(obsLogsStageEnv),
  'rhobs-logs-mst-stage.prometheusrules': renderAlerts(obsLogsStageEnv, 'stage', obsLogsStage),

  local obsLogsProdEnv = 'observatorium-mst-production',
  local obsLogsProd = loki + lokiTenants(obsLogsProdEnv),
  'rhobs-logs-mst-production.prometheusrules': renderAlerts(obsLogsProdEnv, 'production', obsLogsProd),
}

{
  local gubernator = absent('gubernator', 'observatorium-gubernator'),

  'observatorium-gubernator-stage.prometheusrules': renderAlerts('observatorium-gubernator-stage', 'stage', gubernator),
  'observatorium-gubernator-production.prometheusrules': renderAlerts('observatorium-gubernator-production', 'production', gubernator),
}

{
  local customAlerts = {
    // Custom alerts.
    prometheusAlerts+:: {
      groups: [
        {
          name: 'observatorium-metrics',
          rules: [
            {
              alert: 'ObservatoriumNoStoreBlocksLoaded',
              annotations: {
                description: 'Observatorium Thanos Store {{$labels.namespace}}/{{$labels.job}} has not loaded any blocks in the last 6 hours.',
                summary: 'Observatorium Thanos Store has not loaded any blocks in the last 6 hours.',
              },
              expr: |||
                absent(thanos_bucket_store_blocks_last_loaded_timestamp_seconds) != 1 and (time() - thanos_bucket_store_blocks_last_loaded_timestamp_seconds) > 6 * 60 * 60
              ||| % config.thanos.store,
              'for': '10m',
              labels: {
                severity: 'warning',
              },
            },
            {
              alert: 'ObservatoriumNoRulesLoaded',
              annotations: {
                description: 'Observatorium Thanos Ruler {{$labels.namespace}}/{{$labels.job}} has not any rules loaded.',
                summary: 'Observatorium Thanos Ruler has not any rule to evaluate. This should not have happened. Check out the configuration.',
              },
              expr: |||
                sum by (namespace, job) (thanos_rule_loaded_rules{%(selector)s}) == 0
              ||| % config.thanos.rule,
              'for': '5m',
              labels: {
                severity: 'critical',
              },
            },
            {
              alert: 'ObservatoriumPersistentVolumeUsageHigh',
              annotations: {
                description: 'The PersistentVolume claimed by {{ $labels.persistentvolumeclaim }} in namespace {{ $labels.namespace }} has {{ printf "%0.2f" $value }}% of free space',
                summary: 'One or more of the PersistentVolumes in Observatorium is over 90% full. They might need to be extended.',
              },
              expr: |||
                100 * kubelet_volume_stats_available_bytes{job="kubelet",namespace!~"^openshift-.*$",persistentvolumeclaim=~"data-observatorium-thanos-.*"}
                /
                kubelet_volume_stats_capacity_bytes{job="kubelet",namespace!~"^openshift-.*$",persistentvolumeclaim=~"data-observatorium-thanos-.*"} < 10
              |||,
              'for': '10m',
              labels: {
                severity: 'warning',
              },
            },
            {
              alert: 'ObservatoriumPersistentVolumeUsageCritical',
              annotations: {
                description: 'The PersistentVolume claimed by {{ $labels.persistentvolumeclaim }} in namespace {{ $labels.namespace }} is only {{ printf "%0.2f" $value }}% free',
                summary: 'One or more of the PersistentVolumes in Observatorium is critically filled. They need to be extended.',
              },
              expr: |||
                100 * kubelet_volume_stats_available_bytes{job="kubelet",namespace!~"^openshift-.*$",persistentvolumeclaim=~"data-observatorium-thanos-.*"}
                /
                kubelet_volume_stats_capacity_bytes{job="kubelet",namespace!~"^openshift-.*$",persistentvolumeclaim=~"data-observatorium-thanos-.*"} < 5
              |||,
              'for': '10m',
              labels: {
                severity: 'critical',
              },
            },
          ],
        },
      ],
    },
  },

  'observatorium-custom-metrics-stage.prometheusrules': renderAlerts('observatorium-metrics-stage', 'stage', customAlerts),
  'observatorium-custom-metrics-production.prometheusrules': renderAlerts('observatorium-metrics-production', 'production', customAlerts),
}

{
  local tenantsAlerts = {
    // Alerts for failures related to tenants (instantiation etc.).
    prometheusAlerts+:: {
      groups: [
        {
          name: 'observatorium-tenants',
          rules: [
            {
              alert: 'ObservatoriumTenantsFailedOIDCRegistrations',
              annotations: {
                message: 'Increase in failed attempts to register with OIDC provider for {{ $labels.tenant }}',
              },
              expr: |||
                sum(increase(observatorium_api_tenants_failed_registrations[5m])) by (tenant) > 0
              |||,
              labels: {
                severity: 'warning',
              },
            },
            {
              alert: 'ObservatoriumTenantsSkippedDuringConfiguration',
              annotations: {
                message: 'Tenant {{ $labels.tenant }} was skipped due to misconfiguration',
              },
              expr: |||
                sum(increase(observatorium_api_tenants_skipped_invalid_configuration[5m])) by (tenant, namespace) > 0
              |||,
              labels: {
                severity: 'warning',
              },
            },
          ],
        },
      ],
    },
  },

  'observatorium-tenants-stage.prometheusrules': renderAlerts('observatorium-tenants-stage', 'stage', tenantsAlerts),
  'observatorium-tenants-production.prometheusrules': renderAlerts('observatorium-tenants-production', 'production', tenantsAlerts),
}

{
  local proactiveMonitoringAlerts = {
    // Alerts for traffic generated by proactive monitoring.
    prometheusAlerts+:: {
      groups: [
        {
          name: 'observatorium-proactive-monitoring',
          rules: [
            {
              alert: 'ObservatoriumProActiveMetricsQueryErrorRateHigh',
              annotations: {
                message: 'Observatorium metric queries {{$labels.job}} in {{$labels.namespace}} are failing to handle {{$value | humanize}}% of requests.',
              },
              expr: |||
                ( sum by (namespace, job, query) (rate(up_custom_query_errors_total[5m])) / sum by (namespace, job, query) (rate(up_custom_query_executed_total[5m]))) * 100 > 25
              |||,
              labels: {
                severity: 'warning',
              },
            },
          ],
        },
      ],
    },
  },

  'observatorium-proactive-monitoring-stage.prometheusrules': renderAlerts('observatorium-proactive-monitoring-stage', 'stage', proactiveMonitoringAlerts),
  'observatorium-proactive-monitoring-production.prometheusrules': renderAlerts('observatorium-proactive-monitoring-production', 'production', proactiveMonitoringAlerts),
}

{
  local httpTrafficMonitoringAlerts = {
    // Alerts for HTTP traffic.
    prometheusAlerts+:: {
      groups: [
        {
          name: 'observatorium-http-traffic',
          rules: [
            {
              alert: 'ObservatoriumHttpTrafficErrorRateHigh',
              annotations: {
                message: 'Observatorium route  {{$labels.route}}  are failing to handle {{$value | humanize}}% of requests.',
              },
              expr: |||
                (sum by (route) (rate(haproxy_backend_http_responses_total{route=~"observatorium.*|telemeter.*|infogw.*", code="5xx"} [5m])) / sum by (route) (rate(haproxy_backend_http_responses_total{route=~"observatorium.*|telemeter.*|infogw.*"}[5m]))) * 100 > 25
              |||,
              labels: {
                severity: 'warning',
              },
            },
          ],
        },
      ],
    },
  },

  'observatorium-http-traffic-stage.prometheusrules': renderAlerts('observatorium-http-traffic-stage', 'stage', httpTrafficMonitoringAlerts),
  'observatorium-http-traffic-production.prometheusrules': renderAlerts('observatorium-http-traffic-production', 'production', httpTrafficMonitoringAlerts),
}
