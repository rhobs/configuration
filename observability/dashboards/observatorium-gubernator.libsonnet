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
  local container = 'gubernator',
  local pod = 'observatorium-gubernator',
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

  local panel(title, description='', unit='reqps') =
    g.panel(title) {
      description: description,
      fieldConfig: {
        defaults: {
          unit: unit,
        },
      },
      span: 0,
    } + g.stack,

  local commonSelectors = 'namespace="$namespace", job="$job"',
  local podSelector = 'observatorium-gubernator-.*',
  local containerSelector = 'gubernator',


  dashboard:: {
    data:
      g.dashboard('Observatorium / Gubernator')
      .addRow(
        g.row('GetRateLimits API')
        .addPanel(
          panel('Requests', 'Rate of gRPC requests to the API per second', 'reqps') +
          g.queryPanel(
            'sum by (job, method) (rate(gubernator_grpc_request_counts{%s, method=~".*/GetRateLimits"}[$interval]))' % commonSelectors,
            '{{job}}',
          )
        )
        .addPanel(
          panel('Errors', 'Rate of failed gRPC requests to the API per second', 'reqps') +
          g.queryPanel(
            'sum by (job, method) (rate(gubernator_grpc_request_counts{%s, method=~".*/GetRateLimits", status="failed"}[$interval]))' % commonSelectors,
            '{{status}} {{job}}',
          )
        )
        .addPanel(
          panel('Latencies', 'Latency of gRPC requests to the API per percentiles', 'ms') +
          g.queryPanel(
            'avg by(quantile, job) (gubernator_grpc_request_duration{%s, method=~".*/GetRateLimits"}) * 1000' % commonSelectors,
            '{{quantile}}th percentile',
          )
        )
        .addPanel(
          panel('Over Limit requests rate', 'Rate of requests that resulted in rate limiting (over the limit) per second', 'reqps') +
          g.queryPanel(
            'sum by(job) (rate(gubernator_over_limit_counter{%s}[$interval]))' % commonSelectors,
            '{{job}}',
          )
        )
      )
      .addRow(
        g.row('GetPeerRateLimits API')
        .addPanel(
          panel('Requests', 'Rate of gRPC requests to the API per second', 'reqps') +
          g.queryPanel(
            'sum by (job, method) (rate(gubernator_grpc_request_counts{%s, method=~".*/GetPeerRateLimits"}[$interval]))' % commonSelectors,
            '{{job}}',
          )
        )
        .addPanel(
          panel('Errors', 'Rate of failed gRPC requests to the API per second', 'reqps') +
          g.queryPanel(
            'sum by (job, method) (rate(gubernator_grpc_request_counts{%s, method=~".*/GetPeerRateLimits", status="failed"}[$interval]))' % commonSelectors,
            '{{status}} {{job}}',
          )
        )
        .addPanel(
          panel('Latencies', 'Latency of gRPC requests to the API per percentiles', 'ms') +
          g.queryPanel(
            'avg by(quantile, job) (gubernator_grpc_request_duration{%s, method=~".*/GetPeerRateLimits"}) * 1000' % commonSelectors,
            '{{quantile}}th percentile',
          )
        )
      )
      .addRow(
        g.row('Queues')
        .addPanel(
          panel('getRateLimitsBatch queue length', 'The getRateLimitsBatch() queue length in PeerClient.  This represents rate checks queued by for batching to a remote peer.', '') +
          g.queryPanel(
            'sum by(job) (rate(gubernator_queue_length{%s}[$interval]))' % commonSelectors,
            '{{job}}',
          )
        )
        .addPanel(
          panel('GetRateLimit queue length', 'The number of GetRateLimit requests queued up in GubernatorPool workers.', '') +
          g.queryPanel(
            'sum by(job) (rate(gubernator_pool_queue_length{%s}[$interval]))' % commonSelectors,
            '{{job}}',
          )
        )
      )
      .addRow(
        g.row('Cache')
        .addPanel(
          panel('Requests', 'Rate of cache requests per second', 'reqps') +
          g.queryPanel(
            'sum by(job) (rate(gubernator_cache_access_count{%s}[$interval]))' % commonSelectors,
            '{{job}}',
          )
        )
        .addPanel(
          panel('Misses', 'Rate of cache misses per second', 'reqps') +
          g.queryPanel(
            'sum by(job) (rate(gubernator_cache_access_count{%s, type="miss"}[$interval])) / sum by(job) (rate(gubernator_cache_access_count{%s}[$interval]))' % [commonSelectors, commonSelectors],
            '{{job}}',
          )
        )
        .addPanel(
          panel('Size', 'The number of items in LRU Cache which holds the rate limits.', '') +
          g.queryPanel(
            'sum by(job) (gubernator_cache_size{%s})' % commonSelectors,
            '{{job}}',
          )
        )
        .addPanel(
          panel('Unexpired evictions', 'Rate of cache items which were evicted while unexpired per second.', 'reqps') +
          g.queryPanel(
            'sum by(job) (rate(gubernator_unexpired_evictions_count{%s}[$interval]))' % commonSelectors,
            '{{job}}',
          )
        )
      )
      .addRow(
        g.row('Other latencies')
        .addPanel(
          panel('Batch', 'Latency of batch send operations to a remote peer per percentiles', 'ms') +
          g.queryPanel(
            'avg by(quantile, job) (gubernator_batch_send_duration{%s}) * 1000' % commonSelectors,
            '{{quantile}}th percentile',
          )
        )
        .addPanel(
          panel('Broadcast', 'Latency of of GLOBAL broadcasts to peers per percentiles', 'ms') +
          g.queryPanel(
            'avg by(quantile, job) (gubernator_broadcast_durations{%s}) * 1000' % commonSelectors,
            '{{quantile}}th percentile {{job}}',
          )
        )
        .addPanel(
          panel('Async', 'Latency of of GLOBAL async sends per percentiles', 'ms') +
          g.queryPanel(
            'avg by(quantile, job) (gubernator_async_durations{%s}) * 1000' % commonSelectors,
            '{{quantile}}th percentile {{job}}',
          )
        )
      )
      .addRow(
        g.row('Resources usage')
        .addPanel(
          panel('Memory Usage', 'Memory usage of the Gubernator process', 'MiB') +
          g.queryPanel(
            '(container_memory_working_set_bytes{container="%s", pod=~"%s", namespace="$namespace"}) / 1024^2' % [
              containerSelector,
              podSelector,
            ],
            'memory usage system {{pod}}',
          )
        )
        .addPanel(
          panel('CPU Usage', 'CPU usage of the Gubernator process', 'percent') +
          g.queryPanel(
            'rate(process_cpu_seconds_total{container="%s", pod=~"%s", namespace="$namespace"}[$interval]) * 100' % [
              containerSelector,
              podSelector,
            ],
            'cpu usage system {{pod}}',
          )
        )
        .addPanel(
          panel('Pod/Container Restarts', 'Number of times the pod/container has restarted', '') +
          g.queryPanel(
            'sum by (pod) (kube_pod_container_status_restarts_total{container="%s", pod=~"%s", namespace="$namespace",})' % [
              containerSelector,
              podSelector,
            ],
            'pod restart count {{pod}}',
          )
        )
        .addPanel(
          panel('Network Usage', 'Network usage of the Gubernator process', 'binBps') +
          g.queryPanel(
            [
              'sum by (pod) (rate(container_network_receive_bytes_total{pod=~"%s", namespace="$namespace"}[$interval]))' % podSelector,
              'sum by (pod) (rate(container_network_transmit_bytes_total{pod=~"%s", namespace="$namespace"}[$interval]))' % podSelector,
            ],
            [
              'network traffic in {{pod}}',
              'network traffic out {{pod}}',
            ]
          )
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
