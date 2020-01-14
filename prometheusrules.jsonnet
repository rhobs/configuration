local thanos = (import 'thanos-mixin/mixin.libsonnet');
local thanosReceiveController = (import 'thanos-receive-controller-mixin/mixin.libsonnet');
local slo = import 'slo-libsonnet/slo.libsonnet';
local observatoriumSLOs = import 'observatorium/slos.libsonnet';

// Add dashboards and runbook anntotations
// Overwrite severity to medium and high
local appSREOverwrites = function(prometheusAlerts, namespace) {
  local dashboardID = function(name) {
    id:
      if
        name == 'thanos-querier.rules' then '98fde97ddeaf2981041745f1f2ba68c2'
      else if
        name == 'thanos-compact.rules' then '651943d05a8123e32867b4673963f42b'
      else if
        name == 'thanos-receive.rules' then '916a852b00ccc5ed81056644718fa4fb'
      else if
        name == 'thanos-store.rules' then 'e832e8f26403d95fac0ea1c59837588b'
      else if
        name == 'thanos-receive-controller.rules' then 'no-dashboard'
      else if
        name == 'thanos-component-absent' then 'no-dashboard'
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

    local alerts = thanos + thanosReceiveController {
      _config+:: {
        thanosQuerierJobPrefix: 'thanos-querier',
        thanosStoreJobPrefix: 'thanos-store',
        thanosReceiveJobPrefix: 'thanos-receive',
        thanosCompactJobPrefix: 'thanos-compactor',
        thanosReceiveControllerJobPrefix: 'thanos-receive-controller',

        thanosQuerierSelector: 'job=~"%s.*", namespace="%s"' % [self.thanosQuerierJobPrefix, namespace],
        thanosStoreSelector: 'job=~"%s.*", namespace="%s"' % [self.thanosStoreJobPrefix, namespace],
        thanosReceiveSelector: 'job=~"%s.*", namespace="%s"' % [self.thanosReceiveJobPrefix, namespace],
        thanosCompactSelector: 'job=~"%s.*", namespace="%s"' % [self.thanosCompactJobPrefix, namespace],
        thanosReceiveControllerSelector: 'job=~"%s.*",namespace="%s"' % [self.thanosReceiveControllerJobPrefix, namespace],
      },

      prometheusAlerts+:: {
        groups:
          std.filter(
            function(ruleGroup) ruleGroup.name != 'thanos-sidecar.rules',
            super.groups,
          ),
      },
    } + {
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
    local alerts = thanos + thanosReceiveController {
      _config+:: {
        thanosQuerierJobPrefix: 'thanos-querier',
        thanosStoreJobPrefix: 'thanos-store',
        thanosReceiveJobPrefix: 'thanos-receive',
        thanosCompactJobPrefix: 'thanos-compactor',
        thanosReceiveControllerJobPrefix: 'thanos-receive-controller',

        thanosQuerierSelector: 'job=~"%s.*",namespace="%s"' % [self.thanosQuerierJobPrefix, namespace],
        thanosStoreSelector: 'job=~"%s.*",namespace="%s"' % [self.thanosStoreJobPrefix, namespace],
        thanosReceiveSelector: 'job=~"%s.*",namespace="%s"' % [self.thanosReceiveJobPrefix, namespace],
        thanosCompactSelector: 'job=~"%s.*",namespace="%s"' % [self.thanosCompactJobPrefix, namespace],
        thanosReceiveControllerSelector: 'job=~"%s.*",namespace="%s"' % [self.thanosReceiveControllerJobPrefix, namespace],
      },

      prometheusAlerts+:: {
        groups:
          std.filter(
            function(ruleGroup) ruleGroup.name != 'thanos-sidecar.rules',
            super.groups,
          ),
      },
    } + {
      prometheusAlerts+:: appSREOverwrites(super.prometheusAlerts, namespace),
    },

    spec: alerts.prometheusAlerts,
  },
}
