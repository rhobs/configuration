local g = import 'github.com/grafana/jsonnet-libs/grafana-builder/grafana.libsonnet';
local template = import 'grafonnet/template.libsonnet';

function() {
  local panel(title, description='', unit='short') =
    g.panel(title) {
      description: description,
      fill: 1,
      fillGradient: 0,
      linewidth: 1,
      span: 0,
      stack: true,
      yaxes: g.yaxes(unit),
    },

  local datasourcesRegex = '/^rhobs.*|telemeter-prod-01-prometheus|app-sre-stage-01-prometheus/',
  local labelMatchers = {
    ns: 'namespace="$namespace"',
    job: 'job="observatorium-gubernator"',
    nsAndJob: std.join(', ', [self.ns, self.job]),
    pod: 'pod=~"observatorium-gubernator.*"',
    container: 'container="gubernator"',
  },
  local intervalTemplate =
    template.interval(
      'interval',
      '5m,10m,30m,1h,6h,12h,auto',
      label='interval',
      current='5m',
    ),

  dashboard:: {
    data:
      g.dashboard('Observatorium - Gubernator')
      .addTemplate('namespace', 'gubernator_check_counter', 'namespace')
      .addRow(
        g.row('GetRateLimits API')
        .addPanel(
          panel('Requests', 'Rate of gRPC requests to the API per second', 'reqps') +
          g.queryPanel(
            'sum by (job, method) (rate(gubernator_grpc_request_counts{%(nsAndJob)s, method=~".*/GetRateLimits"}[$interval]))' % labelMatchers,
            '{{job}}',
          )
        )
        .addPanel(
          panel('Errors', 'Rate of failed gRPC requests to the API per second', 'reqps') +
          g.queryPanel(
            'sum by (job, method) (rate(gubernator_grpc_request_counts{%(nsAndJob)s, method=~".*/GetRateLimits", status="failed"}[$interval]))' % labelMatchers,
            '{{status}} {{job}}',
          )
        )
        .addPanel(
          panel('Latencies', 'Latency of gRPC requests to the API per percentiles', 'ms') +
          g.queryPanel(
            'avg by(quantile, job) (gubernator_grpc_request_duration{%(nsAndJob)s, method=~".*/GetRateLimits"}) * 1000' % labelMatchers,
            '{{quantile}}th percentile',
          )
        )
        .addPanel(
          panel('Over Limit requests rate', 'Rate of requests that resulted in rate limiting (over the limit) per second', 'reqps') +
          g.queryPanel(
            'sum by(job) (rate(gubernator_over_limit_counter{%(nsAndJob)s}[$interval]))' % labelMatchers,
            '{{job}}',
          )
        )
      )
      .addRow(
        g.row('GetPeerRateLimits API')
        .addPanel(
          panel('Requests', 'Rate of gRPC requests to the API per second', 'reqps') +
          g.queryPanel(
            'sum by (job, method) (rate(gubernator_grpc_request_counts{%(nsAndJob)s, method=~".*/GetPeerRateLimits"}[$interval]))' % labelMatchers,
            '{{job}}',
          )
        )
        .addPanel(
          panel('Errors', 'Rate of failed gRPC requests to the API per second', 'reqps') +
          g.queryPanel(
            'sum by (job, method) (rate(gubernator_grpc_request_counts{%(nsAndJob)s, method=~".*/GetPeerRateLimits", status="failed"}[$interval]))' % labelMatchers,
            '{{status}} {{job}}',
          )
        )
        .addPanel(
          panel('Latencies', 'Latency of gRPC requests to the API per percentiles', 'ms') +
          g.queryPanel(
            'avg by(quantile, job) (gubernator_grpc_request_duration{%(nsAndJob)s, method=~".*/GetPeerRateLimits"}) * 1000' % labelMatchers,
            '{{quantile}}th percentile',
          )
        )
      )
      .addRow(
        g.row('Queues')
        .addPanel(
          panel('getRateLimitsBatch queue length', 'The getRateLimitsBatch() queue length in PeerClient.  This represents rate checks queued by for batching to a remote peer.', '') +
          g.queryPanel(
            'sum by(job) (rate(gubernator_queue_length{%(nsAndJob)s}[$interval]))' % labelMatchers,
            '{{job}}',
          )
        )
        .addPanel(
          panel('GetRateLimit queue length', 'The number of GetRateLimit requests queued up in GubernatorPool workers.', '') +
          g.queryPanel(
            'sum by(job) (rate(gubernator_pool_queue_length{%(nsAndJob)s}[$interval]))' % labelMatchers,
            '{{job}}',
          )
        )
      )
      .addRow(
        g.row('Cache')
        .addPanel(
          panel('Requests', 'Rate of cache requests per second', 'reqps') +
          g.queryPanel(
            'sum by(job) (rate(gubernator_cache_access_count{%(nsAndJob)s}[$interval]))' % labelMatchers,
            '{{job}}',
          )
        )
        .addPanel(
          panel('Misses', 'Rate of cache misses per second', 'reqps') +
          g.queryPanel(
            'sum by(job) (rate(gubernator_cache_access_count{%(nsAndJob)s, type="miss"}[$interval])) / sum by(job) (rate(gubernator_cache_access_count{%(nsAndJob)s}[$interval]))' % labelMatchers,
            '{{job}}',
          )
        )
        .addPanel(
          panel('Size', 'The number of items in LRU Cache which holds the rate limits.', '') +
          g.queryPanel(
            'sum by(job) (gubernator_cache_size{%(nsAndJob)s})' % labelMatchers,
            '{{job}}',
          )
        )
        .addPanel(
          panel('Unexpired evictions', 'Rate of cache items which were evicted while unexpired per second.', 'reqps') +
          g.queryPanel(
            'sum by(job) (rate(gubernator_unexpired_evictions_count{%(nsAndJob)s}[$interval]))' % labelMatchers,
            '{{job}}',
          )
        )
      )
      .addRow(
        g.row('Other latencies')
        .addPanel(
          panel('Batch', 'Latency of batch send operations to a remote peer per percentiles', 'ms') +
          g.queryPanel(
            'avg by(quantile, job) (gubernator_batch_send_duration{%(nsAndJob)s}) * 1000' % labelMatchers,
            '{{quantile}}th percentile',
          )
        )
        .addPanel(
          panel('Broadcast', 'Latency of of GLOBAL broadcasts to peers per percentiles', 'ms') +
          g.queryPanel(
            'avg by(quantile, job) (gubernator_broadcast_durations{%(nsAndJob)s}) * 1000' % labelMatchers,
            '{{quantile}}th percentile {{job}}',
          )
        )
        .addPanel(
          panel('Async', 'Latency of of GLOBAL async sends per percentiles', 'ms') +
          g.queryPanel(
            'avg by(quantile, job) (gubernator_async_durations{%(nsAndJob)s}) * 1000' % labelMatchers,
            '{{quantile}}th percentile {{job}}',
          )
        )
      )
      .addRow(
        g.row('Resources usage')
        .addPanel(
          panel('Memory Usage', 'Memory usage of the Gubernator process', 'MiB') +
          g.queryPanel(
            'container_memory_working_set_bytes{%(container)s, %(pod)s, %(ns)s} / 1024^2' % labelMatchers,
            'memory usage system {{pod}}',
          )
        )
        .addPanel(
          panel('CPU Usage', 'CPU usage of the Gubernator process', 'percent') +
          g.queryPanel(
            'rate(process_cpu_seconds_total{%(container)s, %(pod)s, %(ns)s}[$interval]) * 100' % labelMatchers,
            'cpu usage system {{pod}}',
          )
        )
        .addPanel(
          panel('Pod/Container Restarts', 'Number of times the pod/container has restarted', '') +
          g.queryPanel(
            'sum by (pod) (kube_pod_container_status_restarts_total{%(container)s, %(pod)s, %(ns)s})' % labelMatchers,
            'pod restart count {{pod}}',
          )
        )
        .addPanel(
          panel('Network Usage', 'Network usage of the Gubernator process', 'binBps') +
          g.queryPanel(
            [
              'sum by (pod) (rate(container_network_receive_bytes_total{%(pod)s, %(ns)s}[$interval]))' % labelMatchers,
              'sum by (pod) (rate(container_network_transmit_bytes_total{%(pod)s, %(ns)s}[$interval]))' % labelMatchers,
            ],
            [
              'network traffic in {{pod}}',
              'network traffic out {{pod}}',
            ]
          )
        )
      ) + {
        templating+: {
          list: [
            if variable.name == 'datasource'
            then variable { regex: datasourcesRegex }
            else variable
            for variable in super.list
          ] + [intervalTemplate],
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
