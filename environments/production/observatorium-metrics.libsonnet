local t = (import 'github.com/thanos-io/kube-thanos/jsonnet/kube-thanos/thanos.libsonnet');
local trc = (import 'github.com/observatorium/thanos-receive-controller/jsonnet/lib/thanos-receive-controller.libsonnet');
local memcached = (import 'github.com/observatorium/deployments/components/memcached.libsonnet');
local telemeterRules = (import 'github.com/openshift/telemeter/jsonnet/telemeter/rules.libsonnet');

// This file contains all components as configured per upstream projects like kube-thanos etc.
// Please check observatorium-metrics-template.libsonnet for OpenShift Template specific overwrites.

// TODO(kakkoyun): Shouldn't anything that touches templates be moved to other file?
// TODO(kakkoyun): More Code reuse!!
{
  thanos+:: {
    local thanos = self,

    local thanosSharedConfig = {
      image: '${THANOS_IMAGE}:${THANOS_IMAGE_TAG}',
      version: '${THANOS_IMAGE_TAG}',
      namespace: '${NAMESPACE}',
      replicaLabels: ['replica', 'rule_replica', 'prometheus_replica'],
      objectStorageConfig: {
        name: '${THANOS_CONFIG_SECRET}',
        key: 'thanos.yaml',
      },
      tracing: {
        type: 'JAEGER',
        config+: {
          sampler_type: 'ratelimiting',
          sampler_param: 2,
        },
      },
    },

    compact:: t.compact(thanosSharedConfig {
      name: 'observatorium-thanos-compact',
      commonLabels+:: {
        'app.kubernetes.io/part-of': 'observatorium',
        'app.kubernetes.io/instance': 'observatorium',
      },
      replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
      logLevel: '${THANOS_COMPACTOR_LOG_LEVEL}',
      serviceMonitor: true,
      retentionResolutionRaw: '14d',
      retentionResolution5m: '1s',
      retentionResolution1h: '1s',
      disableDownsampling: true,
      deduplicationReplicaLabels: ['replica'],
      resources: {
        limits: {
          cpu: '${THANOS_COMPACTOR_CPU_LIMIT}',
          memory: '${THANOS_COMPACTOR_MEMORY_LIMIT}',
        },
        requests: {
          cpu: '${THANOS_COMPACTOR_CPU_REQUEST}',
          memory: '${THANOS_COMPACTOR_MEMORY_REQUEST}',
        },
      },
      volumeClaimTemplate: {
        spec: {
          accessModes: ['ReadWriteOnce'],
          storageClassName: '${STORAGE_CLASS}',
          resources: {
            requests: {
              storage: '${THANOS_COMPACTOR_PVC_REQUEST}',
            },
          },
        },
      },
      tracing: {},  // disable globally enabled tracing for compact.
    }),

    local observatoriumRules = 'observatorium-rules',
    rule:: t.rule(thanosSharedConfig {
      name: 'observatorium-thanos-rule',
      commonLabels+:: {
        'app.kubernetes.io/part-of': 'observatorium',
        'app.kubernetes.io/instance': 'observatorium',
      },
      replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
      logLevel: '${THANOS_RULER_LOG_LEVEL}',
      serviceMonitor: true,
      queriers: [
        // TODO(kakkoyun): Replace with actual reference one query is moved.
        'dnssrv+_http._tcp.%s.${NAMESPACE}.svc.cluster.local' % 'observatorium-thanos-query',
      ],
      rulesConfig: [
        {
          name: observatoriumRules,
          key: 'foo',
          rules: telemeterRules.prometheus.recordingrules.groups[0].rules,
        },
      ],
      resources: {
        limits: {
          cpu: '${THANOS_RULER_CPU_LIMIT}',
          memory: '${THANOS_RULER_MEMORY_LIMIT}',
        },
        requests: {
          cpu: '${THANOS_RULER_CPU_REQUEST}',
          memory: '${THANOS_RULER_MEMORY_REQUEST}',
        },
      },
      volumeClaimTemplate: {
        spec: {
          accessModes: ['ReadWriteOnce'],
          storageClassName: '${STORAGE_CLASS}',
          resources: {
            requests: {
              storage: '${THANOS_RULER_PVC_REQUEST}',
            },
          },
        },
      },
    }) + {
      // TODO: Move configmap either to upstream (best) or as overwrite.
      configmap: {
        apiVersion: 'v1',
        kind: 'ConfigMap',
        metadata: {
          name: observatoriumRules,
          annotations: {
            'qontract.recycle': 'true',
          },
          labels: {
            'app.kubernetes.io/instance': 'observatorium',
            'app.kubernetes.io/part-of': 'observatorium',
          },
        },
        data: {
          'observatorium.yaml': std.manifestYamlDoc({
            groups: [{
              name: 'observatorium.rules',
              interval: '3m',
              rules: telemeterRules.prometheus.recordingrules.groups[0].rules,
            }],
          }),
        },
      },
    },

    local storeShards = 3,
    stores:: t.storeShards(thanosSharedConfig {
      shards: storeShards,
      name: 'observatorium-thanos-store-shard',
      namespace: '${NAMESPACE}',
      commonLabels+:: thanos.config.commonLabels,
      replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
      ignoreDeletionMarksDelay: '24h',
      volumeClaimTemplate: {
        spec: {
          accessModes: ['ReadWriteOnce'],
          storageClassName: '${STORAGE_CLASS}',
          resources: {
            requests: {
              storage: '50Gi',
            },
          },
        },
      },
      logLevel: '${THANOS_STORE_LOG_LEVEL}',
      local memcachedDefaults = {
        timeout: '2s',
        max_idle_connections: 1000,
        max_async_concurrency: 100,
        max_async_buffer_size: 100000,
        max_get_multi_concurrency: 900,
        max_get_multi_batch_size: 1000,
      },
      indexCache: {
        type: 'memcached',
        config+: memcachedDefaults {
          addresses: ['dnssrv+_client._tcp.%s.%s.svc' % [thanos.storeIndexCache.service.metadata.name, thanos.storeIndexCache.service.metadata.namespace]],
          // Default Memcached Max Connection Limit is '3072', this is related to concurrency.
          max_idle_connections: 1300,  // default: 100 - For better performances, this should be set to a number higher than your peak parallel requests.
          timeout: '400ms',  // default: 500ms
          max_async_buffer_size: 200000,  // default: 10_000
          max_async_concurrency: 200,  // default: 20
          max_get_multi_batch_size: 100,  // default: 0 - No batching.
          max_get_multi_concurrency: 1000,  // default: 100
          max_item_size: '5MiB',  // default: 1Mb
        },
      },
      bucketCache: {
        type: 'memcached',
        config+: memcachedDefaults {
          addresses: ['dnssrv+_client._tcp.%s.%s.svc' % [thanos.storeBucketCache.service.metadata.name, thanos.storeBucketCache.service.metadata.namespace]],
          // Default Memcached Max Connection Limit is '3072', this is related to concurrency.
          max_idle_connections: 1100,  // default: 100 - For better performances, this should be set to a number higher than your peak parallel requests.
          timeout: '400ms',  // default: 500ms
          max_async_buffer_size: 25000,  // default: 10_000
          max_async_concurrency: 50,  // default: 20
          max_get_multi_batch_size: 100,  // default: 0 - No batching.
          max_get_multi_concurrency: 1000,  // default: 100
        },
      },
      resources: {
        requests: {
          cpu: '${THANOS_STORE_CPU_REQUEST}',
          memory: '${THANOS_STORE_MEMORY_REQUEST}',
        },
        limits: {
          cpu: '${THANOS_STORE_CPU_LIMIT}',
          memory: '${THANOS_STORE_MEMORY_LIMIT}',
        },
      },
    }),

    storesServiceMonitor:: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata+: {
        name: 'observatorium-thanos-store-shard',
        labels: thanos.stores.config.commonLabels {
          prometheus: 'app-sre',
          'app.kubernetes.io/version':: 'hidden',
        },
      },
      spec: {
        selector: {
          matchLabels: thanos.stores.config.podLabelSelector,
        },
        namespaceSelector+: { matchNames: ['${NAMESPACE}'] },
        endpoints: [
          {
            port: 'http',
            relabelings: [{
              sourceLabels: ['namespace', 'pod'],
              separator: '/',
              targetLabel: 'instance',
            }],
          },
        ],
      },
    },

    // We use separated memcached instances for index and bucket cache, so disable default.
    storeCache:: {},

    storeIndexCache:: memcached({
      local cfg = self,
      serviceMonitor: true,
      name: 'observatorium-thanos-store-index-cache-' + cfg.commonLabels['app.kubernetes.io/name'],
      namespace: thanosSharedConfig.namespace,
      commonLabels:: {
        'app.kubernetes.io/component': 'store-index-cache',
        'app.kubernetes.io/instance': 'observatorium',
        'app.kubernetes.io/name': 'memcached',
        'app.kubernetes.io/part-of': 'observatorium',
        'app.kubernetes.io/version': cfg.version,
      },

      version: '${MEMCACHED_IMAGE_TAG}',
      image: '%s:%s' % ['${MEMCACHED_IMAGE}', cfg.version],
      exporterVersion: '${MEMCACHED_EXPORTER_IMAGE_TAG}',
      exporterImage: '%s:%s' % ['${MEMCACHED_EXPORTER_IMAGE}', cfg.exporterVersion],
      connectionLimit: '${THANOS_STORE_INDEX_CACHE_CONNECTION_LIMIT}',
      memoryLimitMb: '${THANOS_STORE_INDEX_CACHE_MEMORY_LIMIT_MB}',
      maxItemSize: '5m',
      replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
      resources: {
        memcached: {
          requests: {
            cpu: '${THANOS_STORE_INDEX_CACHE_MEMCACHED_CPU_REQUEST}',
            memory: '${THANOS_STORE_INDEX_CACHE_MEMCACHED_MEMORY_REQUEST}',
          },
          limits: {
            cpu: '${THANOS_STORE_INDEX_CACHE_MEMCACHED_CPU_LIMIT}',
            memory: '${THANOS_STORE_INDEX_CACHE_MEMCACHED_MEMORY_LIMIT}',
          },
        },

        exporter: {
          requests: {
            cpu: '${MEMCACHED_EXPORTER_CPU_REQUEST}',
            memory: '${MEMCACHED_EXPORTER_MEMORY_REQUEST}',
          },
          limits: {
            cpu: '${MEMCACHED_EXPORTER_CPU_LIMIT}',
            memory: '${MEMCACHED_EXPORTER_MEMORY_LIMIT}',
          },
        },
      },
    }),

    storeBucketCache:: memcached({
      local cfg = self,
      name: 'observatorium-thanos-store-bucket-cache-' + cfg.commonLabels['app.kubernetes.io/name'],
      namespace: thanosSharedConfig.namespace,
      commonLabels:: {
        'app.kubernetes.io/component': 'store-bucket-cache',
        'app.kubernetes.io/instance': 'observatorium',
        'app.kubernetes.io/name': 'memcached',
        'app.kubernetes.io/part-of': 'observatorium',
        'app.kubernetes.io/version': cfg.version,
      },

      serviceMonitor: true,
      version: '${MEMCACHED_IMAGE_TAG}',
      image: '%s:%s' % ['${MEMCACHED_IMAGE}', cfg.version],
      exporterVersion: '${MEMCACHED_EXPORTER_IMAGE_TAG}',
      exporterImage: '%s:%s' % ['${MEMCACHED_EXPORTER_IMAGE}', cfg.exporterVersion],
      connectionLimit: '${THANOS_STORE_BUCKET_CACHE_CONNECTION_LIMIT}',
      memoryLimitMb: '${THANOS_STORE_BUCKET_CACHE_MEMORY_LIMIT_MB}',
      replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
      resources: {
        memcached: {
          requests: {
            cpu: '${THANOS_STORE_BUCKET_CACHE_MEMCACHED_CPU_REQUEST}',
            memory: '${THANOS_STORE_BUCKET_CACHE_MEMCACHED_MEMORY_REQUEST}',
          },
          limits: {
            cpu: '${THANOS_STORE_BUCKET_CACHE_MEMCACHED_CPU_LIMIT}',
            memory: '${THANOS_STORE_BUCKET_CACHE_MEMCACHED_MEMORY_LIMIT}',
          },
        },

        exporter: {
          requests: {
            cpu: '${MEMCACHED_EXPORTER_CPU_REQUEST}',
            memory: '${MEMCACHED_EXPORTER_MEMORY_REQUEST}',
          },
          limits: {
            cpu: '${MEMCACHED_EXPORTER_CPU_LIMIT}',
            memory: '${MEMCACHED_EXPORTER_MEMORY_LIMIT}',
          },
        },
      },
    }),

    query:: t.query(thanosSharedConfig {
      name: 'observatorium-thanos-query',
      commonLabels+:: {
        'app.kubernetes.io/instance': 'observatorium',
        'app.kubernetes.io/part-of': 'observatorium',
      },
      replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
      logLevel: '${THANOS_QUERIER_LOG_LEVEL}',
      lookbackDelta: '15m',
      queryTimeout: '15m',
      stores: [
        'dnssrv+_grpc._tcp.%s.%s.svc.cluster.local' % [service.metadata.name, service.metadata.namespace]
        for service in
          [thanos.rule.service] +
          [thanos.stores[shard].service for shard in std.objectFields(thanos.stores)] +
          [thanos.receivers[hashring].service for hashring in std.objectFields(thanos.receivers)]
      ],
      serviceMonitor: true,
      resources: {
        requests: {
          cpu: '${THANOS_QUERIER_CPU_REQUEST}',
          memory: '${THANOS_QUERIER_MEMORY_REQUEST}',
        },
        limits: {
          cpu: '${THANOS_QUERIER_CPU_LIMIT}',
          memory: '${THANOS_QUERIER_MEMORY_LIMIT}',
        },
      },
    }),

    queryFrontend:: t.queryFrontend(thanosSharedConfig {
      name: 'observatorium-thanos-query-frontend',
      commonLabels+:: {
        'app.kubernetes.io/instance': 'observatorium',
        'app.kubernetes.io/part-of': 'observatorium',
      },
      replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
      downstreamURL: 'http://%s.%s.svc.cluster.local.:%d' % [
        thanos.query.service.metadata.name,
        thanos.query.service.metadata.namespace,
        thanos.query.service.spec.ports[1].port,
      ],
      serviceMonitor: true,
      queryRangeCache: {
        type: 'in-memory',
        config+: {
          max_size: '0',
          max_size_items: 2048,
          validity: '6h',
        },
      },
      logQueriesLongerThan: '${THANOS_QUERY_FRONTEND_LOG_QUERIES_LONGER_THAN}',
      fifoCache: {
        maxSize: '0',
        maxSizeItems: 2048,
        validity: '6h',
      },
      resources: {
        requests: {
          cpu: '${THANOS_QUERY_FRONTEND_CPU_REQUEST}',
          memory: '${THANOS_QUERY_FRONTEND_MEMORY_REQUEST}',
        },
        limits: {
          cpu: '${THANOS_QUERY_FRONTEND_CPU_LIMIT}',
          memory: '${THANOS_QUERY_FRONTEND_MEMORY_LIMIT}',
        },
      },
    }),

    // For now, just use an in-memory cache.
    queryFrontendCache:: {},

    local hashrings = [{
      hashring: 'default',
      tenants: [],
    }],

    receivers:: t.receiveHashrings(thanosSharedConfig {
      hashrings: thanos.config.hashrings,
      name: 'observatorium-thanos-receive',
      namespace: '${NAMESPACE}',
      commonLabels+:: {
        'app.kubernetes.io/instance': 'observatorium',
        'app.kubernetes.io/part-of': 'observatorium',
      },
      replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
      replicationFactor: 3,
      retention: '4d',
      replicaLabels: thanos.config.replicaLabels,
      debug: '${THANOS_RECEIVE_DEBUG_ENV}',
      resources: {
        requests: {
          cpu: '${THANOS_RECEIVE_CPU_REQUEST}',
          memory: '${THANOS_RECEIVE_MEMORY_REQUEST}',
        },
        limits: {
          cpu: '${THANOS_RECEIVE_CPU_LIMIT}',
          memory: '${THANOS_RECEIVE_MEMORY_LIMIT}',
        },
      },
      volumeClaimTemplate: {
        spec: {
          accessModes: ['ReadWriteOnce'],
          storageClassName: '${STORAGE_CLASS}',
          resources: {
            requests: {
              storage: '50Gi',
            },
          },
        },
      },
      // hashringConfigMapName: 'observatorium-thanos-receive-controller-tenants-generated',
      hashringConfigMapName: '%s-generated' % thanos.receiveController.configmap.metadata.name,
      logLevel: '${THANOS_RECEIVE_LOG_LEVEL}',
    }),

    receiversServiceMonitor:: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata+: {
        name: 'observatorium-thanos-receive',
        labels: thanos.receivers.config.commonLabels {
          prometheus: 'app-sre',
          'app.kubernetes.io/version':: 'hidden',
        },
      },
      spec: {
        selector: {
          matchLabels: thanos.receivers.config.podLabelSelector,
        },
        namespaceSelector+: { matchNames: ['${NAMESPACE}'] },
        endpoints: [
          {
            port: 'http',
            relabelings: [{
              sourceLabels: ['namespace', 'pod'],
              separator: '/',
              targetLabel: 'instance',
            }],
          },
        ],
      },
    },

    receiveController:: trc({
      namespace: '${NAMESPACE}',
      commonLabels+:: {
        'app.kubernetes.io/instance': 'observatorium',
        'app.kubernetes.io/part-of': 'observatorium',
      },
      name: 'observatorium-thanos-receive-controller',
      image: '${THANOS_RECEIVE_CONTROLLER_IMAGE}:${THANOS_RECEIVE_CONTROLLER_IMAGE_TAG}',
      version: '${THANOS_RECEIVE_CONTROLLER_IMAGE_TAG}',
      replicas: 1,
      hashrings: hashrings,
      resources: {
        requests: {
          cpu: '10m',
          memory: '24Mi',
        },
        limits: {
          cpu: '64m',
          memory: '128Mi',
        },
      },
      serviceMonitor: true,
    }),
  },
}
