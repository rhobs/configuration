local config = (import '../config.libsonnet').thanos;
local utils = import 'github.com/thanos-io/thanos/mixin/lib/utils.libsonnet';
local g = import 'github.com/thanos-io/thanos/mixin/lib/thanos-grafana-builder/builder.libsonnet';
local template = import 'grafonnet/template.libsonnet';

function() {

  local thanos = self,
  local intervalTemplate =
    template.interval(
      'interval',
      '5m,10m,30m,1h,6h,12h,auto',
      label='interval',
      current='5m',
    ),
  local namespaceTemplate =
    template.new(
      name='namespace',
      datasource='$datasource',
      query='label_values(thanos_status, namespace)',
      label='namespace',
      allValues='.+',
      current='',
      hide='',
      refresh=2,
      includeAll=true,
      sort=1
    ),

  queryFrontend:: {
    selector: error 'must provide selector for Thanos Query Frontend dashboard',
    title: error 'must provide title for Thanos Query Frontend dashboard',
    dashboard:: {
      title: config.queryFrontend.title,
      selector: std.join(', ', config.dashboard.selector + ['job=~"observatorium-thanos-query-frontend"']),
      dimensions: std.join(', ', config.dashboard.dimensions + ['job']),
      pod: 'observatorium-thanos-query-frontend.*',
    },
  },

  local queryFrontendHandlerSelector = utils.joinLabels([thanos.queryFrontend.dashboard.selector, 'handler="query-frontend"']),
  local queryFrontendOpSelector = utils.joinLabels([thanos.queryFrontend.dashboard.selector, 'op=~".*"']),
  dashboard:: {
    data:
      g.dashboard('RHOBS Instance Utilization Overview')
      .addRow(
        g.row('Query Frontend Overview')
        .addPanel(
          g.panel('Rate of requests', 'Shows rate of requests against Query Frontend for the given time.') +
          g.httpQpsPanel('http_requests_total', queryFrontendHandlerSelector, thanos.queryFrontend.dashboard.dimensions) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { gridPos: { x: 0, y: 1, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Rate of queries', 'Shows rate of queries passing through Query Frontend') +
          g.httpQpsPanel('thanos_query_frontend_queries_total', queryFrontendOpSelector, thanos.queryFrontend.dashboard.dimensions + ',op') +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { gridPos: { x: 6, y: 1, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Errors', 'Shows ratio of errors compared to the total number of handled requests against Query Frontend.') +
          g.httpErrPanel('http_requests_total', queryFrontendHandlerSelector, thanos.queryFrontend.dashboard.dimensions) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { gridPos: { x: 12, y: 1, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Duration', 'Shows how long has it taken to handle requests in quantiles.') +
          g.latencyPanel('http_request_duration_seconds', queryFrontendHandlerSelector, thanos.queryFrontend.dashboard.dimensions) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { gridPos: { x: 18, y: 1, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Memory Used') +
          g.queryPanel(
            [
              '(container_memory_working_set_bytes{container="thanos-query-frontend", namespace="$namespace"}) / (1024 * 1024)',
            ],
            [
              'memory usage system {{pod}}',
            ]
          ) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { yaxes: g.yaxes('MB'), gridPos: { x: 0, y: 7, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel(
            [
              'rate(process_cpu_seconds_total{job="observatorium-thanos-query-frontend", namespace="$namespace"}[$interval]) * 100',
            ],
            [
              'cpu usage system {{instance}}',
            ]
          ) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { yaxes: g.yaxes('percent'), gridPos: { x: 6, y: 7, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Pod/Container Restarts') +
          g.queryPanel(
            [
              'increase(kube_pod_container_status_restarts_total{namespace="$namespace", container=\'thanos-query-frontend\'}[$interval])',
            ],
            [
              'pod {{instance}}',
            ]
          ) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { yaxes: g.yaxes('count'), gridPos: { x: 12, y: 7, w: 6, h: 6 } }
        )
      ) + {
        templating+: {
          list+: [namespaceTemplate, intervalTemplate],
        },
      },
  },
  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    name: 'grafana-dashboard-rhobs-instance-utlization',
  },
  data: {
    'rhobs-instance-utlization-overview.json': std.manifestJsonEx(thanos.dashboard.data, ' '),
  },
}
