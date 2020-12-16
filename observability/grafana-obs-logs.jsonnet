local selectors = (import 'selectors.libsonnet');
local loki = (import 'github.com/grafana/loki/production/loki-mixin/mixin.libsonnet') + selectors.loki;

local obsDatasource = 'telemeter-prod-01-prometheus';
local obsNamespace = 'telemeter-production';

local dashboards = {
  ['grafana-dashboard-observatorium-logs-%s.configmap' % std.split(name, '.')[0]]: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'grafana-dashboard-observatorium-logs-%s' % std.split(name, '.')[0],
    },
    data: {
      [name]: std.manifestJsonEx(loki.grafanaDashboards[name] { tags: std.uniq(super.tags + ['observatorium', 'observatorium-logs']) }, '  '),
    },
  }
  for name in std.objectFields(loki.grafanaDashboards)
} + {
  'grafana-dashboard-observatorium-api-logs.configmap': (import 'dashboards/observatorium-api-logs.libsonnet')(obsDatasource, obsNamespace),
  'grafana-dashboard-observatorium-logs-loki-overview.configmap': (import 'observatorium-logs/loki-overview.libsonnet')(obsDatasource, obsNamespace),
};

{
  apiVersion: 'v1',
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
    { name: 'OBSERVATORIUM_API_NAMESPACE', value: 'telemeter-production' },
    { name: 'OBSERVATORIUM_LOGS_NAMESPACE', value: 'observatorium-logs-production' },
  ],
}
