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
  local instanceTemplate =
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
      selector: std.join(', ', config.dashboard.selector + ['job=~"observatorium-thanos-query-frontend"']),
      dimensions: std.join(', ', config.dashboard.dimensions + ['job']),
      pod: 'observatorium-thanos-query-frontend.*',
    },
  },

  local queryFrontendHandlerSelector = utils.joinLabels([thanos.queryFrontend.dashboard.selector, 'handler="query-frontend"']),
  local queryFrontendOpSelector = utils.joinLabels([thanos.queryFrontend.dashboard.selector, 'op="query_range"']),
  dashboard:: {
    data:
      g.dashboard('RHOBS Instance Utilization Overview')
      .addRow(
        g.row('Query Frontend Overview')
        .addPanel(
          g.panel('Rate of requests', 'Shows rate of requests against Query Frontend for the given time.') +
          g.httpQpsPanel('http_requests_total', queryFrontendHandlerSelector, thanos.queryFrontend.dashboard.dimensions) +
          { gridPos: { x: 0, y: 1, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Rate of queries', 'Shows rate of queries passing through Query Frontend') +
          g.httpQpsPanel('thanos_query_frontend_queries_total', queryFrontendOpSelector, thanos.queryFrontend.dashboard.dimensions) +
          { gridPos: { x: 6, y: 1, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Errors', 'Shows ratio of errors compared to the total number of handled requests against Query Frontend.') +
          g.httpErrPanel('http_requests_total', queryFrontendHandlerSelector, thanos.queryFrontend.dashboard.dimensions) +
          { gridPos: { x: 12, y: 1, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Duration', 'Shows how long has it taken to handle requests in quantiles.') +
          g.latencyPanel('http_request_duration_seconds', queryFrontendHandlerSelector, thanos.queryFrontend.dashboard.dimensions) +
          { gridPos: { x: 18, y: 1, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Memory Used') +
          g.queryPanel(
            [
              'go_memstats_alloc_bytes{%s}' % thanos.queryFrontend.dashboard.selector,
              'go_memstats_heap_alloc_bytes{%s}' % thanos.queryFrontend.dashboard.selector,
              'rate(go_memstats_alloc_bytes_total{%s}[30s])' % thanos.queryFrontend.dashboard.selector,
              'rate(go_memstats_heap_alloc_bytes{%s}[30s])' % thanos.queryFrontend.dashboard.selector,
              'go_memstats_stack_inuse_bytes{%s}' % thanos.queryFrontend.dashboard.selector,
              'go_memstats_heap_inuse_bytes{%s}' % thanos.queryFrontend.dashboard.selector,
            ],
            [
              'alloc all {{instance}}',
              'alloc heap {{instance}}',
              'alloc rate all {{instance}}',
              'alloc rate heap {{instance}}',
              'inuse heap {{instance}}',
              'inuse stack {{instance}}',
            ]
          ) +
          { yaxes: g.yaxes('bytes'), gridPos: { x: 0, y: 7, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel(
            [
              'rate(process_cpu_seconds_total{job="observatorium-thanos-query-frontend", namespace="$namespace"}[5m]) * 100',
            ],
            [
              'cpu usage system {{instance}}',
            ]
          ) +
          { yaxes: g.yaxes('percent'), gridPos: { x: 6, y: 7, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Pod/Container Restarts') +
          g.queryPanel(
            [
              'kube_pod_container_status_restarts_total{namespace="$namespace", container=\'thanos-query-frontend\'}',
            ],
            [
              'pod {{pod}}',
            ]
          ) +
          { yaxes: g.yaxes('count'), gridPos: { x: 12, y: 7, w: 6, h: 6 } }
        )
      ) + {
        templating+: {
          list+: [instanceTemplate, intervalTemplate],
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
