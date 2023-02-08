local loki = (import 'github.com/observatorium/observatorium/configuration/components/loki.libsonnet');
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
        resources+: {
          requests: {
            cpu: '${LOKI_CHUNK_CACHE_CPU_REQUESTS}',
            memory: '${LOKI_CHUNK_CACHE_MEMORY_REQUESTS}',
          },
          limits: {
            cpu: '${LOKI_CHUNK_CACHE_CPU_LIMITS}',
            memory: '${LOKI_CHUNK_CACHE_MEMORY_LIMITS}',
          },
        },
      },
      indexQueryCache: {
        replicas: 1,  // overwritten in observatorium-logs-template.libsonnet
        withServiceMonitor: true,
        resources+: {
          requests: {
            cpu: '${LOKI_INDEX_QUERY_CACHE_CPU_REQUESTS}',
            memory: '${LOKI_INDEX_QUERY_CACHE_MEMORY_REQUESTS}',
          },
          limits: {
            cpu: '${LOKI_INDEX_QUERY_CACHE_CPU_LIMITS}',
            memory: '${LOKI_INDEX_QUERY_CACHE_MEMORY_LIMITS}',
          },
        },
      },
      resultsCache: {
        replicas: 1,  // overwritten in observatorium-logs-template.libsonnet
        withServiceMonitor: true,
        resources+: {
          requests: {
            cpu: '${LOKI_RESULTS_CACHE_CPU_REQUESTS}',
            memory: '${LOKI_RESULTS_CACHE_MEMORY_REQUESTS}',
          },
          limits: {
            cpu: '${LOKI_RESULTS_CACHE_CPU_LIMITS}',
            memory: '${LOKI_RESULTS_CACHE_MEMORY_LIMITS}',
          },
        },
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
    query+: {
      concurrency: 2,  // overwritten in observatorium-logs-template-overwrites.libsonnet
    },
    objectStorageConfig: {
      secretName: '${LOKI_S3_SECRET}',
      bucketsKey: 'bucket',
      regionKey: 'aws_region',
      accessKeyIdKey: 'aws_access_key_id',
      secretAccessKeyKey: 'aws_secret_access_key',
    },
    rulesStorageConfig: {
      type: 's3',
      secretName: '${RULES_OBJSTORE_S3_SECRET}',
      bucketsKey: 'bucket',
      regionKey: 'aws_region',
      accessKeyIdKey: 'aws_access_key_id',
      secretAccessKeyKey: 'aws_secret_access_key',
    },
    memberlist: {
      ringName: 'gossip-ring',
    },
    wal: {
      replayMemoryCeiling: '4GB',  // overwritten in observatorium-logs-template-overwrites.libsonnet
    },
    replicas: {
      compactor: 1,  // Loki supports only a single compactor instance.
      distributor: '${{LOKI_DISTRIBUTOR_REPLICAS}}',
      ingester: '${{LOKI_INGESTER_REPLICAS}}',
      index_gateway: '${{LOKI_INDEX_GATEWAY_REPLICAS}}',
      querier: '${{LOKI_QUERIER_REPLICAS}}',
      query_scheduler: '${{LOKI_QUERY_SCHEDULER_REPLICAS}}',
      query_frontend: '${{LOKI_QUERY_FRONTEND_REPLICAS}}',
      ruler: '${{LOKI_RULER_REPLICAS}}',
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
      index_gateway: {
        requests: {
          cpu: '${LOKI_INDEX_GATEWAY_CPU_REQUESTS}',
          memory: '${LOKI_INDEX_GATEWAY_MEMORY_REQUESTS}',
        },
        limits: {
          cpu: '${LOKI_INDEX_GATEWAY_CPU_LIMITS}',
          memory: '${LOKI_INDEX_GATEWAY_MEMORY_LIMITS}',
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
      query_scheduler: {
        requests: {
          cpu: '${LOKI_QUERY_SCHEDULER_CPU_REQUESTS}',
          memory: '${LOKI_QUERY_SCHEDULER_MEMORY_REQUESTS}',
        },
        limits: {
          cpu: '${LOKI_QUERY_SCHEDULER_CPU_LIMITS}',
          memory: '${LOKI_QUERY_SCHEDULER_MEMORY_LIMITS}',
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
      ruler: {
        requests: {
          cpu: '${LOKI_RULER_CPU_REQUESTS}',
          memory: '${LOKI_RULER_MEMORY_REQUESTS}',
        },
        limits: {
          cpu: '${LOKI_RULER_CPU_LIMITS}',
          memory: '${LOKI_RULER_MEMORY_LIMITS}',
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
      index_gateway+: { withServiceMonitor: true },
      querier+: { withServiceMonitor: true },
      query_scheduler+: { withServiceMonitor: true },
      query_frontend+: { withServiceMonitor: true },
      ruler+: { withServiceMonitor: true },
    },
    config+: {
      limits_config+: {
        ingestion_rate_mb: 50,
        max_global_streams_per_user: 25000,
        per_stream_rate_limit: '5MB',
      },
      querier+: {
        engine+: {
          timeout: '6m',
        },
      },
      ruler+: {
        enable_alertmanager_discovery: true,
        enable_alertmanager_v2: false,
        alertmanager_url: 'http://_http._tcp.observatorium-alertmanager.${ALERTMANAGER_NAMESPACE}.svc.cluster.local',
        alertmanager_refresh_interval: '1m',
      },
      tracing: {
        // TODO(@periklis):
        // Re-enable jaeger tracing of Loki once both issues fixed:
        // - https://github.com/grafana/loki/issues/6667
        // - https://github.com/weaveworks/common/pull/246
        // Currently collecting the user id and org id in exemplar
        // when Loki is sampled by jaeger fails with a golang panic:
        // `http: panic serving : exemplar labels have 87 runes, exceeding the limit of 64`
        enabled: false,
      },
    },
  }),
}
