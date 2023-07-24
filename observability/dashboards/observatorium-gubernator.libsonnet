// local am = (import '../config.libsonnet').alertmanager;
// local utils = import 'github.com/thanos-io/thanos/mixin/lib/utils.libsonnet';
local g = import 'github.com/grafana/jsonnet-libs/grafana-builder/grafana.libsonnet';
local grafana = import 'grafonnet/grafana.libsonnet';
local template = import 'grafonnet/template.libsonnet';

function() {

  local gubernator = self,
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
      query='label_values(up{namespace="$namespace", job="observatorium-gubernator"}, job)',
      label='job',
      allValues='.+',
      current='',
      hide='',
      refresh=2,
      includeAll=true,
      sort=1
    ),

  // Requests status/count
  // gubernator_grpc_request_counts
  // gubernator_grpc_request_duration
  // gubernator_over_limit_counter
  // Request Latencies
  // gubernator_async_durations
  // gubernator_asyncrequest_retries
  // gubernator_broadcast_durations
  // Gube Cache Status
  // gubernator_cache_access_count
  // gubernator_cache_size
  // gubernator_check_counter
  // gubernator_check_error_counter
  // gubernator_concurrent_checks_counter
  // gubernator_pool_queue_length
  // gubernator_queue_length

  dashboard:: {
    data:
      g.dashboard('Observatorium / Gubernator')
      .addRow(
        g.row('gRPC Requests GetRateLimits')
        .addPanel(
          g.panel('Rate of requests') { span: 0 } +
          g.queryPanel(
            [
              'rate(gubernator_grpc_request_counts{namespace="$namespace", job="$job", method=".*/GetRateLimits"}[$interval])',
            ],
            [
              '{{pod}}',
            ]
          ) +
          g.stack
        )
        .addPanel(
          g.panel('Rate of errors') { span: 0 } +
          g.queryPanel(
            [
              'rate(gubernator_grpc_request_counts{namespace="$namespace", job="$job", method=".*/GetRateLimits", status="failed"}[$interval])',
            ],
            [
              '{{pod}}',
            ]
          ) +
          g.stack
        .addPanel(
          g.panel('Latencies') { span: 0 } +
          g.queryPanel(
            [
              'gubernator_grpc_request_duration{namespace="$namespace", job="$job", method=".*/GetRateLimits", status="success"}[$interval])',
            ],
            [
              '{{pod}}',
            ]
          ) +
          g.stack
        )
      ) + {
        templating+: {
          list+: [
            if variable.name == 'datasource'
            then variable { regex: '/^rhobs.*|telemeter-prod-01-prometheus|app-sre-stage-01-prometheus/' }
            else variable
            for variable in super.list
          ] + [namespaceTemplate, jobTemplate, intervalTemplate],
        },
      },
  },
  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    name: 'grafana-dashboard-obervatorium-gubernator',
  },
  data: {
    'rhobs-instance-obervatorium-gubernator.json': std.manifestJsonEx($.dashboard.data, ' '),
  },
}
