local t = (import 'github.com/thanos-io/kube-thanos/jsonnet/kube-thanos/thanos.libsonnet');
local trc = (import 'github.com/observatorium/thanos-receive-controller/jsonnet/lib/thanos-receive-controller.libsonnet');
local memcached = (import 'github.com/observatorium/observatorium/configuration/components/memcached.libsonnet');
local telemeterRules = (import 'github.com/openshift/telemeter/jsonnet/telemeter/rules.libsonnet');
local metricFederationRules = (import '../configuration/observatorium/metric-federation-rules.libsonnet');
local tenants = (import '../configuration/observatorium/tenants.libsonnet');

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
      alertmanagerName: 'observatorium-alertmanager',
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
      retentionResolutionRaw: '${THANOS_COMPACTOR_RETENTION_RESOLUTION_RAW}',
      retentionResolution5m: '${THANOS_COMPACTOR_RETENTION_RESOLUTION_FIVE_MINUTES}',
      retentionResolution1h: '${THANOS_COMPACTOR_RETENTION_RESOLUTION_ONE_HOUR}',
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
    local observatoriumRulesKey = 'observatorium.yaml',
    rule:: t.rule(thanosSharedConfig {
      name: 'observatorium-thanos-rule',
      commonLabels+:: {
        'app.kubernetes.io/part-of': 'observatorium',
        'app.kubernetes.io/instance': 'observatorium',
      },
      replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
      logLevel: '${THANOS_RULER_LOG_LEVEL}',
      serviceMonitor: true,
      alertmanagersURLs: ['dnssrv+_http._tcp.%s.%s.svc.cluster.local' % [thanosSharedConfig.alertmanagerName, thanosSharedConfig.namespace]],
      queriers: [
        'dnssrv+_http._tcp.%s.%s.svc.cluster.local' % [thanos.query.service.metadata.name, thanos.query.service.metadata.namespace],
      ],
      reloaderImage: '${CONFIGMAP_RELOADER_IMAGE}:${CONFIGMAP_RELOADER_IMAGE_TAG}',
      rulesConfig: [
        {
          name: observatoriumRules,
          key: observatoriumRulesKey,
        },
      ],
      ruleFiles: [
        '/etc/thanos/rules/rule-syncer/observatorium.yaml',
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
          [observatoriumRulesKey]: std.manifestYamlDoc({
            groups: std.map(function(group) {
              name: 'telemeter-' + group.name,
              interval: group.interval,
              rules: std.map(function(rule) rule {
                labels+: {
                  tenant_id: tenants.map.telemeter.id,
                },
              }, group.rules),
            }, telemeterRules.prometheus.recordingrules.groups),
          }),
        },
      },
    },

    local metricFederationRulesName = 'metric-federation-rules',
    metricFederationRule:: t.rule(thanosSharedConfig {
      name: 'observatorium-thanos-metric-federation-rule',
      commonLabels+:: {
        'app.kubernetes.io/part-of': 'observatorium',
        'app.kubernetes.io/instance': 'metric-federation',
      },
      replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
      logLevel: '${THANOS_RULER_LOG_LEVEL}',
      serviceMonitor: true,
      queriers: [
        'dnssrv+_http._tcp.%s.%s.svc.cluster.local' % [thanos.query.service.metadata.name, '${THANOS_QUERIER_NAMESPACE}'],
      ],
      reloaderImage: '${CONFIGMAP_RELOADER_IMAGE}:${CONFIGMAP_RELOADER_IMAGE_TAG}',
      rulesConfig: [
        {
          name: metricFederationRulesName,
          key: observatoriumRulesKey,
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
          name: metricFederationRulesName,
          annotations: {
            'qontract.recycle': 'true',
          },
          labels: {
            'app.kubernetes.io/instance': 'observatorium',
            'app.kubernetes.io/part-of': 'observatorium',
          },
        },
        data: {
          [observatoriumRulesKey]: std.manifestYamlDoc({
            groups: std.map(function(group) {
              name: 'telemeter-' + group.name,
              interval: group.interval,
              rules: std.map(function(rule) rule {
                labels+: {
                  tenant_id: tenants.map.telemeter.id,
                },
              }, group.rules),
            }, metricFederationRules.prometheus.recordingrules.groups),
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
          timeout: '2s',  // default: 500ms
          max_async_buffer_size: 10000000,  // default: 10_000
          max_async_concurrency: 1000,  // default: 20
          max_get_multi_batch_size: 20000,  // default: 0 - No batching.
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
          timeout: '2s',  // default: 500ms
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
        namespaceSelector: {
          // NOTICE:
          // When using the ${{PARAMETER_NAME}} syntax only a single parameter reference is allowed and leading/trailing characters are not permitted.
          // The resulting value will be unquoted unless, after substitution is performed, the result is not a valid json object.
          // If the result is not a valid json value, the resulting value will be quoted and treated as a standard string.
          matchNames: '${{NAMESPACES}}',
        },
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
    }) {
      serviceAccount+: {
        imagePullSecrets+: [{ name: 'quay.io' }],
      },
    },

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
    }) {
      serviceAccount+: {
        imagePullSecrets+: [{ name: 'quay.io' }],
      },
    },

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
      prefixHeader: 'X-Forwarded-Prefix',
      stores: [
        'dnssrv+_grpc._tcp.%s.%s.svc.cluster.local' % [service.metadata.name, service.metadata.namespace]
        for service in
          [thanos.rule.service] +
          [thanos.stores.shards[shard].service for shard in std.objectFields(thanos.stores.shards)] +
          [thanos.receivers.hashrings[hashring].service for hashring in std.objectFields(thanos.receivers.hashrings)]
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
    }) + {
      // This is a workaround for adding extra store for the metric federation
      // ruler service, which does not exist in the MST instance, so we cannot simply pass it
      // with the --store flag. Instead, we use the file service discovery. The extra store(s)
      // should be passed as an array string in THANOS_QUERIER_FILE_SD_TARGETS parameter.
      deployment+: {
        spec+: {
          template+: {
            spec+: {
              volumes+: [{
                configMap: {
                  name: 'thanos-query-file-sd',
                },
                name: 'file-sd',
              }],
              containers: [
                if x.name == 'thanos-query'
                then x {
                  args+: ['--store.sd-files=/etc/thanos/sd/file_sd.yaml'],
                  volumeMounts+: [{
                    mountPath: '/etc/thanos/sd',
                    name: 'file-sd',
                  }],
                }
                else x
                for x in super.containers
              ],
            },
          },
        },
      },
    } + {
      configmap: {
        apiVersion: 'v1',
        kind: 'ConfigMap',
        metadata: {
          name: 'thanos-query-file-sd',
          annotations: {
            'qontract.recycle': 'true',
          },
          labels: {
            'app.kubernetes.io/instance': 'observatorium',
            'app.kubernetes.io/part-of': 'observatorium',
          },
        },
        data: {
          'file_sd.yaml': '- targets: ${THANOS_QUERIER_FILE_SD_TARGETS}',
        },
      },
    },

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
        type: 'memcached',
        config: {
          addresses: ['dnssrv+_client._tcp.%s.%s.svc' % [thanos.queryFrontendCache.service.metadata.name, thanos.queryFrontendCache.service.metadata.namespace]],
          // Default Memcached Max Connection Limit is '3072', this is related to concurrency.
          max_idle_connections: 1300,  // default: 100 - For better performances, this should be set to a number higher than your peak parallel requests.
          timeout: '2s',  // default: 500ms
          max_async_buffer_size: 200000,  // default: 10_000
          max_async_concurrency: 200,  // default: 20
          max_get_multi_batch_size: 100,  // default: 0 - No batching.
          max_get_multi_concurrency: 1000,  // default: 100
          max_item_size: '64MiB',  // default: 1Mb
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
    queryFrontendCache:: memcached({
      local cfg = self,
      serviceMonitor: true,
      name: 'observatorium-thanos-query-range-cache-' + cfg.commonLabels['app.kubernetes.io/name'],
      namespace: thanosSharedConfig.namespace,
      commonLabels:: {
        'app.kubernetes.io/component': 'query-range-cache',
        'app.kubernetes.io/instance': 'observatorium',
        'app.kubernetes.io/name': 'memcached',
        'app.kubernetes.io/part-of': 'observatorium',
        'app.kubernetes.io/version': cfg.version,
      },

      version: '${MEMCACHED_IMAGE_TAG}',
      image: '%s:%s' % ['${MEMCACHED_IMAGE}', cfg.version],
      exporterVersion: '${MEMCACHED_EXPORTER_IMAGE_TAG}',
      exporterImage: '%s:%s' % ['${MEMCACHED_EXPORTER_IMAGE}', cfg.exporterVersion],
      connectionLimit: '${THANOS_QUERY_FRONTEND_QUERY_CACHE_CONNECTION_LIMIT}',
      memoryLimitMb: '${THANOS_QUERY_FRONTEND_QUERY_CACHE_MEMORY_LIMIT_MB}',
      maxItemSize: '64m',
      replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
      resources: {
        memcached: {
          requests: {
            cpu: '${THANOS_QUERY_FRONTEND_QUERY_CACHE_MEMCACHED_CPU_REQUEST}',
            memory: '${THANOS_QUERY_FRONTEND_QUERY_CACHE_MEMCACHED_MEMORY_REQUEST}',
          },
          limits: {
            cpu: '${THANOS_QUERY_FRONTEND_QUERY_CACHE_MEMCACHED_CPU_LIMIT}',
            memory: '${THANOS_QUERY_FRONTEND_QUERY_CACHE_MEMCACHED_MEMORY_LIMIT}',
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
    }) {
      serviceAccount+: {
        imagePullSecrets+: [{ name: 'quay.io' }],
      },
    },

    local hashrings = [
      {
        hashring: 'default',
        tenants: [],
      },
    ],

    receivers:: t.receiveHashrings(thanosSharedConfig {
      hashrings: hashrings,
      name: 'observatorium-thanos-receive',
      namespace: '${NAMESPACE}',
      commonLabels+:: {
        'app.kubernetes.io/instance': 'observatorium',
        'app.kubernetes.io/part-of': 'observatorium',
      },
      replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
      replicationFactor: 3,
      retention: '4d',
      replicaLabels: thanosSharedConfig.replicaLabels,
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
              storage: '${THANOS_RECEIVE_PVC_STORAGE}',
            },
          },
        },
      },
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
        namespaceSelector+: {
          // NOTICE:
          // When using the ${{PARAMETER_NAME}} syntax only a single parameter reference is allowed and leading/trailing characters are not permitted.
          // The resulting value will be unquoted unless, after substitution is performed, the result is not a valid json object.
          // If the result is not a valid json value, the resulting value will be quoted and treated as a standard string.
          matchNames: '${{NAMESPACES}}',
        },
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

    alertmanager:: {
      local cfg = {
        name: 'observatorium-alertmanager',
        namespace: thanosSharedConfig.namespace,
        image: 'quay.io/prometheus/alertmanager:main',
        persistentVolumeClaimName: 'alertmanager-data',
        routingConfigName: 'alertmanager-config',
        routingConfigFileName: 'alertmanager.yaml',
        port: 9093,
        commonLabels: {
          'app.kubernetes.io/component': 'alertmanager',
          'app.kubernetes.io/name': 'alertmanager',
          'app.kubernetes.io/part-of': 'observatorium',
        },
      },
      service: {
        apiVersion: 'v1',
        kind: 'Service',
        metadata: {
          name: cfg.name,
          namespace: cfg.namespace,
          labels: { 'app.kubernetes.io/name': cfg.name },
        },
        spec: {
          ports: [
            { name: 'http', targetPort: cfg.port, port: cfg.port },
          ],
          selector: cfg.commonLabels,
        },
      },

      volumeClaim: {
        apiVersion: 'v1',
        kind: 'PersistentVolumeClaim',
        metadata: {
          name: cfg.persistentVolumeClaimName,
          namespace: cfg.namespace,
          labels: { 'app.kubernetes.io/name': cfg.name },
        },
        spec: {
          accessModes: ['ReadWriteOnce'],
          storageClassName: 'gp2',
          resources: {
            requests: {
              storage: '10Gi',
            },
          },
        },
      },

      statefulSet: {
        apiVersion: 'apps/v1',
        kind: 'StatefulSet',
        metadata: {
          name: cfg.name,
          namespace: cfg.namespace,
          labels: cfg.commonLabels,
        },
        spec: {
          replicas: 1,
          selector: { matchLabels: cfg.commonLabels },
          strategy: {
            rollingUpdate: {
              maxSurge: 0,
              maxUnavailable: 1,
            },
          },
          template: {
            metadata: {
              labels: cfg.commonLabels,
            },
            spec: {
              containers: [{
                name: cfg.name,
                image: cfg.image,
                args: [
                  '--config.file=/etc/config/' + cfg.routingConfigFileName,
                  '--storage.path="data/"',
                  '--web.listen-address=:' + cfg.port,
                  '--cluster.listen-address=',  // Disabled cluster gossiping while we only have one replica
                ],
                ports: [
                  {
                    name: 'http',
                    containerPort: cfg.port,
                  },
                ],
                volumeMounts: [
                  { name: 'alertmanager-data', mountPath: '/data', readOnly: false },
                  { name: cfg.routingConfigName, mountPath: '/etc/config', readOnly: true },
                ],
                livenessProbe: { failureThreshold: 4, periodSeconds: 30, httpGet: {
                  scheme: 'HTTP',
                  port: cfg.port,
                  path: '/',
                } },
                readinessProbe: { failureThreshold: 3, periodSeconds: 30, initialDelaySeconds: 10, httpGet: {
                  scheme: 'HTTP',
                  port: cfg.port,
                  path: '/',
                } },
                resources: {
                  requests: { cpu: '1', memory: '1Gi' },
                  limits: { cpu: '4', memory: '4Gi' },
                },
              }],
              volumes: [
                { name: cfg.persistentVolumeClaimName, persistentVolumeClaim: { claimName: cfg.persistentVolumeClaimName } },
                { name: cfg.routingConfigName, secret: { secretName: cfg.routingConfigName } },
              ],
            },
          },
        },
      },

      serviceMonitor: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata+: {
          name: cfg.name,
          namespace: cfg.namespace,
          labels: cfg.commonLabels,
        },
        spec: {
          selector: { matchLabels: cfg.commonLabels },
          endpoints: [
            { port: 'http' },
          ],
          namespaceSelector: { matchNames: ['${NAMESPACE}'] },
        },
      },
    },

    manifests+: {
      'stores-service-monitor': thanos.storesServiceMonitor,
      'receivers-service-monitor': thanos.receiversServiceMonitor,
    } + {
      ['store-index-cache-' + name]: thanos.storeIndexCache[name]
      for name in std.objectFields(thanos.storeIndexCache)
    } + {
      ['store-bucket-cache-' + name]: thanos.storeBucketCache[name]
      for name in std.objectFields(thanos.storeBucketCache)
    } + {
      ['metric-federation-rule-' + name]: thanos.metricFederationRule[name]
      for name in std.objectFields(thanos.metricFederationRule)
    } + {
      ['observatorium-alertmanager-' + name]: thanos.alertmanager[name]
      for name in std.objectFields(thanos.alertmanager)
    },
  },
}
