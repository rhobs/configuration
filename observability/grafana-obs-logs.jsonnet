local cfg = (import 'config.libsonnet');
local loki = (import 'github.com/grafana/loki/production/loki-mixin/mixin.libsonnet') + cfg.loki;

local dashboards = {
  ['grafana-dashboard-observatorium-logs-%s.configmap' % std.split(name, '.')[0]]: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'grafana-dashboard-observatorium-logs-%s' % std.split(name, '.')[0],
    },
    data: {
      [name]: std.manifestJsonEx(loki.grafanaDashboards[name], '  '),
    },
  }
  for name in std.objectFields(loki.grafanaDashboards)
  if name != 'loki-logs.json'
} + {
  'grafana-dashboard-observatorium-api-logs.configmap': (import 'dashboards/observatorium-api-logs.libsonnet')('${OBSERVATORIUM_API_DATASOURCE}', '${OBSERVATORIUM_API_NAMESPACE}'),
  'grafana-dashboard-observatorium-logs-loki-overview.configmap': (import 'observatorium-logs/loki-overview.libsonnet')('${OBSERVATORIUM_API_DATASOURCE}', '${OBSERVATORIUM_API_NAMESPACE}'),
};

local dashboardsTemplate = {
  apiVersion: 'template.openshift.io/v1',
  kind: 'Template',
  metadata: {
    name: 'observatorium-logs-dahboards-templates',
  },
  objects: [
    dashboards[name] {
      metadata+: {
        labels+: {
          grafana_dashboard: 'true',
        },
        annotations+: {
          'grafana-folder': '/grafana-dashboard-definitions/Observatorium',
        },
      },
    }
    for name in std.objectFields(dashboards)
  ],
  parameters: [
    { name: 'OBSERVATORIUM_API_DATASOURCE', value: 'telemeter-prod-01-prometheus' },
    { name: 'OBSERVATORIUM_API_NAMESPACE', value: 'observatorium-mst-production' },
    { name: 'OBSERVATORIUM_DATASOURCE_REGEX', value: '(app-sre-stage-01|rhobs-testing|rhobsp02ue1|telemeter-prod-01)-prometheus' },
    { name: 'OBSERVATORIUM_NAMESPACE_OPTIONS', value: 'observatorium-logs-testing,observatorium-mst-stage,observatorium-mst-production' },
  ],
};

local recordingRulesTemplate = {
  apiVersion: 'template.openshift.io/v1',
  kind: 'Template',
  metadata: {
    name: 'observatorium-logs-dahboards-rules-templates',
  },
  objects: [
    {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'PrometheusRule',
      metadata: {
        name: 'observatorium-logs-recording-rules',
        labels: {
          prometheus: 'app-sre',
          role: 'recording-rules',
        },
      },
      spec: loki.prometheusRules,
    },
  ],
  parameters: [],
};

{
  'grafana-dashboards-template': dashboardsTemplate,
  'grafana-dashboards-rules-template': recordingRulesTemplate,
}
