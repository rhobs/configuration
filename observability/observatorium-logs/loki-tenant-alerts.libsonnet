function(namespace) {
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'loki_tenant_alerts',
        rules: [
          {
            alert: 'LokiTenantRateLimitWarning',
            expr: |||
              sum by (tenant, reason) (sum_over_time(rate(loki_discarded_samples_total{namespace="%s"}[1m])[30m:1m]))
              > 100
            ||| % namespace,
            'for': '15m',
            labels: {
              severity: 'medium',
            },
            annotations: {
              message: |||
                {{ $labels.tenant }} is experiencing rate limiting for reason '{{ $labels.reason }}': {{ printf "%.2f" $value }}%.
              |||,
            },
          },
        ],
      },
    ],
  },
}
