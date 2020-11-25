local t = (import 'github.com/thanos-io/kube-thanos/jsonnet/kube-thanos/thanos.libsonnet');
local trc = (import 'github.com/observatorium/thanos-receive-controller/jsonnet/lib/thanos-receive-controller.libsonnet');
local memcached = (import 'github.com/observatorium/deployments/components/memcached.libsonnet');
local telemeterRules = (import 'github.com/openshift/telemeter/jsonnet/telemeter/rules.libsonnet');

// This file contains all components as configured per upstream projects like kube-thanos etc.
// Please check observatorium-metrics-template.libsonnet for OpenShift Template specific overwrites.

// TODO(kakkoyun): Shouldn't anything that touches templates be moved to other file?
{
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

  compact::
    t.compact(thanosSharedConfig {
      name: 'observatorium-thanos-compact',
      commonLabels:: {
        'app.kubernetes.io/component': 'database-compactor',
        'app.kubernetes.io/instance': 'observatorium',
        'app.kubernetes.io/name': 'thanos-compact',
        'app.kubernetes.io/part-of': 'observatorium',
        'app.kubernetes.io/version': '${THANOS_IMAGE_TAG}',
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
      tracing: {},  // disable globally enabled tracing for compact
    }),

  rule::
    t.rule(thanosSharedConfig {
      name: 'observatorium-thanos-rule',
      commonLabels:: {
        'app.kubernetes.io/component': 'rule-evaluation-engine',
        'app.kubernetes.io/instance': 'observatorium',
        'app.kubernetes.io/name': 'thanos-rule',
        'app.kubernetes.io/part-of': 'observatorium',
        'app.kubernetes.io/version': '${THANOS_IMAGE_TAG}',
      },
      replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
      logLevel: '${THANOS_RULER_LOG_LEVEL}',
      serviceMonitor: true,
      queriers: [
        'dnssrv+_http._tcp.%s.${NAMESPACE}.svc.cluster.local' % 'observatorium-thanos-query',  // TODO: Replace with actual reference one query is moved
      ],
      rulesConfig: [
        {
          name: 'observatorium.rules',
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
          name: 'observatorium-rule',
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
  store:: {
    // Sharding should be moved upstream into kube-thanos.
    ['shard' + i]+:
      t.store(thanosSharedConfig {
        name: 'observatorium-thanos-store',
        replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
        logLevel: '${THANOS_STORE_LOG_LEVEL}',
        bucketCache: {
          type: 'memcached',
          config: {
            addresses: ['dnssrv+_client._tcp.observatorium-thanos-store-bucket-cache-memcached.${NAMESPACE}.svc'],
          },
        },
        indexCache: {
          type: 'memcached',
          config: {
            addresses: ['dnssrv+_client._tcp.observatorium-thanos-store-index-cache-memcached.${NAMESPACE}.svc'],
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
      })
    for i in std.range(0, storeShards - 1)
  },

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
    replicas: '${{THANOS_STORE_INDEX_CACHE_REPLICAS}}',
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
    replicas: '${{THANOS_STORE_BUCKET_CACHE_REPLICAS}}',
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

  query::
    t.query(thanosSharedConfig {
      name: 'observatorium-thanos-query',
      replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
      logLevel: '${THANOS_QUERIER_LOG_LEVEL}',
      lookbackDelta: '15m',
      queryTimeout: '15m',
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


  // TODO(kakkoyun): Clean up!
  // queryFrontend+: {
  //   image: obs.config.thanosImage,
  //   version: obs.config.thanosVersion,
  //   replicas: '${{THANOS_QUERY_FRONTEND_REPLICAS}}',
  //   resources: {
  //     requests: {
  //       cpu: '${THANOS_QUERY_FRONTEND_CPU_REQUEST}',
  //       memory: '${THANOS_QUERY_FRONTEND_MEMORY_REQUEST}',
  //     },
  //     limits: {
  //       cpu: '${THANOS_QUERY_FRONTEND_CPU_LIMIT}',
  //       memory: '${THANOS_QUERY_FRONTEND_MEMORY_LIMIT}',
  //     },
  //   },
  //   splitInterval: '${THANOS_QUERY_FRONTEND_SPLIT_INTERVAL}',
  //   maxRetries: '${THANOS_QUERY_FRONTEND_MAX_RETRIES}',
  //   logQueriesLongerThan: '${THANOS_QUERY_FRONTEND_LOG_QUERIES_LONGER_THAN}',
  //   fifoCache: {
  //     maxSize: '0',
  //     maxSizeItems: 2048,
  //     validity: '6h',
  //   },
  //   oauthProxy: {
  //     image: obs.config.oauthProxyImage,
  //     httpsPort: 9091,
  //     upstream: 'http://localhost:' + obs.queryFrontend.service.spec.ports[0].port,
  //     tlsSecretName: 'query-frontend-tls',
  //     sessionSecretName: 'query-frontend-proxy',
  //     sessionSecret: '',
  //     serviceAccountName: 'prometheus-telemeter',
  //     resources: {
  //       requests: {
  //         cpu: '${JAEGER_PROXY_CPU_REQUEST}',
  //         memory: '${JAEGER_PROXY_MEMORY_REQUEST}',
  //       },
  //       limits: {
  //         cpu: '${JAEGER_PROXY_CPU_LIMITS}',
  //         memory: '${JAEGER_PROXY_MEMORY_LIMITS}',
  //       },
  //     },
  //   },
  //   jaegerAgent: {
  //     image: obs.config.jaegerAgentImage,
  //     collectorAddress: obs.config.jaegerAgentCollectorAddress,
  //   },
  // },

  queryFrontend::
    t.queryFrontend(thanosSharedConfig {
      name: 'observatorium-thanos-query-frontend',
      replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
      downstreamURL: 'http',
      serviceMonitor: true,
      queryRangeCache: {
        type: 'in-memory',
        config+: {
          max_size: '0',
        },
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

  // TODO(kakkoyun): Clean up!
  // receivers+: {
  //   logLevel: '${THANOS_RECEIVE_LOG_LEVEL}',
  //   debug: '${THANOS_RECEIVE_DEBUG_ENV}',
  //   image: obs.config.thanosImage,
  //   version: obs.config.thanosVersion,
  //   objectStorageConfig: obs.config.objectStorageConfig.thanos,
  //   hashrings: obs.config.hashrings,
  //   replicas: '${{THANOS_RECEIVE_REPLICAS}}',
  //   replicationFactor: 3,
  //   resources: {
  //     requests: {
  //       cpu: '${THANOS_RECEIVE_CPU_REQUEST}',
  //       memory: '${THANOS_RECEIVE_MEMORY_REQUEST}',
  //     },
  //     limits: {
  //       cpu: '${THANOS_RECEIVE_CPU_LIMIT}',
  //       memory: '${THANOS_RECEIVE_MEMORY_LIMIT}',
  //     },
  //   },
  //   volumeClaimTemplate: {
  //     spec: {
  //       accessModes: ['ReadWriteOnce'],
  //       resources: {
  //         requests: {
  //           storage: '50Gi',
  //         },
  //       },
  //       storageClassName: '${STORAGE_CLASS}',
  //     },
  //   },
  //   jaegerAgent: {
  //     image: obs.config.jaegerAgentImage,
  //     collectorAddress: obs.config.jaegerAgentCollectorAddress,
  //   },
  // },

  local hashrings = [{
    hashring: 'default',
    tenants: [],
  }],

  receivers:: {
    [hashring.hashring]+:
      t.receive(thanosSharedConfig {
        name: 'observatorium-thanos-receive-default',
        replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
        replicationFactor: 3,
        hashringConfigMapName: 'observatorium-thanos-receive-controller-tenants-generated',
        logLevel: '${THANOS_RECEIVE_LOG_LEVEL}',
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
      })
    for hashring in hashrings
  },

  receiversService:: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'observatorium-thanos-receivers',
      namespace: thanosSharedConfig.namespace,
      labels: thanosSharedConfig.commonLabels { 'app.kubernetes.io/name': 'thanos-receive' },
    },
    spec: {
      selector: { 'app.kubernetes.io/name': 'thanos-receive' },
      ports: [
        { name: 'grpc', port: 10901, targetPort: 10901 },
        { name: 'http', port: 10902, targetPort: 10902 },
        { name: 'remote-write', port: 19291, targetPort: 19291 },
      ],
    },
  },

  receiveController:: trc({
    serviceMonitor: true,
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
  }),
}
