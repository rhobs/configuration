local loki = (import 'github.com/grafana/loki/production/loki-mixin/mixin.libsonnet');
local slo = import 'github.com/metalmatze/slo-libsonnet/slo-libsonnet/slo.libsonnet';
local obs = import '../services/observatorium.libsonnet';

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

  local dashboardID = function(name) {
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
        std.startsWith(name, 'observatorium-api') then 'Tg-mH0rizaSJDKSADX'
      else if
        std.startsWith(name, 'telemeter') then 'Tg-mH0rizaSJDKSADJ'
      else if
        std.startsWith(name, 'loki') then 'Lg-mH0rizaSJDKSADX'
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
      then 'obervatorium-logs'
      else 'telemeter',
  },

  local pruneUnsupportedLabels = function(labels) {
    // Prune selector label because not allowed by AppSRE
    labels: std.prune(labels {
      group: null,
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
                  runbook: 'https://gitlab.cee.redhat.com/observatorium/configuration/blob/master/docs/sop/observatorium.md#%s' % std.asciiLower(r.alert),
                  dashboard: 'https://grafana.app-sre.devshift.net/d/%s/api-logs?orgId=1&refresh=1m&var-datasource=%s' % [
                    dashboardID('loki').id,
                    dashboardDatasource(environment).datasource,
                  ],
                }
              else if std.startsWith(g.name, 'telemeter') then
                {
                  runbook: 'https://gitlab.cee.redhat.com/observatorium/configuration/blob/master/docs/sop/telemeter.md#%s' % std.asciiLower(r.alert),
                  dashboard: 'https://grafana.app-sre.devshift.net/d/%s/telemeter?orgId=1&refresh=1m&var-datasource=%s' % [
                    dashboardID(g.name).id,
                    dashboardDatasource(environment).datasource,
                  ],
                }
              else
                {
                  runbook: 'https://gitlab.cee.redhat.com/observatorium/configuration/blob/master/docs/sop/observatorium.md#%s' % std.asciiLower(r.alert),
                  dashboard: 'https://grafana.app-sre.devshift.net/d/%s/%s?orgId=1&refresh=10s&var-datasource=%s&var-namespace={{$labels.namespace}}&var-job=All&var-pod=All&var-interval=5m' % [
                    dashboardID(g.name).id,
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
  local telemeterSLOs = [
    {
      name: 'telemeter-upload.slo',
      slos: [
        slo.errorburn({
          alertName: 'TelemeterUploadErrorBudgetBurning',
          alertMessage: 'Telemeter /upload is burning too much error budget to gurantee overall availability',
          metric: 'haproxy_server_http_responses_total',
          selectors: ['route="telemeter-server-upload"'],
          errorSelectors: ['code="5xx"'],
          target: 0.98,
        }),
      ],
    },
    {
      name: 'telemeter-authorize.slo',
      slos: [
        slo.errorburn({
          alertName: 'TelemeterAuthorizeErrorBudgetBurning',
          alertMessage: 'Telemeter /authorize is burning too much error budget to gurantee overall availability',
          metric: 'haproxy_server_http_responses_total',
          selectors: ['route="telemeter-server-authorize"'],
          errorSelectors: ['code="5xx"'],
          target: 0.98,
        }),
      ],
    },
  ],

  local telemeter = {
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
        for group in telemeterSLOs
      ],
    },
  },

  'telemeter-slos-stage.prometheusrules': renderAlerts('telemeter-slos-stage', 'stage', telemeter),
  'telemeter-slos-production.prometheusrules': renderAlerts('telemeter-slos-production', 'production', telemeter),
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

  'observatorium-logs-stage.prometheusrules': renderAlerts('observatorium-logs-stage', 'stage', loki),
  'observatorium-logs-production.prometheusrules': renderAlerts('observatorium-logs-production', 'production', loki),
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
          ],
        },
      ],
    },
  },

  'observatorium-custom-metrics-stage.prometheusrules': renderAlerts('observatorium-metrics-stage', 'stage', customAlerts),
  'observatorium-custom-metrics-production.prometheusrules': renderAlerts('observatorium-metrics-production', 'production', customAlerts),
}
