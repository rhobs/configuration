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
  local jobTemplate =
    template.new(
      name='job',
      datasource='$datasource',
      query='label_values(up{namespace="$namespace", job=~"observatorium-thanos-.*|observatorium-ruler-query.*"}, job)',
      label='job',
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
      selector: std.join(', ', config.dashboard.selector + ['job=~"$job"']),
      dimensions: std.join(', ', config.dashboard.dimensions + ['job']),
      pod: 'observatorium-thanos-query-frontend.*',
    },
  },
  local queryFrontendHandlerSelector = utils.joinLabels([thanos.queryFrontend.dashboard.selector, 'handler="query-frontend"']),

  rule:: {
    yStart: 8,
    selector: error 'must provide selector for Thanos Rule dashboard',
    title: error 'must provide title for Thanos Rule dashboard',
    dashboard:: {
      title: config.rule.title,
      selector: std.join(', ', config.dashboard.selector + ['job=~"$job"']),
      dimensions: std.join(', ', config.dashboard.dimensions + ['job']),
      pod: 'observatorium-thanos-rule.*',
      container: 'thanos-rule',
    },
  },

  receive:: {
    selector: error 'must provide selector for Thanos Receive dashboard',
    title: error 'must provide title for Thanos Receive dashboard',
    dashboard:: {
      title: config.receive.title,
      selector: std.join(', ', config.dashboard.selector + ['job=~"$job"']),
      dimensions: std.join(', ', config.dashboard.dimensions + ['job']),
      pod: 'observatorium-thanos-receive.*',
    },
  },
  local receiveHandlerSelector = utils.joinLabels([thanos.receive.dashboard.selector, 'handler="receive"']),

  store+:: {
    selector: error 'must provide selector for Thanos Store dashboard',
    title: error 'must provide title for Thanos Store dashboard',
    dashboard:: {
      title: config.store.title,
      selector: std.join(', ', config.dashboard.selector + ['job=~"$job"']),
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
              'sum by (pod) (rate(container_network_receive_bytes_total{namespace="$namespace", pod=~"observatorium-thanos-receive-.*"}[$interval]))',
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
              '(container_memory_working_set_bytes{container="thanos-query-frontend", namespace="$namespace"})',
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
              'rate(container_network_receive_bytes_total{namespace="$namespace", pod=~"observatorium-thanos-query-frontend-.*"}[$interval])',
              'rate(container_network_transmit_bytes_total{namespace="$namespace", pod=~"observatorium-thanos-query-frontend-.*"}[$interval])',
            ],
            [
              'receive bytes pod {{pod}}',
              'transmit bytes pod {{pod}}',
            ]
          ) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { yaxes: g.yaxes('binBps') }
        )
      )
      .addRow(
        g.row('Thanos Rule Overview')
        // First line (y=1): evaluations metrics
        .addPanel(
          g.panel('Total evaluations', 'Displays the rate of total rule evaluations,') +
          g.queryPanel(
            'sum by (job, rule_group) (rate(prometheus_rule_evaluations_total{%(selector)s}[$interval]))' % thanos.rule.dashboard,
            '{{rule_group}}'
          ) +
          g.addDashboardLink(thanos.rule.dashboard.title) +
          { gridPos: { x: 0, y: thanos.rule.yStart + 1, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Failed evaluations', 'Displays the rate of rule evaluation failures, grouped by rule group.') +
          g.queryPanel(
            'sum by (job, rule_group) (rate(prometheus_rule_evaluation_failures_total{%(selector)s}[$interval]))' % thanos.rule.dashboard,
            '{{rule_group}}'
          ) +
          g.addDashboardLink(thanos.rule.dashboard.title) +
          { gridPos: { x: 6, y: thanos.rule.yStart + 1, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Evaluations with warnings') +
          g.queryPanel(
            'sum by (job, strategy) (rate(thanos_rule_evaluation_with_warnings_total{%(selector)s}[$interval]))' % thanos.rule.dashboard,
            '{{rule_group}}'
          ) +
          g.addDashboardLink(thanos.rule.dashboard.title) +
          { gridPos: { x: 12, y: thanos.rule.yStart + 1, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Too slow evaluations', 'Displays the total time of rule group evaluations that took longer than their scheduled interval.') +
          g.addDashboardLink(thanos.rule.dashboard.title) +
          g.queryPanel(
            'sum by(job, rule_group) (prometheus_rule_group_last_duration_seconds{%(selector)s}) / sum by(job, rule_group) (prometheus_rule_group_interval_seconds{%(selector)s})' % thanos.rule.dashboard,
            '{{rule_group}}'
          ) +
          { gridPos: { x: 18, y: thanos.rule.yStart + 1, w: 6, h: 6 } },
        )
        // Second line (y=7): alerts push to aler manager metrics
        .addPanel(
          g.panel('Rate of sent alerts', 'Shows the rate of total alerts sent by Thanos.') +
          g.queryPanel('sum by (job) (rate(thanos_alert_sender_alerts_sent_total{%(selector)s}[$interval]))' % thanos.rule.dashboard, '{{job}}') +
          g.addDashboardLink(thanos.rule.dashboard.title) +
          { gridPos: { x: 0, y: thanos.rule.yStart + 7, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Rate of send alerts errors', 'Displays the ratio of error rate to total alerts sent rate by Thanos.') +
          g.queryPanel(
            'sum by (job) (rate(thanos_alert_sender_errors_total{%(selector)s}[$interval])) / sum by (job) (rate(thanos_alert_sender_alerts_sent_total{%(selector)s}[$interval]))' % thanos.rule.dashboard,
            '{{job}}'
          ) +
          g.addDashboardLink(thanos.rule.dashboard.title) +
          { gridPos: { x: 6, y: thanos.rule.yStart + 7, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Duration od send alerts', 'Displays the 50th, 90th, and 99th percentile latency of alert requests sent by Thanos.') +
          g.queryPanel(
            [
              'histogram_quantile(0.50, sum by (job, le) (rate(thanos_alert_sender_latency_seconds_bucket{%(selector)s}[$interval])))' % thanos.rule.dashboard,
              'histogram_quantile(0.90, sum by (job, le) (rate(thanos_alert_sender_latency_seconds_bucket{%(selector)s}[$interval])))' % thanos.rule.dashboard,
              'histogram_quantile(0.99, sum by (job, le) (rate(thanos_alert_sender_latency_seconds_bucket{%(selector)s}[$interval])))' % thanos.rule.dashboard,
            ],
            [
              'p50',
              'p90',
              'p99',
            ]
          ) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { gridPos: { x: 12, y: thanos.rule.yStart + 7, w: 6, h: 6 } },
        )
        // Third line (y=13): CPU, memory, network resource usage and restarts
        .addPanel(
          g.panel('Memory Used') +
          g.queryPanel(
            [
              '(container_memory_working_set_bytes{container="thanos-rule", namespace="$namespace"}) / (1024 * 1024)',
            ],
            [
              'memory usage system {{pod}}',
            ]
          ) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { yaxes: g.yaxes('MB'), gridPos: { x: 0, y: thanos.rule.yStart + 13, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel(
            [
              'rate(process_cpu_seconds_total{%(selector)s}[$interval]) * 100' % thanos.rule.dashboard,
            ],
            [
              'cpu usage system {{pod}}',
            ]
          ) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { yaxes: g.yaxes('percent'), gridPos: { x: 6, y: thanos.rule.yStart + 13, w: 6, h: 6 } },
        )
        .addPanel(
          g.panel('Network Usage') +
          g.queryPanel(
            [
              'rate(container_network_receive_bytes_total{namespace="$namespace", pod=~"%(pod)s"}[$interval]) / (1024 * 1024)' % thanos.rule.dashboard,
              'rate(container_network_transmit_bytes_total{namespace="$namespace", pod=~"%(pod)s"}[$interval]) / (1024 * 1024)' % thanos.rule.dashboard,
            ],
            [
              'receive bytes pod {{pod}}',
              'transmit bytes pod {{pod}}',
            ]
          ) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { yaxes: g.yaxes('MB'), gridPos: { x: 12, y: thanos.rule.yStart + 13, w: 6, h: 6 } }
        )
        .addPanel(
          g.panel('Pod/Container Restarts') +
          g.queryPanel(
            [
              'increase(kube_pod_container_status_restarts_total{namespace="$namespace", container="%(container)s"}[$interval])' % thanos.rule.dashboard,
            ],
            [
              'pod {{pod}}',
            ]
          ) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { yaxes: g.yaxes('count'), gridPos: { x: 18, y: thanos.rule.yStart + 13, w: 6, h: 6 } }
        )
      )
      .addRow(
        g.row('Store Gateway Overview')
        .addPanel(
          g.panel('Unary gRPC Rate', 'Shows rate of handled Unary gRPC requests from queriers.') +
          g.grpcRequestsPanel('grpc_server_handled_total', grpcUnarySelector, thanos.store.dashboard.dimensions) +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Unary gRPC Errors', 'Shows ratio of errors compared to the total number of handled requests from queriers.') +
          g.grpcErrorsPanel('grpc_server_handled_total', grpcUnarySelector, thanos.store.dashboard.dimensions) +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Unary gRPC Duration', 'Shows how long has it taken to handle requests from queriers, in quantiles.') +
          g.latencyPanel('grpc_server_handling_seconds', grpcUnarySelector, thanos.store.dashboard.dimensions) +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Sreamed gRPC Rate', 'Shows rate of handled Streamed gRPC requests from queriers.') +
          g.grpcRequestsPanel('grpc_server_handled_total', grpcServerStreamSelector, thanos.store.dashboard.dimensions) +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Sreamed gRPC Errors', 'Shows ratio of errors compared to the total number of handled requests from queriers.') +
          g.grpcErrorsPanel('grpc_server_handled_total', grpcServerStreamSelector, thanos.store.dashboard.dimensions) +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Sreamed gRPC Duration', 'Shows how long has it taken to handle requests from queriers, in quantiles.') +
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
          g.latencyPanel('thanos_bucket_store_series_merge_duration_seconds', thanos.store.dashboard.selector, thanos.store.dashboard.dimensions) +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Memory Used', 'Memory working set') +
          g.queryPanel(
            [
              '(container_memory_working_set_bytes{container="thanos-store", namespace="$namespace"})',
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
              'rate(process_cpu_seconds_total{job=~"observatorium-thanos-store-.*", namespace="$namespace"}[$interval]) * 100',
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
              'sum by (pod) (kube_pod_container_status_restarts_total{namespace="$namespace", container="thanos-store"})',
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
              'sum by (pod) (rate(container_network_receive_bytes_total{namespace="$namespace", pod=~"observatorium-thanos-store-.*"}[$interval]))',
              'sum by (pod) (rate(container_network_transmit_bytes_total{namespace="$namespace", pod=~"observatorium-thanos-store-.*"}[$interval]))',
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
      ) + {
        templating+: {
          list+: [namespaceTemplate, jobTemplate, intervalTemplate],
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
