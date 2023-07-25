local config = (import 'config.libsonnet');

local thanos =
  (import 'github.com/thanos-io/thanos/mixin/dashboards/query-frontend.libsonnet') +
  (import 'github.com/thanos-io/thanos/mixin/dashboards/query.libsonnet') +
  (import 'github.com/thanos-io/thanos/mixin/dashboards/store.libsonnet') +
  (import 'github.com/thanos-io/thanos/mixin/dashboards/receive.libsonnet') +
  (import 'github.com/thanos-io/thanos/mixin/dashboards/rule.libsonnet') +
  (import 'github.com/thanos-io/thanos/mixin/dashboards/compact.libsonnet') +
  (import 'github.com/thanos-io/thanos/mixin/dashboards/overview.libsonnet') +
  (import 'github.com/thanos-io/thanos/mixin/dashboards/defaults.libsonnet') +
  (import 'github.com/observatorium/thanos-receive-controller/jsonnet/thanos-receive-controller-mixin/mixin.libsonnet') +
  config.thanos;

local memcached = (import 'github.com/grafana/jsonnet-libs/memcached-mixin/mixin.libsonnet');
local alertmanager = (import 'github.com/prometheus/alertmanager/doc/alertmanager-mixin/dashboards/overview.libsonnet') +
                     config.alertmanager;

local obsDatasource = 'telemeter-prod-01-prometheus';
local obsNamespace = 'telemeter-production';
local obsTraces = 'observatorium-traces';

local sanitizeDashboardName(name) = std.strReplace(std.split(name, '.')[0], '_', '-');

local dashboards =
  {
    ['grafana-dashboard-observatorium-thanos-%s.configmap' % sanitizeDashboardName(name)]: {
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata: {
        name: 'grafana-dashboard-observatorium-thanos-%s' % sanitizeDashboardName(name),
      },
      data: {
        [name]: std.manifestJsonEx(thanos.grafanaDashboards[name] { tags: std.uniq(super.tags + ['observatorium']) }, '  '),
      },
    }
    for name in std.objectFields(thanos.grafanaDashboards)
  } +
  {
    ['grafana-dashboard-observatorium-memcached-%s.configmap' % sanitizeDashboardName(name)]: {
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata: {
        name: 'grafana-dashboard-observatorium-memcached-%s' % sanitizeDashboardName(name),
      },
      data: {
        // Replace references to 'cluster' by 'namespace', since we do not have 'cluster' label and use 'namespace' by default.
        [name]: std.strReplace(std.manifestJsonEx(memcached.grafanaDashboards[name] { tags: std.uniq(super.tags + ['observatorium']) }, '  '), 'cluster', 'namespace'),
      },
    }
    for name in std.objectFields(memcached.grafanaDashboards)
  } +
  {
    ['grafana-dashboard-observatorium-%s.configmap' % sanitizeDashboardName(name)]: {
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata: {
        name: 'grafana-dashboard-observatorium-%s' % sanitizeDashboardName(name),
      },
      data: {
        // Replace references to 'cluster' by 'namespace', since we do not have 'cluster' label and use 'namespace' by default.
        [name]: std.strReplace(std.manifestJsonEx(alertmanager.grafanaDashboards[name] { tags: std.uniq(super.tags + ['observatorium']) }, '  '), 'cluster', 'namespace'),
      },
    }
    for name in std.objectFields(alertmanager.grafanaDashboards)
  } +
  { 'grafana-dashboard-observatorium-api.configmap': (import 'dashboards/observatorium-api.libsonnet')(obsDatasource, obsNamespace) } +
  { 'grafana-dashboard-telemeter-canary.configmap': (import 'dashboards/telemeter-canary.libsonnet')(obsDatasource, obsNamespace) } +
  { 'grafana-dashboard-telemeter.configmap': (import 'dashboards/telemeter.libsonnet')(obsDatasource, obsNamespace) } +
  { 'grafana-dashboard-slo-telemeter-production.configmap': (import 'dashboards/slo.libsonnet')('telemeter', 'production', 'Telemeter Production SLOs') } +
  { 'grafana-dashboard-slo-telemeter-stage.configmap': (import 'dashboards/slo.libsonnet')('telemeter', 'stage', 'Telemeter Staging SLOs') } +
  { 'grafana-dashboard-slo-mst-production.configmap': (import 'dashboards/slo.libsonnet')('mst', 'production', 'MST Production SLOs') } +
  { 'grafana-dashboard-slo-rhobsp02ue1-production.configmap': (import 'dashboards/slo.libsonnet')('mst', 'rhobsp02ue1', 'rhobsp02ue1 Production SLOs') } +
  { 'grafana-dashboard-slo-mst-stage.configmap': (import 'dashboards/slo.libsonnet')('mst', 'stage', 'MST Stage SLOs') } +
  { 'grafana-dashboard-tracing-otel.configmap': (import 'dashboards/opentelemetry.libsonnet')(obsDatasource, obsTraces) } +
  { 'grafana-dashboard-tracing-jaeger.configmap': (import 'dashboards/tracing.libsonnet')(obsDatasource, obsTraces) } +
  { 'grafana-dashboard-rhobs-instance-utilization-overview.configmap': (import 'dashboards/rhobs-instance-utilization-overview.libsonnet')() } +
  { 'grafana-dashboard-rules-objstore.configmap': (import 'dashboards/rules-objstore.libsonnet')() };
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
