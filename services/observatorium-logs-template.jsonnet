local obs = import 'observatorium.libsonnet';
{
  apiVersion: 'v1',
  kind: 'Template',
  metadata: {
    name: 'observatorium-logs',
  },
  objects: [
    obs.lokiCaches.manifests[name] {
      metadata+: {
        namespace:: 'hidden',
      },
    }
    for name in std.objectFields(obs.lokiCaches.manifests)
  ] + [
    obs.loki.manifests[name] {
      metadata+: {
        namespace:: 'hidden',
      },
    }
    for name in std.objectFields(obs.loki.manifests)
  ],
  parameters: [
    { name: 'NAMESPACE', value: 'observatorium-logs' },
    { name: 'STORAGE_CLASS', value: 'gp2' },
    { name: 'LOKI_IMAGE_TAG', value: '2.0.0' },
    { name: 'LOKI_IMAGE', value: 'docker.io/grafana/loki' },
    { name: 'LOKI_S3_SECRET', value: 'observatorium-logs-stage-s3' },
    { name: 'LOKI_COMPACTOR_CPU_REQUESTS', value: '500m' },
    { name: 'LOKI_COMPACTOR_CPU_LIMITS', value: '1000m' },
    { name: 'LOKI_COMPACTOR_MEMORY_REQUESTS', value: '2Gi' },
    { name: 'LOKI_COMPACTOR_MEMORY_LIMITS', value: '4Gi' },
    { name: 'LOKI_DISTRIBUTOR_REPLICAS', value: '2' },
    { name: 'LOKI_DISTRIBUTOR_CPU_REQUESTS', value: '500m' },
    { name: 'LOKI_DISTRIBUTOR_CPU_LIMITS', value: '1000m' },
    { name: 'LOKI_DISTRIBUTOR_MEMORY_REQUESTS', value: '500Mi' },
    { name: 'LOKI_DISTRIBUTOR_MEMORY_LIMITS', value: '1Gi' },
    { name: 'LOKI_INGESTER_REPLICAS', value: '2' },
    { name: 'LOKI_INGESTER_CPU_REQUESTS', value: '1000m' },
    { name: 'LOKI_INGESTER_CPU_LIMITS', value: '2000m' },
    { name: 'LOKI_INGESTER_MEMORY_REQUESTS', value: '5Gi' },
    { name: 'LOKI_INGESTER_MEMORY_LIMITS', value: '10Gi' },
    { name: 'LOKI_QUERIER_REPLICAS', value: '2' },
    { name: 'LOKI_QUERIER_CPU_REQUESTS', value: '500m' },
    { name: 'LOKI_QUERIER_CPU_LIMITS', value: '500m' },
    { name: 'LOKI_QUERIER_MEMORY_REQUESTS', value: '600Mi' },
    { name: 'LOKI_QUERIER_MEMORY_LIMITS', value: '1200Mi' },
    { name: 'LOKI_QUERY_FRONTEND_REPLICAS', value: '2' },
    { name: 'LOKI_QUERY_FRONTEND_CPU_REQUESTS', value: '500m' },
    { name: 'LOKI_QUERY_FRONTEND_CPU_LIMITS', value: '500m' },
    { name: 'LOKI_QUERY_FRONTEND_MEMORY_REQUESTS', value: '600Mi' },
    { name: 'LOKI_QUERY_FRONTEND_MEMORY_LIMITS', value: '1200Mi' },
    // This value should be set equal t
    // LOKI_REPLICATION_FACTOR <= LOKI_INGESTER_REPLICAS
    { name: 'LOKI_REPLICATION_FACTOR', value: '2' },
    // The querier concurrency should be equal to (or less than) the CPU cores of the system the querier runs
    // A higher value will lead to a querier trying to process more requests than there are available
    // cores and will result in scheduling delays.
    // This value should be set equal to:
    //
    // std.floor( querier-concurrency / LOKI_QUERY_FRONTEND_REPLICAS)
    //
    // e.g. limit to N/2 worker threads per frontend, as we have two frontends.
    { name: 'LOKI_QUERY_PARALLELISM', value: '2' },
    { name: 'LOKI_CHUNK_CACHE_REPLICAS', value: '2' },
    { name: 'LOKI_CHUNK_CACHE_CPU_REQUESTS', value: '500m' },
    { name: 'LOKI_CHUNK_CACHE_CPU_LIMITS', value: '3' },
    { name: 'LOKI_CHUNK_CACHE_MEMORY_REQUESTS', value: '5016Mi' },
    { name: 'LOKI_CHUNK_CACHE_MEMORY_LIMITS', value: '6Gi' },
    { name: 'LOKI_INDEX_QUERY_CACHE_REPLICAS', value: '2' },
    { name: 'LOKI_INDEX_QUERY_CACHE_CPU_REQUESTS', value: '500m' },
    { name: 'LOKI_INDEX_QUERY_CACHE_CPU_LIMITS', value: '3' },
    { name: 'LOKI_INDEX_QUERY_CACHE_MEMORY_REQUESTS', value: '1329Mi' },
    { name: 'LOKI_INDEX_QUERY_CACHE_MEMORY_LIMITS', value: '1536Mi' },
    { name: 'LOKI_RESULTS_CACHE_REPLICAS', value: '2' },
    { name: 'LOKI_RESULTS_CACHE_CPU_REQUESTS', value: '500m' },
    { name: 'LOKI_RESULTS_CACHE_CPU_LIMITS', value: '3' },
    { name: 'LOKI_RESULTS_CACHE_MEMORY_REQUESTS', value: '1329Mi' },
    { name: 'LOKI_RESULTS_CACHE_MEMORY_LIMITS', value: '1536Mi' },
    { name: 'LOKI_PVC_REQUEST', value: '50Gi' },
    { name: 'JAEGER_COLLECTOR_NAMESPACE', value: 'observatorium' },
    { name: 'JAEGER_AGENT_IMAGE', value: 'jaegertracing/jaeger-agent' },
    { name: 'JAEGER_AGENT_IMAGE_TAG', value: '1.14.0' },
    { name: 'JAEGER_PROXY_CPU_REQUEST', value: '100m' },
    { name: 'JAEGER_PROXY_MEMORY_REQUEST', value: '100Mi' },
    { name: 'JAEGER_PROXY_CPU_LIMITS', value: '200m' },
    { name: 'JAEGER_PROXY_MEMORY_LIMITS', value: '200Mi' },
    { name: 'MEMCACHED_IMAGE', value: 'docker.io/memcached' },
    { name: 'MEMCACHED_IMAGE_TAG', value: '1.5.20-alpine' },
    { name: 'MEMCACHED_EXPORTER_IMAGE', value: 'docker.io/prom/memcached-exporter' },
    { name: 'MEMCACHED_EXPORTER_IMAGE_TAG', value: 'v0.6.0' },
    { name: 'MEMCACHED_CPU_REQUEST', value: '500m' },
    { name: 'MEMCACHED_CPU_LIMIT', value: '3' },
    { name: 'MEMCACHED_MEMORY_REQUEST', value: '1329Mi' },
    { name: 'MEMCACHED_MEMORY_LIMIT', value: '1844Mi' },
    { name: 'MEMCACHED_EXPORTER_CPU_REQUEST', value: '50m' },
    { name: 'MEMCACHED_EXPORTER_CPU_LIMIT', value: '200m' },
    { name: 'MEMCACHED_EXPORTER_MEMORY_REQUEST', value: '50Mi' },
    { name: 'MEMCACHED_EXPORTER_MEMORY_LIMIT', value: '200Mi' },
  ],
}
