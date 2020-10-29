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
local appSREOverwrites(prometheusAlerts, namespace) = {
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
        std.startsWith(name, 'loki') then 'no-dashboard'
      else if
        std.startsWith(name, 'gubernator') then 'no-dashboard'
      else error 'no dashboard id for group %s' % name,
  },

  local setSeverity = function(label, alertName) {
    label: if std.startsWith(alertName, 'Loki') then 'info'
    else if label == 'critical' then
      // For thanos page only for `ThanosNoRuleEvaluations`.
      if std.startsWith(alertName, 'Thanos') then
        if alertName != 'ThanosNoRuleEvaluations' then 'high' else label
      else label
    else if label == 'warning' then 'medium'
    else 'high',
  },

  groups: [
    g {
      rules: [
        if std.objectHas(r, 'alert') then
          r {
            annotations+: {
              runbook: 'https://gitlab.cee.redhat.com/observatorium/configuration/blob/master/docs/sop/observatorium.md#%s' % std.asciiLower(r.alert),
              dashboard: if std.startsWith(g.name, 'telemeter') then 'https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADJ/telemeter?orgId=1&refresh=1m&var-datasource=telemeter-prod-01-prometheus'
              else 'https://grafana.app-sre.devshift.net/d/%s/%s?orgId=1&refresh=10s&var-datasource=app-sre-prometheus&var-namespace=%s&var-job=All&var-pod=All&var-interval=5m' % [
                dashboardID(g.name).id,
                g.name,
                namespace,
              ],
            },
            labels+: {
              service: 'telemeter',
              severity: setSeverity(r.labels.severity, r.alert).label,
            },
          } else r
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
    prometheusAlerts+:: appSREOverwrites(super.prometheusAlerts, namespace),
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
  'telemeter-slos-production.prometheusrules': renderAlerts('telemeter-slos-production', 'telemeter-prodcution', telemeter),
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
        bucketOpsP99LatencyThreshold: 3,
      },
    },

  'observatorium-thanos-stage.prometheusrules': renderAlerts('observatorium-thanos-stage', 'telemeter-stage', thanosAlerts),
  'observatorium-thanos-production.prometheusrules': renderAlerts('observatorium-thanos-production', 'telemeter-production', thanosAlerts),
}

{
  local obsSLOs = {
    local metricLatency = 'http_request_duration_seconds',
    local metricError = 'http_requests_total',
    local writeSelector = {
      selectors: ['handler="receive"', 'job="%s"' % obs.manifests['api-service'].metadata.name],
    },
    local querySelector = {
      selectors: ['handler=~"query|query_legacy"', 'job="%s"' % obs.manifests['api-service'].metadata.name],
    },
    local queryRangeSelector = {
      selectors: ['handler="query_range"', 'job="%s"' % obs.manifests['api-service'].metadata.name],
    },

    local alertNameErrors = 'ObservatoriumAPIErrorsSLOBudgetBurn',
    local alertNameLatency = 'ObservatoriumAPILatencySLOBudgetBurn',

    errorBurn:: [
      {
        name: 'observatorium-api-write-errors.slo.rules',
        config: writeSelector {
          alertName: alertNameErrors,
          metric: metricError,
          target: 0.99,
        },
      },
      {
        name: 'observatorium-api-query-errors.slo.rules',
        config: querySelector {
          alertName: alertNameErrors,
          metric: metricError,
          target: 0.95,
        },
      },
      {
        name: 'observatorium-api-query-range-errors.slo.rules',
        config: queryRangeSelector {
          alertName: alertNameErrors,
          metric: metricError,
          target: 0.90,
        },
      },
    ],

    // TODO: add these only when we have enough metrics to have an SLO
    //   latencyBurn:: [
    //     {
    //       name: 'observatorium-api-write-latency-low.slo.rules',
    //       config: writeSelector {
    //         alertName: alertNameLatency,
    //         metric: metricLatency,
    //         latencyTarget: '0.2',
    //         latencyBudget: 1 - 0.95,
    //       },
    //     },
    //     {
    //       name: 'observatorium-api-write-latency-high.slo.rules',
    //       config: writeSelector {
    //         alertName: alertNameLatency,
    //         metric: metricLatency,
    //         latencyTarget: '1',
    //         latencyBudget: 1 - 0.99,
    //       },
    //     },
    //     {
    //       name: 'observatorium-api-query-latency-low.slo.rules',
    //       config: querySelector {
    //         alertName: alertNameLatency,
    //         metric: metricLatency,
    //         latencyTarget: '1',
    //         latencyBudget: 1 - 0.95,
    //       },
    //     },
    //     {
    //       name: 'observatorium-api-query-latency-high.slo.rules',
    //       config: querySelector {
    //         alertName: alertNameLatency,
    //         metric: metricLatency,
    //         latencyTarget: '2.5',
    //         latencyBudget: 1 - 0.99,
    //       },
    //     },
    //     {
    //       name: 'observatorium-api-query-range-latency-low.slo.rules',
    //       config: queryRangeSelector {
    //         alertName: alertNameLatency,
    //         metric: metricLatency,
    //         latencyTarget: '60',
    //         latencyBudget: 1 - 0.90,
    //       },
    //     },
    //     {
    //       name: 'observatorium-api-query-range-latency-high.slo.rules',
    //       config: queryRangeSelector {
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
  'observatorium-loki-recording-rules.prometheusrules': renderRules('observatorium-loki-recording-rules', 'telemeter', loki),

  'observatorium-loki-stage.prometheusrules': renderAlerts('observatorium-loki-stage', 'telemeter-stage', loki),
  'observatorium-loki-production.prometheusrules': renderAlerts('observatorium-loki-production', 'telemeter-production', loki),
}

{
  local gubernator = absent('gubernator', 'observatorium-gubernator'),

  'observatorium-gubernator-stage.prometheusrules': renderAlerts('observatorium-gubernator-stage', 'telemeter-stage', gubernator),
  'observatorium-gubernator-production.prometheusrules': renderAlerts('observatorium-gubernator-production', 'telemeter-production', gubernator),
}
