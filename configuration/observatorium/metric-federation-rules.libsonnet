{
  prometheus+:: {
    recordingrules+: {
      groups+: [
        {
          name: 'kafka.rules',
          interval: '1m',
          rules: [
            {
              record: 'rhosak:haproxy_server_bytes_out_total:kube_namespace_labels:sum_rate',
              expr: |||
                haproxy_server_bytes_out_total:kube_namespace_labels:sum_rate
              |||,
            },
            {
              record: 'rhosak:haproxy_server_bytes_in_total:kube_namespace_labels:sum_rate',
              expr: |||
                haproxy_server_bytes_in_total:kube_namespace_labels:sum_rate
              |||,
            },
            {
              record: 'rhosak:haproxy_server_bytes_in_total:kube_namespace_labels:sum_rate:haproxy_server_bytes_out_total:kube_namespace_labels:sum_rate',
              expr: |||
                haproxy_server_bytes_in_total:kube_namespace_labels:sum_rate:haproxy_server_bytes_out_total:kube_namespace_labels:sum_rate
              |||,
            },
            {
              record: 'rhosak:kafka_broker_quota_totalstorageusedbytes:kube_namespace_labels:sum_max_over_time',
              expr: |||
                kafka_broker_quota_totalstorageusedbytes:kube_namespace_labels:sum_max_over_time
              |||,
            },
            {
              record: 'rhosak:strimzi_resource_state:kube_namespace_labels:group',
              expr: |||
                strimzi_resource_state:kube_namespace_labels:group
              |||,
            },
          ],
        },
      ],
    },
  },
}
