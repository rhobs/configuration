local config = (import 'config.libsonnet');
local loki = (import 'github.com/grafana/loki/production/loki-mixin/mixin.libsonnet') + config.loki;

local obsDatasource = 'telemeter-prod-01-prometheus';
local obsNamespace = 'observatorium-mst-production';

local dashboardUIDs = {
  'loki-chunks.json': 'GtCujSHzC8gd9i5fck9a3v9n2EvTzA',
  'loki-logs.json': 'nEhbhXRHDQQBSSWMt9WCpkwyxbwpu4',
  'loki-operational.json': 'E2CAJBcLcg3NNfd2jLKe4fhQpf2LaU',
  'loki-reads.json': '62q5jjYwhVSaz4Mcrm8tV3My3gcKED',
  'loki-writes.json': 'F6nRYKuXmFVpVSFQmXr7cgXy5j7UNr',
};

local dashboards = {
  ['grafana-dashboard-observatorium-logs-%s.configmap' % std.split(name, '.')[0]]: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'grafana-dashboard-observatorium-logs-%s' % std.split(name, '.')[0],
    },
    data: {
      [name]: std.manifestJsonEx(loki.grafanaDashboards[name] {
        tags: std.uniq(super.tags + ['observatorium', 'observatorium-logs']),
        uid: dashboardUIDs[name],
      }, '  '),
    },
  }
  for name in std.objectFields(loki.grafanaDashboards)
} + {
  'grafana-dashboard-observatorium-api-logs.configmap': (import 'dashboards/observatorium-api-logs.libsonnet')(obsDatasource, obsNamespace),
  'grafana-dashboard-observatorium-logs-loki-overview.configmap': (import 'observatorium-logs/loki-overview.libsonnet')(obsDatasource, obsNamespace),
};

{
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
    { name: 'OBSERVATORIUM_LOGS_NAMESPACE', value: 'observatorium-mst-production' },
  ],
}
