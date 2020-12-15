local loki = (import 'github.com/observatorium/deployments/components/loki.libsonnet');
local lokiCaches = (import 'components/loki-caches.libsonnet');

{
  local obs = self,

  lokiCaches:: lokiCaches({
    local cfg = self,
    name: obs.config.name,
    namespace: '${NAMESPACE}',
    version: '${MEMCACHED_IMAGE_TAG}',
    image: '%s:%s' % ['${MEMCACHED_IMAGE}', cfg.version],
    commonLabels+: obs.config.commonLabels,
    exporterVersion: '${MEMCACHED_EXPORTER_IMAGE_TAG}',
    exporterImage: '%s:%s' % ['${MEMCACHED_EXPORTER_IMAGE}', cfg.exporterVersion],

    components+: {
      chunkCache: {
        replicas: 1,  // overwritten in observatorium-logs-template.libsonnet
        withServiceMonitor: true,
      },
      indexQueryCache: {
        replicas: 1,  // overwritten in observatorium-logs-template.libsonnet
        withServiceMonitor: true,
      },
      resultsCache: {
        replicas: 1,  // overwritten in observatorium-logs-template.libsonnet
        withServiceMonitor: true,
      },
    },
  }),

  loki:: loki({
    local cfg = self,
    name: 'observatorium-' + cfg.commonLabels['app.kubernetes.io/name'],
    namespace: '${NAMESPACE}',
    version: '${LOKI_IMAGE_TAG}',
    image: '%s:%s' % ['${LOKI_IMAGE}', cfg.version],
    commonLabels+: obs.config.commonLabels,
    objectStorageConfig: {
      secretName: '${LOKI_S3_SECRET}',
      bucketsKey: 'bucket',
      regionKey: 'aws_region',
      accessKeyIdKey: 'aws_access_key_id',
      secretAccessKeyKey: 'aws_secret_access_key',
    },
    memberlist: {
      ringName: 'gossip-ring',
    },
    replicas: {
      compactor: 1,  // Loki supports only a single compactor instance.
      distributor: '${{LOKI_DISTRIBUTOR_REPLICAS}}',
      ingester: '${{LOKI_INGESTER_REPLICAS}}',
      querier: '${{LOKI_QUERIER_REPLICAS}}',
      query_frontend: '${{LOKI_QUERY_FRONTEND_REPLICAS}}',
    },
    resources: {
      compactor: {
        requests: {
          cpu: '${LOKI_COMPACTOR_CPU_REQUESTS}',
          memory: '${LOKI_COMPACTOR_MEMORY_REQUESTS}',
        },
        limits: {
          cpu: '${LOKI_COMPACTOR_CPU_LIMITS}',
          memory: '${LOKI_COMPACTOR_MEMORY_LIMITS}',
        },
      },
      distributor: {
        requests: {
          cpu: '${LOKI_DISTRIBUTOR_CPU_REQUESTS}',
          memory: '${LOKI_DISTRIBUTOR_MEMORY_REQUESTS}',
        },
        limits: {
          cpu: '${LOKI_DISTRIBUTOR_CPU_LIMITS}',
          memory: '${LOKI_DISTRIBUTOR_MEMORY_LIMITS}',
        },
      },
      ingester: {
        requests: {
          cpu: '${LOKI_INGESTER_CPU_REQUESTS}',
          memory: '${LOKI_INGESTER_MEMORY_REQUESTS}',
        },
        limits: {
          cpu: '${LOKI_INGESTER_CPU_LIMITS}',
          memory: '${LOKI_INGESTER_MEMORY_LIMITS}',
        },
      },
      querier: {
        requests: {
          cpu: '${LOKI_QUERIER_CPU_REQUESTS}',
          memory: '${LOKI_QUERIER_MEMORY_REQUESTS}',
        },
        limits: {
          cpu: '${LOKI_QUERIER_CPU_LIMITS}',
          memory: '${LOKI_QUERIER_MEMORY_LIMITS}',
        },
      },
      query_frontend: {
        requests: {
          cpu: '${LOKI_QUERY_FRONTEND_CPU_REQUESTS}',
          memory: '${LOKI_QUERY_FRONTEND_MEMORY_REQUESTS}',
        },
        limits: {
          cpu: '${LOKI_QUERY_FRONTEND_CPU_LIMITS}',
          memory: '${LOKI_QUERY_FRONTEND_MEMORY_LIMITS}',
        },
      },
    },
    storeChunkCache: 'dns+%s.%s.svc.cluster.local:%s' % [
      obs.lokiCaches.manifests['chunk-cache-service'].metadata.name,
      obs.lokiCaches.manifests['chunk-cache-service'].metadata.namespace,
      obs.lokiCaches.manifests['chunk-cache-service'].spec.ports[0].port,
    ],
    indexQueryCache: 'dns+%s.%s.svc.cluster.local:%s' % [
      obs.lokiCaches.manifests['index-query-cache-service'].metadata.name,
      obs.lokiCaches.manifests['index-query-cache-service'].metadata.namespace,
      obs.lokiCaches.manifests['index-query-cache-service'].spec.ports[0].port,
    ],
    resultsCache: 'dns+%s.%s.svc.cluster.local:%s' % [
      obs.lokiCaches.manifests['results-cache-service'].metadata.name,
      obs.lokiCaches.manifests['results-cache-service'].metadata.namespace,
      obs.lokiCaches.manifests['results-cache-service'].spec.ports[0].port,
    ],
    volumeClaimTemplate: {
      spec: {
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: '${LOKI_PVC_REQUEST}',
          },
        },
        storageClassName: '${STORAGE_CLASS}',
      },
    },
    components+: {
      compactor+: { withServiceMonitor: true },
      distributor+: { withServiceMonitor: true },
      ingester+: { withServiceMonitor: true },
      querier+: { withServiceMonitor: true },
      query_frontend+: { withServiceMonitor: true },
    },
    config+: {
      limits_config+: {
        max_global_streams_per_user: 25000,
      },
      tracing: {
        enabled: true,
      },
    },
  }),
}
