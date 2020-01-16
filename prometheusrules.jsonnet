local observatoriumSLOs = import 'observatorium/slos.libsonnet';
local slo = import 'slo-libsonnet/slo.libsonnet';

local thanosReceiveController = (import 'thanos-receive-controller-mixin/mixin.libsonnet');
local thanosAlerts =
  // (import 'thanos-mixin/alerts/absent.libsonnet') + // TODO: need to be fixed upstream
  (import 'thanos-mixin/alerts/compactor.libsonnet') +
  (import 'thanos-mixin/alerts/querier.libsonnet') +
  (import 'thanos-mixin/alerts/receiver.libsonnet') +
  (import 'thanos-mixin/alerts/store.libsonnet') + {
    compactor+:: {
      jobPrefix: 'thanos-compactor',
      selector: 'job=~"%s.*"' % self.jobPrefix,
    },
    querier+:: {
      jobPrefix: 'thanos-querier',
      selector: 'job=~"%s.*"' % self.jobPrefix,
    },
    receiver+:: {
      jobPrefix: 'thanos-receive',
      selector: 'job=~"%s.*"' % self.jobPrefix,
    },
    store+:: {
      jobPrefix: 'thanos-store',
      selector: 'job=~"%s.*"' % self.jobPrefix,
    },
  } + {
  };


// Add dashboards and runbook anntotations
// Overwrite severity to medium and high
local appSREOverwrites = function(prometheusAlerts, namespace) {
  local dashboardID = function(name) {
    id:
      if
        name == 'thanos-querier.rules' then '98fde97ddeaf2981041745f1f2ba68c2'
      else if
        name == 'thanos-compactor.rules' then '651943d05a8123e32867b4673963f42b'
      else if
        name == 'thanos-receiver.rules' then '916a852b00ccc5ed81056644718fa4fb'
      else if
        name == 'thanos-store.rules' then 'e832e8f26403d95fac0ea1c59837588b'
      else if
        name == 'thanos-receive-controller.rules' then 'no-dashboard'
      else if
        name == 'thanos-component-absent.rules' then 'no-dashboard'
      else error 'no dashboard id for group %s' % name,
  },

  groups: [
    g {
      rules: [
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
        }
        for r in super.rules
      ],
    }
    for g in super.groups
  ],
};

{
  'observatorium-thanos-stage.prometheusrules': {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      name: 'observatorium-thanos-stage',
      labels: {
        prometheus: 'app-sre',
        role: 'alert-rules',
      },
    },
    local namespace = 'telemeter-stage',

    local alerts = thanosAlerts + thanosReceiveController {
      prometheusAlerts+:: appSREOverwrites(super.prometheusAlerts, namespace),
    },

    spec: alerts.prometheusAlerts,
  },
  'observatorium-thanos-production.prometheusrules': {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      name: 'observatorium-thanos-production',
      labels: {
        prometheus: 'app-sre',
        role: 'alert-rules',
      },
    },
    local namespace = 'telemeter-production',
    local alerts = thanosAlerts + thanosReceiveController {
    } + {
      prometheusAlerts+:: appSREOverwrites(super.prometheusAlerts, namespace),
    },

    spec: alerts.prometheusAlerts,
  },
}
