local obs = import 'environments/production/obs.jsonnet';
local slo = import 'github.com/metalmatze/slo-libsonnet/slo-libsonnet/slo.libsonnet';

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
];

local thanosAlerts =
  // (import 'thanos-mixin/alerts/absent.libsonnet') + // TODO: need to be fixed upstream.
  (import 'thanos-mixin/alerts/compact.libsonnet') +
  (import 'thanos-mixin/alerts/query.libsonnet') +
  (import 'thanos-mixin/alerts/receive.libsonnet') +
  (import 'thanos-mixin/alerts/store.libsonnet') +
  (import 'thanos-mixin/alerts/rule.libsonnet') +
  (import 'thanos-receive-controller-mixin/mixin.libsonnet') +
  (import 'selectors.libsonnet') {
    query+:: {
      p99QueryLatencyThreshold: 90,
    },
  };

// Add dashboards and runbook anntotations.
// Overwrite severity to medium and high.
local appSREOverwrites = function(prometheusAlerts, namespace) {
  local setSeverity = function(label, alertName) {
    label: if label == 'critical' then
      // For thanos page only for `ThanosNoRuleEvaluations`.
      if std.startsWith(alertName, 'Thanos') then
        if alertName != 'ThanosNoRuleEvaluations' then 'high' else label
      else label
    else if label == 'warning' then 'medium'
    else 'high',
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
      else error 'no dashboard id for group %s' % name,
  },

  groups: [
    g {
      rules: [
        if std.objectHas(r, 'alert') then
          r {
            annotations+: {
              runbook: 'https://gitlab.cee.redhat.com/observatorium/configuration/blob/master/docs/sop/observatorium.md#%s' % std.asciiLower(r.alert),
              dashboard: 'https://grafana.app-sre.devshift.net/d/%s/%s?orgId=1&refresh=10s&var-datasource=app-sre-prometheus&var-namespace=%s&var-job=All&var-pod=All&var-interval=5m' % [
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
};


{
  'telemeter-slos-production.prometheusrules': renderTelemeterSLOs('telemeter-slos-production'),
  'telemeter-slos-stage.prometheusrules': renderTelemeterSLOs('telemeter-slos-stage'),

  local renderTelemeterSLOs(name) = {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      name: name,
      labels: {
        prometheus: 'app-sre',
        role: 'alert-rules',
      },
    },
    spec: {
      groups: [
        {
          local slos = [
            [
              alert {
                labels+: {
                  service: 'telemeter',
                  severity: if alert.labels.severity == 'warning' then 'medium' else alert.labels.severity,
                  annotations+: {
                    runbook: 'https://gitlab.cee.redhat.com/observatorium/configuration/blob/master/docs/sop/observatorium.md#%s' % std.asciiLower(alert.alert),
                    dashboard: 'https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADJ/telemeter?orgId=1&refresh=1m&var-datasource=telemeter-prod-01-prometheus',
                  },
                },
              }
              for alert in slo.alerts
            ]
            +
            slo.recordingrules
            for slo in group.slos
          ],

          name: group.name,
          rules: std.flattenArrays(slos),
        }
        for group in telemeterSLOs
      ],
    },
  },

  'observatorium-thanos-stage.prometheusrules': renderThanos('observatorium-thanos-stage', 'telemeter-stage'),
  'observatorium-thanos-production.prometheusrules': renderThanos('observatorium-thanos-production', 'telemeter-production'),

  local renderThanos(name, namespace) = {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      name: name,
      labels: {
        prometheus: 'app-sre',
        role: 'alert-rules',
      },
    },

    local alerts = thanosAlerts {
    } + {
      prometheusAlerts+:: appSREOverwrites(super.prometheusAlerts, namespace),
    },

    spec: alerts.prometheusAlerts,
  },

  'observatorium-api-stage.prometheusrules': renderAPI('observatorium-api-stage', 'telemeter-stage'),

  'observatorium-api-production.prometheusrules': renderAPI('observatorium-api-production', 'telemeter-production'),

  local renderAPI(name, namespace) = {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      name: name,
      labels: {
        prometheus: 'app-sre',
        role: 'alert-rules',
      },
    },

    local a = {
      all+:: {
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
    } + {
      all+:: appSREOverwrites(super.all, namespace),
    },

    spec: a.all,
  },
}
