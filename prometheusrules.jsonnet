local observatoriumSLOs = import 'configuration/slos.libsonnet';
local slo = import 'slo-libsonnet/slo.libsonnet';

local thanosAlerts =
  // (import 'thanos-mixin/alerts/absent.libsonnet') + // TODO: need to be fixed upstream
  (import 'thanos-mixin/alerts/compact.libsonnet') +
  (import 'thanos-mixin/alerts/query.libsonnet') +
  (import 'thanos-mixin/alerts/receive.libsonnet') +
  (import 'thanos-mixin/alerts/store.libsonnet') +
  (import 'thanos-receive-controller-mixin/mixin.libsonnet') +
  (import 'selectors.libsonnet') {
    query+:: {
      p99QueryLatencyThreshold: 90,
    },
  };

// Add dashboards and runbook anntotations
// Overwrite severity to medium and high
local appSREOverwrites = function(prometheusAlerts, namespace) {
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
        name == 'thanos-receive-controller.rules' then 'no-dashboard'
      else if
        name == 'thanos-component-absent.rules' then 'no-dashboard'
      else if
        std.startsWith(name, 'observatorium-gateway') then 'Tg-mH0rizaSJDKSADX'
      else error 'no dashboard id for group %s' % name,
  },

  groups: [
    g {
      rules: [
        if std.objectHas(r, 'alert') then
          r {
            annotations+: {
              runbook: 'https://gitlab.cee.redhat.com/service/app-interface/blob/master/docs/telemeter/sop/observatorium.md#%s' % std.asciiLower(r.alert),
              dashboard: 'https://grafana.app-sre.devshift.net/d/%s/%s?orgId=1&refresh=10s&var-datasource=app-sre-prometheus&var-namespace=%s&var-job=All&var-pod=All&var-interval=5m' % [
                dashboardID(g.name).id,
                g.name,
                namespace,
              ],
            },
            labels+: {
              service: 'telemeter',
              severity: if r.labels.severity == 'warning' then 'medium' else 'high',
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
            r.alert == 'ThanosStoreSeriesGateLatencyHigh' ||
            r.alert == 'ThanosQueryHttpRequestQueryRangeErrorRateHigh'
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
    selectors: ['handler="write"'],
  },
  local querySelector = {
    selectors: ['handler="query"'],
  },
  local queryRangeSelector = {
    selectors: ['handler="query_range"'],
  },


  local alertNameErrors = 'ObservatoriumGatewayErrorsSLOBudgetBurn',
  local alertNameLatency = 'ObservatoriumGatewayLatencySLOBudgetBurn',

  errorBurn:: [
    {
      name: 'observatorium-gateway-write-errors.slo.rules',
      config: writeSelector {
        alertName: alertNameErrors,
        metric: metricError,
        errorBudget: 1 - 0.99,
      },
    },
    {
      name: 'observatorium-gateway-query-errors.slo.rules',
      config: querySelector {
        alertName: alertNameErrors,
        metric: metricError,
        errorBudget: 1 - 0.95,
      },
    },
    {
      name: 'observatorium-gateway-query-range-errors.slo.rules',
      config: queryRangeSelector {
        alertName: alertNameErrors,
        metric: metricError,
        errorBudget: 1 - 0.90,
      },
    },
  ],

  // TODO: add these only when we have enough metrics to have an SLO
  //   latencyBurn:: [
  //     {
  //       name: 'observatorium-gateway-write-latency-low.slo.rules',
  //       config: writeSelector {
  //         alertName: alertNameLatency,
  //         metric: metricLatency,
  //         latencyTarget: '0.2',
  //         latencyBudget: 1 - 0.95,
  //       },
  //     },
  //     {
  //       name: 'observatorium-gateway-write-latency-high.slo.rules',
  //       config: writeSelector {
  //         alertName: alertNameLatency,
  //         metric: metricLatency,
  //         latencyTarget: '1',
  //         latencyBudget: 1 - 0.99,
  //       },
  //     },
  //     {
  //       name: 'observatorium-gateway-query-latency-low.slo.rules',
  //       config: querySelector {
  //         alertName: alertNameLatency,
  //         metric: metricLatency,
  //         latencyTarget: '1',
  //         latencyBudget: 1 - 0.95,
  //       },
  //     },
  //     {
  //       name: 'observatorium-gateway-query-latency-high.slo.rules',
  //       config: querySelector {
  //         alertName: alertNameLatency,
  //         metric: metricLatency,
  //         latencyTarget: '2.5',
  //         latencyBudget: 1 - 0.99,
  //       },
  //     },
  //     {
  //       name: 'observatorium-gateway-query-range-latency-low.slo.rules',
  //       config: queryRangeSelector {
  //         alertName: alertNameLatency,
  //         metric: metricLatency,
  //         latencyTarget: '60',
  //         latencyBudget: 1 - 0.90,
  //       },
  //     },
  //     {
  //       name: 'observatorium-gateway-query-range-latency-high.slo.rules',
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

  'observatorium-gateway-stage.prometheusrules': renderGateway('observatorium-gateway-stage', 'telemeter-stage'),

  'observatorium-gateway-production.prometheusrules': renderGateway('observatorium-gateway-production', 'telemeter-production'),

  local renderGateway(name, namespace) = {
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
