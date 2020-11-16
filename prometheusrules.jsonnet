local loki = (import 'loki-mixin/mixin.libsonnet');
local obs = import 'environments/production/obs.jsonnet';
local slo = import 'github.com/metalmatze/slo-libsonnet/slo-libsonnet/slo.libsonnet';

local absent(name, job) = {
  prometheusAlerts+:: {
    groups+: [
      {
        name: '%s-absent.rules' % name,
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
local appSREOverwrites(namespace) = {
  local nscomponents = std.split(namespace, '-'),
  local environment = nscomponents[std.length(nscomponents) - 1],
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
        name == 'thanos-query.rules' then '98fde97ddeaf2981041745f1f2ba68c2'
      else if
        name == 'thanos-compact.rules' then '651943d05a8123e32867b4673963f42b'
      else if
        name == 'thanos-receive.rules' then '916a852b00ccc5ed81056644718fa4fb'
      else if
        name == 'thanos-store.rules' then 'e832e8f26403d95fac0ea1c59837588b'
      else if
        name == 'thanos-rule.rules' then '35da848f5f92b2dc612e0c3a0577b8a1'
      else if
        name == 'thanos-receive-controller.rules' then 'no-dashboard'
      else if
        name == 'thanos-component-absent.rules' then 'no-dashboard'
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
                  dashboard: 'https://grafana.app-sre.devshift.net/d/%s/%s?orgId=1&refresh=10s&var-datasource=%s&var-namespace=%s&var-job=All&var-pod=All&var-interval=5m' % [
                    dashboardID(g.name).id,
                    g.name,
                    dashboardDatasource(environment).datasource,
                    namespace,
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
            r.alert == 'ThanosQueryHttpRequestQueryRangeErrorRateHigh' ||
            r.alert == 'ThanosQueryRangeLatencyHigh' ||
            r.alert == 'ThanosStoreSeriesGateLatencyHigh'
          )
        ),
        super.rules,
      ),
    }
    for g in super.groups
  ],
};


local renderPrometheusRules(name, namespace, mixin) = {
  apiVersion: 'monitoring.coreos.com/v1',
  kind: 'PrometheusRule',
  metadata: {
    name: name,
    labels: {
      prometheus: 'app-sre',
      role: 'all-rules',
    },
  },
  spec: mixin {
          prometheusAlerts+:: appSREOverwrites(super.prometheusAlerts, namespace),
        }.prometheusAlerts +
        mixin.prometheusRules,
};

local renderRules(name, _namespace, mixin) = {
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

local renderAlerts(name, namespace, mixin) = {
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
    prometheusAlerts+:: appSREOverwrites(namespace),
  }.prometheusAlerts,
};

{
  local telemeterSLOs = [
    {
      name: 'telemeter-upload.slo.rules',
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
      name: 'telemeter-authorize.slo.rules',
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

  'telemeter-slos-stage.prometheusrules': renderAlerts('telemeter-slos-stage', 'telemeter-stage', telemeter),
  'telemeter-slos-production.prometheusrules': renderAlerts('telemeter-slos-production', 'telemeter-production', telemeter),
}

{
  local thanosAlerts =
    (import 'thanos-mixin/alerts/absent.libsonnet') +
    (import 'thanos-mixin/alerts/compact.libsonnet') +
    (import 'thanos-mixin/alerts/query.libsonnet') +
    (import 'thanos-mixin/alerts/receive.libsonnet') +
    (import 'thanos-mixin/alerts/store.libsonnet') +
    (import 'thanos-mixin/alerts/rule.libsonnet') +
    (import 'thanos-receive-controller-mixin/mixin.libsonnet') +
    (import 'environments/production/selectors.libsonnet').thanos {
      query+:: {
        p99QueryLatencyThreshold: 90,
      },
      store+:: {
        bucketOpsP99LatencyThreshold: 6,
      },
    },

  'observatorium-thanos-stage.prometheusrules': renderAlerts('observatorium-thanos-stage', 'telemeter-stage', thanosAlerts),
  'observatorium-thanos-production.prometheusrules': renderAlerts('observatorium-thanos-production', 'telemeter-production', thanosAlerts),
}

{
  local obsSLOs = {
    local logsGroup = 'logsv1',
    local metricsGroup = 'metricsv1',
    local metricLatency = 'http_request_duration_seconds',
    local metricError = 'http_requests_total',
    local writeMetricsSelector(group) = {
      selectors: ['group="%s"' % group, 'handler="receive"', 'job="%s"' % obs.manifests['api-service'].metadata.name],
    },
    local queryMetricsSelector(group) = {
      selectors: ['group="%s"' % group, 'handler=~"query|query_legacy"', 'job="%s"' % obs.manifests['api-service'].metadata.name],
    },
    local queryRangeMetricsSelector(group) = {
      selectors: ['group="%s"' % group, 'handler="query_range"', 'job="%s"' % obs.manifests['api-service'].metadata.name],
    },
    local pushLogsSelector(group) = {
      selectors: ['group="%s"' % group, 'handler="push"', 'job="%s"' % obs.manifests['api-service'].metadata.name],
    },
    local queryLogsSelector(group) = {
      selectors: ['group="%s"' % group, 'handler=~"query|label|labels|label_values"', 'job="%s"' % obs.manifests['api-service'].metadata.name],
    },
    local queryRangeLogsSelector(group) = {
      selectors: ['group="%s"' % group, 'handler="query_range"', 'job="%s"' % obs.manifests['api-service'].metadata.name],
    },
    local tailLogsSelector(group) = {
      selectors: ['group="%s"' % group, 'handler="tail|prom_tail"', 'job="%s"' % obs.manifests['api-service'].metadata.name],
    },

    local alertNameLogsErrors = 'ObservatoriumAPILogsErrorsSLOBudgetBurn',
    local alertNameMetricsErrors = 'ObservatoriumAPIMetricsErrorsSLOBudgetBurn',
    local alertNameLatency = 'ObservatoriumAPILatencySLOBudgetBurn',

    errorBurn:: [
      {
        name: 'observatorium-api-write-metrics-errors.slo.rules',
        config: writeMetricsSelector(metricsGroup) {
          alertName: alertNameMetricsErrors,
          metric: metricError,
          target: 0.99,
        },
      },
      {
        name: 'observatorium-api-query-metrics-errors.slo.rules',
        config: queryMetricsSelector(metricsGroup) {
          alertName: alertNameMetricsErrors,
          metric: metricError,
          target: 0.95,
        },
      },
      {
        name: 'observatorium-api-query-range-metrics-errors.slo.rules',
        config: queryRangeMetricsSelector(metricsGroup) {
          alertName: alertNameMetricsErrors,
          metric: metricError,
          target: 0.90,
        },
      },
      {
        name: 'observatorium-api-push-logs-errors.slo.rules',
        config: pushLogsSelector(logsGroup) {
          alertName: alertNameLogsErrors,
          metric: metricError,
          target: 0.90,
        },
      },
      {
        name: 'observatorium-api-query-logs-errors.slo.rules',
        config: queryLogsSelector(logsGroup) {
          alertName: alertNameLogsErrors,
          metric: metricError,
          target: 0.90,
        },
      },
      {
        name: 'observatorium-api-query-range-logs-errors.slo.rules',
        config: queryRangeLogsSelector(logsGroup) {
          alertName: alertNameLogsErrors,
          metric: metricError,
          target: 0.90,
        },
      },
      {
        name: 'observatorium-api-tail-logs-errors.slo.rules',
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
    //       name: 'observatorium-api-write-latency-low.slo.rules',
    //       config: writeMetricsSelector {
    //         alertName: alertNameLatency,
    //         metric: metricLatency,
    //         latencyTarget: '0.2',
    //         latencyBudget: 1 - 0.95,
    //       },
    //     },
    //     {
    //       name: 'observatorium-api-write-latency-high.slo.rules',
    //       config: writeMetricsSelector {
    //         alertName: alertNameLatency,
    //         metric: metricLatency,
    //         latencyTarget: '1',
    //         latencyBudget: 1 - 0.99,
    //       },
    //     },
    //     {
    //       name: 'observatorium-api-query-latency-low.slo.rules',
    //       config: queryMetricsSelector {
    //         alertName: alertNameLatency,
    //         metric: metricLatency,
    //         latencyTarget: '1',
    //         latencyBudget: 1 - 0.95,
    //       },
    //     },
    //     {
    //       name: 'observatorium-api-query-latency-high.slo.rules',
    //       config: queryMetricsSelector {
    //         alertName: alertNameLatency,
    //         metric: metricLatency,
    //         latencyTarget: '2.5',
    //         latencyBudget: 1 - 0.99,
    //       },
    //     },
    //     {
    //       name: 'observatorium-api-query-range-latency-low.slo.rules',
    //       config: queryRangeMetricsSelector {
    //         alertName: alertNameLatency,
    //         metric: metricLatency,
    //         latencyTarget: '60',
    //         latencyBudget: 1 - 0.90,
    //       },
    //     },
    //     {
    //       name: 'observatorium-api-query-range-latency-high.slo.rules',
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
        for s in obsSLOs.errorBurn
      ],
    },
  },

  'observatorium-api-stage.prometheusrules': renderAlerts('observatorium-api-stage', 'telemeter-stage', api),
  'observatorium-api-production.prometheusrules': renderAlerts('observatorium-api-production', 'telemeter-production', api),
}

{
  'observatorium-logs-recording-rules.prometheusrules': renderRules('observatorium-logs-recording-rules', 'observatorium-logs', loki),

  'observatorium-logs-stage.prometheusrules': renderAlerts('observatorium-logs-stage', 'observatorium-logs-stage', loki),
  'observatorium-logs-production.prometheusrules': renderAlerts('observatorium-logs-production', 'observatorium-logs-production', loki),
}

{
  local gubernator = absent('gubernator', 'observatorium-gubernator'),

  'observatorium-gubernator-stage.prometheusrules': renderAlerts('observatorium-gubernator-stage', 'telemeter-stage', gubernator),
  'observatorium-gubernator-production.prometheusrules': renderAlerts('observatorium-gubernator-production', 'telemeter-production', gubernator),
}
