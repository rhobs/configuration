{
  prometheus+:: {
    recordingrules+: {
      groups+: [
        {
          name: 'rhacs.rules',
          interval: '1m',
          rules: [
            {
              record: 'rhacs:rox_central_cluster_metrics_cpu_capacity:avg_over_time1h',
              expr: |||
                rhacs:rox_central_cluster_metrics_cpu_capacity:avg_over_time1h
              |||,
            },
          ],
        },
      ],
    },
  },
}
