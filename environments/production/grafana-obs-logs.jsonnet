local selectors = (import 'selectors.libsonnet');

local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
local loki = (import 'loki-mixin/mixin.libsonnet') + selectors.loki;

local dashboards = {
  ['grafana-dashboard-observatorium-logs-%s.configmap' % std.split(name, '.')[0]]:
    local configmap = k.core.v1.configMap;
    configmap.new() +
    configmap.mixin.metadata.withName('grafana-dashboard-observatorium-logs-%s' % std.split(name, '.')[0]) +
    configmap.withData({
      [name]: std.manifestJsonEx(loki.grafanaDashboards[name] { tags: std.uniq(super.tags + ['observatorium', 'observatorium-logs']) }, '  '),
    })
  for name in std.objectFields(loki.grafanaDashboards)
};

{
  [name]: dashboards[name] {
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
}
