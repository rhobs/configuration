{
  queries: [
    {
      name: 'query-path-sli-1M-samples',
      query: 'avg_over_time(avalanche_metric_mmmmm_0_0{tenant_id="0fc2b00e-201b-4c17-b9f2-19d91adc4fd2"}[1h])',
    },
    {
      name: 'query-path-sli-10M-samples',
      query: 'avg_over_time(avalanche_metric_mmmmm_0_0{tenant_id="0fc2b00e-201b-4c17-b9f2-19d91adc4fd2"}[10h])',
    },
    {
      name: 'query-path-sli-100M-samples',
      query: 'avg_over_time(avalanche_metric_mmmmm_0_0{tenant_id="0fc2b00e-201b-4c17-b9f2-19d91adc4fd2"}[100h])',
    },
  ],
}
