local config = (import '../config.libsonnet').thanos;
local am = (import '../config.libsonnet').alertmanager;
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
    dashboard:: {
      title: config.queryFrontend.title,
      selector: std.join(', ', config.dashboard.selector + ['job=~"$job"']),
      dimensions: std.join(', ', config.dashboard.dimensions + ['job']),
      pod: 'observatorium-thanos-query-frontend.*',
      container: 'thanos-query-frontend',
    },
  },
  local queryFrontendHandlerSelector = utils.joinLabels([thanos.queryFrontend.dashboard.selector, 'handler="query-frontend"']),

  query:: {
    dashboard:: {
      title: config.query.title,
      selector: std.join(', ', config.dashboard.selector + ['job=~"$job"']),
      dimensions: std.join(', ', config.dashboard.dimensions + ['job']),
      queryPod: 'observatorium-thanos-query.*',
      rulerQueryPod: 'observatorium-ruler-query.*',
      container: 'thanos-query',
    },
  },
  local queryHandlerSelector = utils.joinLabels([thanos.query.dashboard.selector, 'handler="query"']),
  local queryRangeHandlerSelector = utils.joinLabels([thanos.query.dashboard.selector, 'handler="query_range"']),

  rule:: {
    yStart: 8,
    dashboard:: {
      title: config.rule.title,
      selector: std.join(', ', config.dashboard.selector + ['job=~"$job"']),
      dimensions: std.join(', ', config.dashboard.dimensions + ['job']),
      pod: 'observatorium-thanos-rule.*',
      container: 'thanos-rule',
    },
  },

  receive:: {
    dashboard:: {
      title: config.receive.title,
      selector: std.join(', ', config.dashboard.selector + ['job=~"$job"']),
      dimensions: std.join(', ', config.dashboard.dimensions + ['job']),
      pod: 'observatorium-thanos-receive.*',
      container: 'thanos-receive',
    },
  },
  local receiveHandlerSelector = utils.joinLabels([thanos.receive.dashboard.selector, 'handler="receive"']),

  store:: {
    dashboard:: {
      title: config.store.title,
      selector: std.join(', ', config.dashboard.selector + ['job=~"$job"']),
      dimensions: std.join(', ', config.dashboard.dimensions + ['job']),
      pod: 'observatorium-thanos-store.*',
      container: 'thanos-store',
    },
  },
  local grpcUnarySelector = utils.joinLabels([thanos.store.dashboard.selector, 'grpc_type="unary"']),
  local grpcServerStreamSelector = utils.joinLabels([thanos.store.dashboard.selector, 'grpc_type="server_stream"']),
  local dataSizeDimensions = utils.joinLabels([thanos.store.dashboard.dimensions, 'data_type']),

  gubernator:: {
    dashboard:: {
      title: 'Observatorium - Gubernator',
      selector: std.join(', ', config.dashboard.selector + ['job=~"$job"']),
      dimensions: std.join(', ', config.dashboard.dimensions + ['job']),
      pod: 'observatorium-gubernator.*',
      container: 'gubernator',
    },
  },

  alertmanager:: {
    dashboard:: {
      selector: std.join(', ', config.dashboard.selector + ['job=~"$job"']),
      dimensions: std.join(', ', config.dashboard.dimensions + ['job']),
      pod: 'observatorium-alertmanager.*',
      container: 'observatorium-alertmanager',
    },
  },

  local memoryUsagePanel(container, pod) =
    g.panel('Memory Used', 'Memory working set') { span:: 0 } +
    g.queryPanel(
      [
        '(container_memory_working_set_bytes{container="%s", pod=~"%s", namespace="$namespace"})' % [
          container,
          pod,
        ],
      ],
      [
        'memory usage system {{pod}}',
      ]
    ) { span:: 0 },

  local cpuUsagePanel(container, pod) =
    g.panel('CPU Usage') { span:: 0 } +
    g.queryPanel(
      [
        'rate(process_cpu_seconds_total{container="%s", pod=~"%s", namespace="$namespace"}[$interval]) * 100' % [
          container,
          pod,
        ],
      ],
      [
        'cpu usage system {{pod}}',
      ]
    ) { span:: 0 },

  local podRestartPanel(container, pod) =
    g.panel('Pod/Container Restarts') { span:: 0 } +
    g.queryPanel(
      [
        'sum by (pod) (kube_pod_container_status_restarts_total{container="%s", pod=~"%s", namespace="$namespace",})' % [
          container,
          pod,
        ],
      ],
      [
        'pod restart count {{pod}}',
      ]
    ) { span:: 0 },

  local networkUsagePanel(pod) =
    g.panel('Network Usage') { span:: 0 } +
    g.queryPanel(
      [
        'sum by (pod) (rate(container_network_receive_bytes_total{pod=~"%s", namespace="$namespace"}[$interval]))' % pod,
        'sum by (pod) (rate(container_network_transmit_bytes_total{pod=~"%s", namespace="$namespace"}[$interval]))' % pod,
      ],
      [
        'network traffic in {{pod}}',
        'network traffic out {{pod}}',
      ]
    ) { span:: 0 },

  dashboard:: {
    data:
      g.dashboard('RHOBS Instance Utilization Overview')
      .addRow(
        g.row('Receive Overview')
        .addPanel(
          g.panel('Rate of requests', 'Shows rate of requests against Receive for the given time') { span:: 0 } +
          g.httpQpsPanel('http_requests_total', receiveHandlerSelector, thanos.receive.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.receive.dashboard.title) +
          g.stack
        )
        .addPanel(
          g.panel('Errors', 'Shows ratio of errors compared to the total number of handled requests against Receive.') { span:: 0 } +
          g.httpErrPanel('http_requests_total', receiveHandlerSelector, thanos.receive.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.receive.dashboard.title)
        )
        .addPanel(
          g.panel('Duration', 'Shows how long has it taken to handle requests in quantiles.') +
          g.latencyPanel('http_request_duration_seconds', receiveHandlerSelector, thanos.receive.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.receive.dashboard.title)
        )
        .addPanel(
          g.panel('Replication request count', 'Shows the number of replication requests against Receive.') { span:: 0 } +
          g.grpcRequestsPanel('grpc_client_handled_total', 'grpc_type="unary", grpc_method="RemoteWrite"', thanos.receive.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.receive.dashboard.title) +
          g.stack
        )
        .addPanel(
          g.panel('Replication request duration', 'Shows how long has it taken to handle replication requests in quantiles.') { span:: 0 } +
          g.latencyPanel('grpc_client_handling_seconds', 'grpc_type="unary", grpc_method="RemoteWrite"', thanos.receive.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.receive.dashboard.title)
        )
        .addPanel(
          g.panel('Replication request errors', 'Shows the number of replication request errors.') { span:: 0 } +
          g.grpcErrorsPanel('grpc_client_handled_total', 'grpc_type="unary", grpc_method="RemoteWrite"', thanos.receive.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.receive.dashboard.title)
        )
        .addPanel(
          g.panel('Concurrency gate utilization') { span:: 0 } +
          g.queryPanel(
            [
              'max by (pod) (http_inflight_requests{handler="receive", namespace="$namespace"})',
              'max by (pod) (thanos_receive_write_request_concurrency_write_request_limit{namespace="$namespace"})',
            ],
            [
              'concurrency gate used {{pod}}',
              'concurrency gate limit {{pod}}',
            ]
          ) { span:: 0 } +
          g.addDashboardLink(thanos.receive.dashboard.title)
        )
        .addPanel(
          memoryUsagePanel(thanos.receive.dashboard.container, thanos.receive.dashboard.pod) +
          g.addDashboardLink(thanos.receive.dashboard.title) +
          { yaxes: g.yaxes('bytes') } +
          g.stack
        )
        .addPanel(
          cpuUsagePanel(thanos.receive.dashboard.container, thanos.receive.dashboard.pod) +
          g.addDashboardLink(thanos.receive.dashboard.title)
        )
        .addPanel(
          podRestartPanel(thanos.receive.dashboard.container, thanos.receive.dashboard.pod) +
          g.addDashboardLink(thanos.receive.dashboard.title)
        )
        .addPanel(
          networkUsagePanel(thanos.receive.dashboard.pod) +
          g.stack +
          g.addDashboardLink(thanos.receive.dashboard.title) +
          { yaxes: g.yaxes('binBps') }
        ) { collapse: true }
      )
      .addRow(
        g.row('Query Frontend Overview')
        .addPanel(
          g.panel('Rate of requests', 'Shows rate of requests against Query Frontend for the given time.') { span:: 0 } +
          g.httpQpsPanel('http_requests_total', queryFrontendHandlerSelector, thanos.queryFrontend.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          g.stack
        )
        .addPanel(
          g.panel('Errors', 'Shows ratio of errors compared to the total number of handled requests against Query Frontend.') { span:: 0 } +
          g.httpErrPanel('http_requests_total', queryFrontendHandlerSelector, thanos.queryFrontend.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title)
        )
        .addPanel(
          g.panel('Duration', 'Shows how long has it taken to handle requests in quantiles.') { span:: 0 } +
          g.latencyPanel('http_request_duration_seconds', queryFrontendHandlerSelector, thanos.queryFrontend.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title)
        )
        .addPanel(
          memoryUsagePanel(thanos.queryFrontend.dashboard.container, thanos.queryFrontend.dashboard.pod) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { yaxes: g.yaxes('bytes') } +
          g.stack
        )
        .addPanel(
          cpuUsagePanel(thanos.queryFrontend.dashboard.container, thanos.queryFrontend.dashboard.pod) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title)
        )
        .addPanel(
          podRestartPanel(thanos.queryFrontend.dashboard.container, thanos.queryFrontend.dashboard.pod) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title)
        )
        .addPanel(
          networkUsagePanel(thanos.queryFrontend.dashboard.pod) +
          g.addDashboardLink(thanos.queryFrontend.dashboard.title) +
          { yaxes: g.yaxes('binBps') }
        ) { collapse: true }
      )
      .addRow(
        g.row('Query Overview')
        .addPanel(
          g.panel('Instant Query Rate', 'Shows rate of requests against /query for the given time.') { span:: 0 } +
          g.httpQpsPanel('http_requests_total', queryHandlerSelector, thanos.query.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.query.dashboard.title)
        )
        .addPanel(
          g.panel('Instant Query Errors', 'Shows ratio of errors compared to the total number of handled requests against /query.') { span:: 0 } +
          g.httpErrPanel('http_requests_total', queryHandlerSelector, thanos.query.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.query.dashboard.title)
        )
        .addPanel(
          g.panel('Instant Query Duration', 'Shows how long has it taken to handle requests in quantiles.') { span:: 0 } +
          g.latencyPanel('http_request_duration_seconds', queryHandlerSelector, thanos.query.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.query.dashboard.title)
        )
        .addPanel(
          g.panel('Range Query Rate', 'Shows rate of requests against /query_range for the given time range.') { span:: 0 } +
          g.httpQpsPanel('http_requests_total', queryRangeHandlerSelector, thanos.query.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.query.dashboard.title)
        )
        .addPanel(
          g.panel('Range Query Errors', 'Shows ratio of errors compared to the total number of handled requests against /query_range.') { span:: 0 } +
          g.httpErrPanel('http_requests_total', queryRangeHandlerSelector, thanos.query.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.query.dashboard.title)
        )
        .addPanel(
          g.panel('Range Query Duration', 'Shows how long has it taken to handle requests in quantiles.') { span:: 0 } +
          g.latencyPanel('http_request_duration_seconds', queryRangeHandlerSelector, thanos.query.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.query.dashboard.title)
        )
        .addPanel(
          g.panel('Concurrent Capacity', 'Shows available capacity of processing queries in parallel.') { span:: 0 } +
          g.queryPanel(
            'max_over_time(thanos_query_concurrent_gate_queries_max{%s}[$__rate_interval]) - avg_over_time(thanos_query_concurrent_gate_queries_in_flight{%s}[$__rate_interval])' % [thanos.query.dashboard.selector, thanos.query.dashboard.selector],
            '{{job}} - {{pod}}'
          ) { span:: 0 }
        )
        .addPanel(
          memoryUsagePanel(thanos.query.dashboard.container, thanos.query.dashboard.queryPod) +
          g.addDashboardLink(thanos.query.dashboard.title) +
          { yaxes: g.yaxes('bytes') } +
          g.stack
        )
        .addPanel(
          cpuUsagePanel(thanos.query.dashboard.container, thanos.query.dashboard.queryPod) +
          g.addDashboardLink(thanos.query.dashboard.title)
        )
        .addPanel(
          podRestartPanel(thanos.query.dashboard.container, thanos.query.dashboard.queryPod) +
          g.addDashboardLink(thanos.query.dashboard.title)
        )
        .addPanel(
          networkUsagePanel(thanos.query.dashboard.queryPod) +
          g.stack +
          g.addDashboardLink(thanos.query.dashboard.title) +
          { yaxes: g.yaxes('binBps') }
        ) { collapse: true }
      )
      .addRow(
        g.row('Ruler - Query Overview')
        .addPanel(
          g.panel('Instant Query Rate', 'Shows rate of requests against /query for the given time.') { span:: 0 } +
          g.httpQpsPanel('http_requests_total', queryHandlerSelector, thanos.query.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.query.dashboard.title)
        )
        .addPanel(
          g.panel('Instant Query Errors', 'Shows ratio of errors compared to the total number of handled requests against /query.') { span:: 0 } +
          g.httpErrPanel('http_requests_total', queryHandlerSelector, thanos.query.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.query.dashboard.title)
        )
        .addPanel(
          g.panel('Instant Query Duration', 'Shows how long has it taken to handle requests in quantiles.') { span:: 0 } +
          g.latencyPanel('http_request_duration_seconds', queryHandlerSelector, thanos.query.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.query.dashboard.title)
        )
        .addPanel(
          g.panel('Range Query Rate', 'Shows rate of requests against /query_range for the given time range.') { span:: 0 } +
          g.httpQpsPanel('http_requests_total', queryRangeHandlerSelector, thanos.query.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.query.dashboard.title)
        )
        .addPanel(
          g.panel('Range Query Errors', 'Shows ratio of errors compared to the total number of handled requests against /query_range.') { span:: 0 } +
          g.httpErrPanel('http_requests_total', queryRangeHandlerSelector, thanos.query.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.query.dashboard.title)
        )
        .addPanel(
          g.panel('Range Query Duration', 'Shows how long has it taken to handle requests in quantiles.') { span:: 0 } +
          g.latencyPanel('http_request_duration_seconds', queryRangeHandlerSelector, thanos.query.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.query.dashboard.title)
        )
        .addPanel(
          g.panel('Concurrent Capacity', 'Shows available capacity of processing queries in parallel.') { span:: 0 } +
          g.queryPanel(
            'max_over_time(thanos_query_concurrent_gate_queries_max{%s}[$__rate_interval]) - avg_over_time(thanos_query_concurrent_gate_queries_in_flight{%s}[$__rate_interval])' % [thanos.query.dashboard.selector, thanos.query.dashboard.selector],
            '{{job}} - {{pod}}'
          ) { span:: 0 }
        )
        .addPanel(
          memoryUsagePanel(thanos.query.dashboard.container, thanos.query.dashboard.rulerQueryPod) +
          g.addDashboardLink(thanos.query.dashboard.title) +
          { yaxes: g.yaxes('bytes') } +
          g.stack
        )
        .addPanel(
          cpuUsagePanel(thanos.query.dashboard.container, thanos.query.dashboard.rulerQueryPod) +
          g.addDashboardLink(thanos.query.dashboard.title)
        )
        .addPanel(
          podRestartPanel(thanos.query.dashboard.container, thanos.query.dashboard.rulerQueryPod) +
          g.addDashboardLink(thanos.query.dashboard.title)
        )
        .addPanel(
          networkUsagePanel(thanos.query.dashboard.rulerQueryPod) +
          g.stack +
          g.addDashboardLink(thanos.query.dashboard.title) +
          { yaxes: g.yaxes('binBps') }
        ) { collapse: true }
      )
      .addRow(
        g.row('Thanos Rule Overview')
        // First line (y=1): evaluations metrics
        .addPanel(
          g.panel('Total evaluations', 'Displays the rate of total rule evaluations,') { span:: 0 } +
          g.queryPanel(
            'sum by (job, rule_group) (rate(prometheus_rule_evaluations_total{%(selector)s}[$interval]))' % thanos.rule.dashboard,
            '{{rule_group}}'
          ) { span:: 0 } +
          g.addDashboardLink(thanos.rule.dashboard.title)
        )
        .addPanel(
          g.panel('Failed evaluations', 'Displays the rate of rule evaluation failures, grouped by rule group.') { span:: 0 } +
          g.queryPanel(
            'sum by (job, rule_group) (rate(prometheus_rule_evaluation_failures_total{%(selector)s}[$interval]))' % thanos.rule.dashboard,
            '{{rule_group}}'
          ) { span:: 0 } +
          g.addDashboardLink(thanos.rule.dashboard.title)
        )
        .addPanel(
          g.panel('Evaluations with warnings') { span:: 0 } +
          g.queryPanel(
            'sum by (job, strategy) (rate(thanos_rule_evaluation_with_warnings_total{%(selector)s}[$interval]))' % thanos.rule.dashboard,
            '{{rule_group}}'
          ) { span:: 0 } +
          g.addDashboardLink(thanos.rule.dashboard.title)
        )
        .addPanel(
          g.panel('Too slow evaluations', 'Displays the total time of rule group evaluations that took longer than their scheduled interval.') { span:: 0 } +
          g.addDashboardLink(thanos.rule.dashboard.title) +
          g.queryPanel(
            'sum by(job, rule_group) (prometheus_rule_group_last_duration_seconds{%(selector)s}) / sum by(job, rule_group) (prometheus_rule_group_interval_seconds{%(selector)s})' % thanos.rule.dashboard,
            '{{rule_group}}'
          ) { span:: 0 }
        )
        // Second line (y=7): alerts push to aler manager metrics
        .addPanel(
          g.panel('Rate of sent alerts', 'Shows the rate of total alerts sent by Thanos.') { span:: 0 } +
          g.queryPanel('sum by (job) (rate(thanos_alert_sender_alerts_sent_total{%(selector)s}[$interval]))' % thanos.rule.dashboard, '{{job}}') { span:: 0 } +
          g.addDashboardLink(thanos.rule.dashboard.title)
        )
        .addPanel(
          g.panel('Rate of send alerts errors', 'Displays the ratio of error rate to total alerts sent rate by Thanos.') { span:: 0 } +
          g.queryPanel(
            'sum by (job) (rate(thanos_alert_sender_errors_total{%(selector)s}[$interval])) / sum by (job) (rate(thanos_alert_sender_alerts_sent_total{%(selector)s}[$interval]))' % thanos.rule.dashboard,
            '{{job}}'
          ) { span:: 0 } +
          g.addDashboardLink(thanos.rule.dashboard.title)
        )
        .addPanel(
          g.panel('Duration od send alerts', 'Displays the 50th, 90th, and 99th percentile latency of alert requests sent by Thanos.') { span:: 0 } +
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
          ) { span:: 0 } +
          g.addDashboardLink(thanos.rule.dashboard.title)
        )
        // Third line (y=13): CPU, memory, network resource usage and restarts
        .addPanel(
          memoryUsagePanel(thanos.rule.dashboard.container, thanos.rule.dashboard.pod) +
          g.addDashboardLink(thanos.rule.dashboard.title) +
          { yaxes: g.yaxes('MB') },
        )
        .addPanel(
          cpuUsagePanel(thanos.rule.dashboard.container, thanos.rule.dashboard.pod) +
          g.addDashboardLink(thanos.rule.dashboard.title) +
          { yaxes: g.yaxes('percent') },
        )
        .addPanel(
          networkUsagePanel(thanos.rule.dashboard.pod) +
          g.addDashboardLink(thanos.rule.dashboard.title) +
          { yaxes: g.yaxes('MB') }
        )
        .addPanel(
          podRestartPanel(thanos.rule.dashboard.container, thanos.rule.dashboard.pod) +
          g.addDashboardLink(thanos.rule.dashboard.title) +
          { yaxes: g.yaxes('count') }
        ) { collapse: true }
      )
      .addRow(
        g.row('Store Gateway Overview')
        .addPanel(
          g.panel('Unary gRPC Rate', 'Shows rate of handled Unary gRPC requests from queriers.') { span:: 0 } +
          g.grpcRequestsPanel('grpc_server_handled_total', grpcUnarySelector, thanos.store.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Unary gRPC Errors', 'Shows ratio of errors compared to the total number of handled requests from queriers.') { span:: 0 } +
          g.grpcErrorsPanel('grpc_server_handled_total', grpcUnarySelector, thanos.store.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Unary gRPC Duration', 'Shows how long has it taken to handle requests from queriers, in quantiles.') { span:: 0 } +
          g.latencyPanel('grpc_server_handling_seconds', grpcUnarySelector, thanos.store.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Sreamed gRPC Rate', 'Shows rate of handled Streamed gRPC requests from queriers.') { span:: 0 } +
          g.grpcRequestsPanel('grpc_server_handled_total', grpcServerStreamSelector, thanos.store.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Sreamed gRPC Errors', 'Shows ratio of errors compared to the total number of handled requests from queriers.') { span:: 0 } +
          g.grpcErrorsPanel('grpc_server_handled_total', grpcServerStreamSelector, thanos.store.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Sreamed gRPC Duration', 'Shows how long has it taken to handle requests from queriers, in quantiles.') { span:: 0 } +
          g.latencyPanel('grpc_server_handling_seconds', grpcServerStreamSelector, thanos.store.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Data Touched', 'Show the size of data touched') { span:: 0 } +
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
          ) { span:: 0 } +
          { yaxes: g.yaxes('bytes') }
        )
        .addPanel(
          g.panel('Get All', 'Shows how long has it taken to get all series.') { span:: 0 } +
          g.latencyPanel('thanos_bucket_store_series_get_all_duration_seconds', thanos.store.dashboard.selector, thanos.store.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          g.panel('Merge', 'Shows how long has it taken to merge series.') { span:: 0 } +
          g.latencyPanel('thanos_bucket_store_series_merge_duration_seconds', thanos.store.dashboard.selector, thanos.store.dashboard.dimensions) { span:: 0 } +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          memoryUsagePanel(thanos.store.dashboard.container, thanos.store.dashboard.pod) +
          g.addDashboardLink(thanos.store.dashboard.title) +
          { yaxes: g.yaxes('bytes') } +
          g.stack
        )
        .addPanel(
          cpuUsagePanel(thanos.store.dashboard.container, thanos.store.dashboard.pod) +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          podRestartPanel(thanos.store.dashboard.container, thanos.store.dashboard.pod) +
          g.addDashboardLink(thanos.store.dashboard.title)
        )
        .addPanel(
          networkUsagePanel(thanos.store.dashboard.pod) +
          g.stack +
          g.addDashboardLink(thanos.store.dashboard.title) +
          { yaxes: g.yaxes('binBps') }
        ) { collapse: true }
      )
      .addRow(
        g.row('Gubernator Overview')
        .addPanel(
          g.panel('Rate of gRPC requests', 'Shows count of gRPC requests to gubernator') { span:: 0 } +
          g.queryPanel(
            [
              'sum(rate(gubernator_grpc_request_counts{namespace="$namespace",job=~"$job"}[$__rate_interval])) by (namespace,job,pod)',
            ],
            [
              'gRPC requests {{pod}}',
            ]
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Rate of errors in gRPC requests', 'Shows count of errors in gRPC requests to gubernator') { span:: 0 } +
          g.queryPanel(
            [
              'sum(rate(gubernator_grpc_request_counts{status="failed",namespace="$namespace",job=~"$job"}[$__rate_interval])) by (namespace,job,pod)',
            ],
            [
              'gRPC request errors {{pod}}',
            ]
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Duration of gRPC requests', 'Shows duration of gRPC requests to gubernator') { span:: 0 } +
          g.queryPanel(
            [
              'gubernator_grpc_request_duration{quantile="0.99", namespace="$namespace",job=~"$job"}',
              'gubernator_grpc_request_duration{quantile="0.5", namespace="$namespace",job=~"$job"}',
            ],
            [
              'P99: {{pod}}',
              'P50: {{pod}}',
            ]
          ) +
          { yaxes: g.yaxes('s') },
        )
        .addPanel(
          g.panel('Local queue of rate checks', 'Shows the number of rate checks in the local queue') { span:: 0 } +
          g.queryPanel(
            [
              'gubernator_pool_queue_length{namespace="$namespace",job=~"$job"}',
            ],
            [
              'local queue size {{pod}}',
            ]
          )
        )
        .addPanel(
          g.panel('Peer queue of rate checks', 'Shows the number of rate checks in the peer queue') { span:: 0 } +
          g.queryPanel(
            [
              'gubernator_queue_length{namespace="$namespace",job=~"$job"}',
            ],
            [
              'peer queue size {{pod}}',
            ]
          )
        )
        .addPanel(
          memoryUsagePanel(thanos.gubernator.dashboard.container, thanos.gubernator.dashboard.pod) +
          { yaxes: g.yaxes('bytes') } +
          g.stack
        )
        .addPanel(
          cpuUsagePanel(thanos.gubernator.dashboard.container, thanos.gubernator.dashboard.pod)
        )
        .addPanel(
          podRestartPanel(thanos.gubernator.dashboard.container, thanos.gubernator.dashboard.pod)
        )
        .addPanel(
          networkUsagePanel(thanos.gubernator.dashboard.pod) +
          g.stack +
          { yaxes: g.yaxes('binBps') }
        ) { collapse: true }
      )
      .addRow(
        g.row('Alertmanager Overview')
        .addPanel(
          g.panel('Alerts receive rate', 'rate of successful and invalid alerts received by the Alertmanager') { span:: 0 } +
          g.queryPanel(
            [
              'sum(rate(alertmanager_alerts_received_total{namespace=~"$namespace",job=~"$job"}[$__rate_interval])) by (namespace,job,pod)',
              'sum(rate(alertmanager_alerts_invalid_total{namespace=~"$namespace",job=~"$job"}[$__rate_interval])) by (namespace,job,pod)',
            ],
            [
              'alerts received {{pod}}',
              'alerts invalid {{pod}}',
            ]
          ) { span:: 0 } +
          g.addDashboardLink(am.title)
        )
        .addPanel(
          memoryUsagePanel(thanos.alertmanager.dashboard.container, thanos.alertmanager.dashboard.pod) +
          g.addDashboardLink(am.title) +
          { yaxes: g.yaxes('bytes') } +
          g.stack
        )
        .addPanel(
          cpuUsagePanel(thanos.alertmanager.dashboard.container, thanos.alertmanager.dashboard.pod) +
          g.addDashboardLink(am.title)
        )
        .addPanel(
          podRestartPanel(thanos.alertmanager.dashboard.container, thanos.alertmanager.dashboard.pod) +
          g.addDashboardLink(am.title)
        )
        .addPanel(
          networkUsagePanel(thanos.alertmanager.dashboard.pod) +
          g.stack +
          g.addDashboardLink(am.title) +
          { yaxes: g.yaxes('binBps') }
        ) { collapse: true }
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
