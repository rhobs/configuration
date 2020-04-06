local obs = (import 'openshift/obs.jsonnet');

local thanos =
  (import 'thanos-mixin/dashboards/query.libsonnet') +
  (import 'thanos-mixin/dashboards/store.libsonnet') +
  (import 'thanos-mixin/dashboards/receive.libsonnet') +
  (import 'thanos-mixin/dashboards/rule.libsonnet') +
  (import 'thanos-mixin/dashboards/compact.libsonnet') +
  (import 'thanos-mixin/dashboards/overview.libsonnet') +
  (import 'thanos-mixin/dashboards/defaults.libsonnet') +
  (import 'thanos-receive-controller-mixin/mixin.libsonnet') +
  (import 'selectors.libsonnet');

local jaeger = (import 'jaeger-mixin/mixin.libsonnet');
local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

{
  ['grafana-dashboard-observatorium-thanos-%s.configmap' % std.split(name, '.')[0]]:
    local configmap = k.core.v1.configMap;
    configmap.new() +
    configmap.mixin.metadata.withName('grafana-dashboard-observatorium-thanos-%s' % std.split(name, '.')[0]) +
    configmap.withData({
      [name]: std.manifestJsonEx(thanos.grafanaDashboards[name] { tags: std.uniq(super.tags + ['observatorium']) }, '  '),
    })
  for name in std.objectFields(thanos.grafanaDashboards)
} + {
  ['grafana-dashboard-observatorium-jaeger-%s.configmap' % std.split(name, '.')[0]]:
    local configmap = k.core.v1.configMap;
    configmap.new() +
    configmap.mixin.metadata.withName('grafana-dashboard-observatorium-jaeger-%s' % std.split(name, '.')[0]) +
    configmap.withData({
      [name]: std.manifestJsonEx(jaeger.grafanaDashboards[name] { tags: std.uniq(super.tags + ['observatorium']) }, '  '),
    })
  for name in std.objectFields(jaeger.grafanaDashboards)
}
