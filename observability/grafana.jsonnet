local config = (import 'config.libsonnet');

local thanos =
  (import 'github.com/thanos-io/thanos/mixin/dashboards/query.libsonnet') +
  (import 'github.com/thanos-io/thanos/mixin/dashboards/store.libsonnet') +
  (import 'github.com/thanos-io/thanos/mixin/dashboards/receive.libsonnet') +
  (import 'github.com/thanos-io/thanos/mixin/dashboards/rule.libsonnet') +
  (import 'github.com/thanos-io/thanos/mixin/dashboards/compact.libsonnet') +
  (import 'github.com/thanos-io/thanos/mixin/dashboards/overview.libsonnet') +
  (import 'github.com/thanos-io/thanos/mixin/dashboards/defaults.libsonnet') +
  (import 'github.com/observatorium/thanos-receive-controller/jsonnet/thanos-receive-controller-mixin/mixin.libsonnet') +
  config.thanos;

local jaeger = (import 'github.com/jaegertracing/jaeger/monitoring/jaeger-mixin/mixin.libsonnet');
local memcached = (import 'github.com/grafana/jsonnet-libs/memcached-mixin/mixin.libsonnet');

local obsDatasource = 'telemeter-prod-01-prometheus';
local obsNamespace = 'telemeter-production';

local dashboards =
  {
    ['grafana-dashboard-observatorium-thanos-%s.configmap' % std.split(name, '.')[0]]: {
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata: {
        name: 'grafana-dashboard-observatorium-thanos-%s' % std.split(name, '.')[0],
      },
      data: {
        [name]: std.manifestJsonEx(thanos.grafanaDashboards[name] { tags: std.uniq(super.tags + ['observatorium']) }, '  '),
      },
    }
    for name in std.objectFields(thanos.grafanaDashboards)
  } +
  {
    ['grafana-dashboard-observatorium-jaeger-%s.configmap' % std.split(name, '.')[0]]: {
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata: {
        name: 'grafana-dashboard-observatorium-jaeger-%s' % std.split(name, '.')[0],
      },
      data: {
        [name]: std.manifestJsonEx(jaeger.grafanaDashboards[name] { tags: std.uniq(super.tags + ['observatorium']) }, '  '),
      },
    }
    for name in std.objectFields(jaeger.grafanaDashboards)
  } +
  {
    ['grafana-dashboard-observatorium-memcached-%s.configmap' % std.split(name, '.')[0]]: {
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata: {
        name: 'grafana-dashboard-observatorium-memcached-%s' % std.split(name, '.')[0],
      },
      data: {
        [name]: std.manifestJsonEx(memcached.grafanaDashboards[name] { tags: std.uniq(super.tags + ['observatorium']) }, '  '),
      },
    }
    for name in std.objectFields(memcached.grafanaDashboards)
  } +
  { 'grafana-dashboard-observatorium-api.configmap': (import 'dashboards/observatorium-api.libsonnet')(obsDatasource, obsNamespace) } +
  { 'grafana-dashboard-telemeter-canary.configmap': (import 'dashboards/telemeter-canary.libsonnet')(obsDatasource, obsNamespace) } +
  { 'grafana-dashboard-telemeter.configmap': (import 'dashboards/telemeter.libsonnet')(obsDatasource, obsNamespace) };

{
  [name]: dashboards[name] {
    metadata+: {
      labels+: { grafana_dashboard: 'true' },
      annotations+: {
        'grafana-folder': '/grafana-dashboard-definitions/Observatorium',
      },
    },
  }
  for name in std.objectFields(dashboards)
}
