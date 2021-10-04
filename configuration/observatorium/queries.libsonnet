{
  queries: [
    {
      name: 'query-path-sli-1M-samples',
      query: 'avg_over_time(avalanche_metric_mmmmm_0_0{tenant_id="1610b0c3-c509-4592-a256-a1871353dbfa"}[1h])',
    },
    {
      name: 'query-path-sli-10M-samples',
      query: 'avg_over_time(avalanche_metric_mmmmm_0_0{tenant_id="1610b0c3-c509-4592-a256-a1871353dbfa"}[10h])',
    },
    {
      name: 'query-path-sli-100M-samples',
      query: 'avg_over_time(avalanche_metric_mmmmm_0_0{tenant_id="1610b0c3-c509-4592-a256-a1871353dbfa"}[100h])',
    },
  ],
}
