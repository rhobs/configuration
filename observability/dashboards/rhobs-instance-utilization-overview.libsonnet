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

  receive:: {
    selector: error 'must provide selector for Thanos Receive dashboard',
    title: error 'must provide title for Thanos Receive dashboard',
    dashboard:: {
      title: config.receive.title,
      selector: std.join(', ', config.dashboard.selector + ['job=~"observatorium-thanos-receive.*"']),
      dimensions: std.join(', ', config.dashboard.dimensions + ['job']),
      pod: 'observatorium-thanos-receive.*',
    },
  },
  local receiveHandlerSelector = utils.joinLabels([thanos.receive.dashboard.selector, 'handler="receive"']),

  dashboard:: {
    data:
      g.dashboard('RHOBS Instance Utilization Overview')
      .addRow(
        g.row('Receive Overview')
        .addPanel(
          g.panel('Rate of requests', 'Shows rate of requests against Receive for the given time') +
          g.httpQpsPanel('http_requests_total', receiveHandlerSelector, thanos.receive.dashboard.dimensions) +
          g.addDashboardLink(thanos.receive.dashboard.title) +
          g.stack
        )
        .addPanel(
          g.panel('Errors', 'Shows ratio of errors compared to the total number of handled requests against Receive.') +
          g.httpErrPanel('http_requests_total', receiveHandlerSelector, thanos.receive.dashboard.dimensions) +
          g.addDashboardLink(thanos.receive.dashboard.title)
        )
        .addPanel(
          g.panel('Duration', 'Shows how long has it taken to handle requests in quantiles.') +
          g.latencyPanel('http_request_duration_seconds', receiveHandlerSelector, thanos.receive.dashboard.dimensions) +
          g.addDashboardLink(thanos.receive.dashboard.title)
        )
        .addPanel(
          g.panel('Replication request count', 'Shows the number of replication requests against Receive.') +
          g.grpcRequestsPanel('grpc_client_handled_total', 'grpc_type="unary", grpc_method="RemoteWrite"', thanos.receive.dashboard.dimensions) +
          g.addDashboardLink(thanos.receive.dashboard.title) +
          g.stack
        )
        .addPanel(
          g.panel('Replication request duration', 'Shows how long has it taken to handle replication requests in quantiles.') +
          g.latencyPanel('grpc_client_handling_seconds', 'grpc_type="unary", grpc_method="RemoteWrite"', thanos.receive.dashboard.dimensions) +
          g.addDashboardLink(thanos.receive.dashboard.title)
        )
        .addPanel(
          g.panel('Replication request errors', 'Shows the number of replication request errors.') +
          g.grpcErrorsPanel('grpc_client_handled_total', 'grpc_type="unary", grpc_method="RemoteWrite"', thanos.receive.dashboard.dimensions) +
          g.addDashboardLink(thanos.receive.dashboard.title)
        )
        .addPanel(
          g.panel('Concurrency gate utilization') +
          g.queryPanel(
            [
              'max by (pod) (http_inflight_requests{handler="receive", namespace="$namespace"})',
              'max by (pod) (thanos_receive_write_request_concurrency_write_request_limit{namespace="$namespace"})',
            ],
            [
              'concurrency gate used {{pod}}',
              'concurrency gate limit {{pod}}',
            ]
          ) +
          g.addDashboardLink(thanos.receive.dashboard.title)
        )
        .addPanel(
          g.panel('Memory Used', 'Memory working set') +
          g.queryPanel(
            [
              '(container_memory_working_set_bytes{container="thanos-receive", namespace="$namespace"})',
            ],
            [
              'memory usage system {{pod}}',
            ]
          ) +
          g.addDashboardLink(thanos.receive.dashboard.title) +
          { yaxes: g.yaxes('bytes') } +
          g.stack
        )
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel(
            [
              'rate(process_cpu_seconds_total{job="observatorium-thanos-receive-default", namespace="$namespace"}[$interval]) * 100',
            ],
            [
              'cpu usage system {{pod}}',
            ]
          ) +
          g.addDashboardLink(thanos.receive.dashboard.title)
        )
        .addPanel(
          g.panel('Pod/Container Restarts') +
          g.queryPanel(
            [
              'sum by (pod) (kube_pod_container_status_restarts_total{namespace="$namespace", container="thanos-receive"})',
            ],
            [
              'pod restart count {{pod}}',
            ]
          ) +
          g.addDashboardLink(thanos.receive.dashboard.title)
        )
        .addPanel(
          g.panel('Network Traffic') +
          g.queryPanel(
            [
              'sum by (pod) (rate(container_network_receive_bytes_total{namespace="$namespace", pod=~"observatorium-thanos-receive-.*"}[$interval])) * -1',
              'sum by (pod) (rate(container_network_transmit_bytes_total{namespace="$namespace", pod=~"observatorium-thanos-receive-.*"}[$interval]))',
            ],
            [
              'network traffic in {{pod}}',
              'network traffic out {{pod}}',
            ]
          ) +
          g.stack +
          g.addDashboardLink(thanos.receive.dashboard.title) +
          { yaxes: g.yaxes('binBps') }
        )
      )
      .addRow(
        g.row('Query Frontend Overview')
        .addPanel(
          g.panel('Rate of requests', 'Shows rate of requests against Query Frontend for the given time.') +
          g.httpQpsPanel('http_requests_total', queryFrontendHandlerSelector, thanos.queryFrontend.dashboard.dimensions) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          g.stack
        )
        .addPanel(
          g.panel('Errors', 'Shows ratio of errors compared to the total number of handled requests against Query Frontend.') +
          g.httpErrPanel('http_requests_total', queryFrontendHandlerSelector, thanos.queryFrontend.dashboard.dimensions) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title)
        )
        .addPanel(
          g.panel('Duration', 'Shows how long has it taken to handle requests in quantiles.') +
          g.latencyPanel('http_request_duration_seconds', queryFrontendHandlerSelector, thanos.queryFrontend.dashboard.dimensions) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title)
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
          { yaxes: g.yaxes('bytes') } +
          g.stack
        )
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel(
            [
              'rate(process_cpu_seconds_total{job="observatorium-thanos-query-frontend", namespace="$namespace"}[$interval]) * 100',
            ],
            [
              'cpu usage system {{pod}}',
            ]
          ) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title)
        )
        .addPanel(
          g.panel('Pod/Container Restarts') +
          g.queryPanel(
            [
              'increase(kube_pod_container_status_restarts_total{namespace="$namespace", container=\'thanos-query-frontend\'}[$interval])',
            ],
            [
              'pod {{pod}}',
            ]
          ) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title)
        )
        .addPanel(
          g.panel('Network Usage') +
          g.queryPanel(
            [
              'rate(container_network_receive_bytes_total{namespace="$namespace", pod=~"observatorium-thanos-query-frontend-.*"}[$interval]) / (1024 * 1024)',
              'rate(container_network_transmit_bytes_total{namespace="$namespace", pod=~"observatorium-thanos-query-frontend-.*"}[$interval]) / (1024 * 1024)',
            ],
            [
              'receive bytes pod {{pod}}',
              'transmit bytes pod {{pod}}',
            ]
          ) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { yaxes: g.yaxes('binBps') }
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
