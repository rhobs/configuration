local thanos =
  (import 'thanos-mixin/dashboards/querier.libsonnet') +
  (import 'thanos-mixin/dashboards/store.libsonnet') +
  (import 'thanos-mixin/dashboards/receiver.libsonnet') +
  (import 'thanos-mixin/dashboards/ruler.libsonnet') +
  (import 'thanos-mixin/dashboards/compactor.libsonnet') +
  (import 'thanos-mixin/dashboards/overview.libsonnet') +
  (import 'thanos-mixin/dashboards/defaults.libsonnet');

local selectors = import 'selectors.libsonnet';

local thanosReceiveController = (import 'thanos-receive-controller-mixin/mixin.libsonnet');
local jaeger = (import 'jaeger-mixin/mixin.libsonnet');
local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

local dashboards = (thanos + selectors).grafanaDashboards;

local thanosReceiveDashboards = thanosReceiveController {
  _config+:: {
    thanosReceiveJobPrefix: 'thanos-receive',
    thanosReceiveControllerJobPrefix: 'thanos-receive-controller',

    thanosReceiveSelector: 'job=~"%s.*"' % self.thanosReceiveJobPrefix,
    thanosReceiveControllerSelector: 'job=~"%s.*"' % self.thanosReceiveControllerJobPrefix,
  },
}.grafanaDashboards;

{
  ['grafana-dashboard-observatorium-thanos-%s.configmap' % std.split(name, '.')[0]]:
    local configmap = k.core.v1.configMap;
    configmap.new() +
    configmap.mixin.metadata.withName('grafana-dashboard-observatorium-thanos-%s' % std.split(name, '.')[0]) +
    configmap.withData({
      [name]: std.manifestJsonEx(dashboards[name] { tags: std.uniq(super.tags + ['observatorium']) }, '  '),
    })
  for name in std.objectFields(dashboards)
} + {
  ['grafana-dashboard-observatorium-thanos-%s.configmap' % std.split(name, '.')[0]]:
    local configmap = k.core.v1.configMap;
    configmap.new() +
    configmap.mixin.metadata.withName('grafana-dashboard-observatorium-thanos-%s' % std.split(name, '.')[0]) +
    configmap.withData({
      [name]: std.manifestJsonEx(thanosReceiveDashboards[name] { tags: std.uniq(super.tags + ['observatorium']) }, '  '),
    })
  for name in std.objectFields(thanosReceiveDashboards)
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
