local config = (import '../config.libsonnet').thanos;
local utils = import 'github.com/thanos-io/thanos/mixin/lib/utils.libsonnet';
local g = import 'github.com/thanos-io/thanos/mixin/lib/thanos-grafana-builder/builder.libsonnet';
local grafana = import 'grafonnet/grafana.libsonnet';


function() {

  local thanos = self,

  local intervalTemplate =
    grafana.template.interval(
      'interval',
      '5m,10m,30m,1h,6h,12h,auto',
      label='interval',
      current='5m',
    ),
  local namespaceTemplate =
    grafana.template.new(
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

  local memoryUsedPanel(container) =
    g.panel('Memory Used') +
    g.queryPanel(
      [
        '(container_memory_working_set_bytes{container=' + container + ', namespace="$namespace"}) / (1024 * 1024)',
      ],
      [
        'memory usage system {{pod}}',
      ]
    ),
  local cpuUsagePanel(container) =
    g.panel('CPU Usage') +
    g.queryPanel(
      [
        'rate(process_cpu_seconds_total{container=' + container + ', namespace="$namespace"}[$interval]) * 100',
      ],
      [
        'cpu usage system {{pod}}',
      ]
    ),
  local containerRestartsPanel(container) =
    g.panel('Pod/Container Restarts') +
    g.queryPanel(
      [
        'increase(kube_pod_container_status_restarts_total{container=' + container + ', namespace="$namespace", }[$interval])',
      ],
      [
        'pod restarts {{pod}}',
      ]
    ),
  local networkUsagePanel(container) =
    g.panel('Network Usage') +
    g.queryPanel(
      [
        'rate(container_network_receive_bytes_total{namespace="$namespace", pod=~"observatorium-' + container + '-.*"}[$interval]) / (1024 * 1024)',
        'rate(container_network_transmit_bytes_total{namespace="$namespace", pod=~"observatorium-' + container + '-.*"}[$interval]) / (1024 * 1024)',
      ],
      [
        'receive bytes pod {{pod}}',
        'transmit bytes pod {{pod}}',
      ]
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

  store+:: {
    selector: error 'must provide selector for Thanos Store dashboard',
    title: error 'must provide title for Thanos Store dashboard',
    dashboard:: {
      title: config.store.title,
      selector: std.join(', ', config.dashboard.selector + ['job=~"observatorium-thanos-store.*"']),
      dimensions: std.join(', ', config.dashboard.dimensions + ['job']),
    },
  },
  local grpcUnarySelector = utils.joinLabels([thanos.store.dashboard.selector, 'grpc_type="unary"']),
  local grpcServerStreamSelector = utils.joinLabels([thanos.store.dashboard.selector, 'grpc_type="server_stream"']),
  local dataSizeDimensions = utils.joinLabels([thanos.store.dashboard.dimensions, 'data_type']),

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
          g.panel('Errors', 'Shows ratio of errors compared to the total number of handled requests against Query Frontend.') +
          g.httpErrPanel('http_requests_total', queryFrontendHandlerSelector, thanos.queryFrontend.dashboard.dimensions) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { gridPos: { x: 6, y: 1, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Duration', 'Shows how long has it taken to handle requests in quantiles.') +
          g.latencyPanel('http_request_duration_seconds', queryFrontendHandlerSelector, thanos.queryFrontend.dashboard.dimensions) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { gridPos: { x: 12, y: 1, w: 6, h: 6 } },
        )
        .addPanel(
          memoryUsedPanel('thanos-query-frontend') +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { yaxes: g.yaxes('MB'), gridPos: { x: 18, y: 1, w: 6, h: 6 } },
        )
        .addPanel(
          cpuUsagePanel('thanos-query-frontend') +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { yaxes: g.yaxes('percent'), gridPos: { x: 0, y: 7, w: 6, h: 6 } },
        )
        .addPanel(
          containerRestartsPanel('thanos-query-frontend') +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { yaxes: g.yaxes('count'), gridPos: { x: 6, y: 7, w: 6, h: 6 } }
        )
        .addPanel(
          networkUsagePanel('thanos-query-frontend') +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { yaxes: g.yaxes('MB'), gridPos: { x: 12, y: 7, w: 6, h: 6 } }
        )
        + { gridPos: { x: 0, y: 0, w: 24, h: 1 } },
      )
      .addRow(
        g.row('Store Gateway Overview')
        .addPanel(
          g.panel('Rate', 'Shows rate of handled Unary gRPC requests from queriers.') +
          g.grpcRequestsPanel('grpc_server_handled_total', grpcUnarySelector, thanos.store.dashboard.dimensions) +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Errors', 'Shows ratio of errors compared to the total number of handled requests from queriers.') +
          g.grpcErrorsPanel('grpc_server_handled_total', grpcUnarySelector, thanos.store.dashboard.dimensions) +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Duration', 'Shows how long has it taken to handle requests from queriers, in quantiles.') +
          g.latencyPanel('grpc_server_handling_seconds', grpcUnarySelector, thanos.store.dashboard.dimensions) +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Rate', 'Shows rate of handled Streamed gRPC requests from queriers.') +
          g.grpcRequestsPanel('grpc_server_handled_total', grpcServerStreamSelector, thanos.store.dashboard.dimensions) +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Errors', 'Shows ratio of errors compared to the total number of handled requests from queriers.') +
          g.grpcErrorsPanel('grpc_server_handled_total', grpcServerStreamSelector, thanos.store.dashboard.dimensions) +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Duration', 'Shows how long has it taken to handle requests from queriers, in quantiles.') +
          g.latencyPanel('grpc_server_handling_seconds', grpcServerStreamSelector, thanos.store.dashboard.dimensions) +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Data Touched', 'Show the size of data touched') +
          g.queryPanel(
            [
              'histogram_quantile(0.99, sum by (le) (rate(thanos_bucket_store_series_data_touched{%s}[$__rate_interval])))' % thanos.store.dashboard.selector,
              'sum by (%s) (rate(thanos_bucket_store_series_data_touched_sum{%s}[$__rate_interval])) / sum by (%s) (rate(thanos_bucket_store_series_data_touched_count{%s}[$__rate_interval]))' % [dataSizeDimensions, thanos.store.dashboard.selector, dataSizeDimensions, thanos.store.dashboard.selector],
              'histogram_quantile(0.50, sum by (le) (rate(thanos_bucket_store_series_data_touched{%s}[$__rate_interval])))' % thanos.store.dashboard.selector,
            ], [
              'P99: {{data_type}} / {{job}}',
              'mean: {{data_type}} / {{job}}',
              'P50: {{data_type}} / {{job}}',
            ],
          ) +
          { yaxes: g.yaxes('bytes') }
        )
        .addPanel(
          g.panel('Get All', 'Shows how long has it taken to get all series.') +
          g.latencyPanel('thanos_bucket_store_series_get_all_duration_seconds', thanos.store.dashboard.selector, thanos.store.dashboard.dimensions) +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Merge', 'Shows how long has it taken to merge series.') +
          g.latencyPanel('thanos_bucket_store_series_merge_duration_seconds', thanos.store.dashboard.selector, thanos.store.dashboard.dimensions)
        )
        .addPanel(
          memoryUsedPanel('thanos-store') +
          g.addDashboardLink(thanos.store.dashboard.title) +
          { yaxes: g.yaxes('MB') },
        )
        .addPanel(
          cpuUsagePanel('thanos-store') +
          g.addDashboardLink(thanos.store.dashboard.title) +
          { yaxes: g.yaxes('percent') },
        )
        .addPanel(
          containerRestartsPanel('thanos-store') +
          g.addDashboardLink(thanos.store.dashboard.title) +
          { yaxes: g.yaxes('count') }
        )
        .addPanel(
          networkUsagePanel('thanos-store') +
          g.addDashboardLink(thanos.store.dashboard.title) +
          { yaxes: g.yaxes('MB') }
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
