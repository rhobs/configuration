local l = (import 'github.com/observatorium/deployments/components/loki.libsonnet');
local lc = (import './loki-caches.libsonnet');
local ja = (import './sidecars/jaeger-agent.libsonnet');

// JaegerAgent sidecar shared across components, thus instantiated outside components.
local jaegerAgentSidecar = (import './sidecars/jaeger-agent.libsonnet')({
  image: '${JAEGER_AGENT_IMAGE}:${JAEGER_AGENT_IMAGE_TAG}',
  collectorAddress: 'dns:///jaeger-collector-headless.${JAEGER_COLLECTOR_NAMESPACE}.svc:14250',
});

{
  local obs = self,

  lokiCaches+::
    lc +
    lc.withServiceMonitors {
      config+:: {
        local lcCfg = self,
        name: obs.config.name,
        namespace: '${NAMESPACE}',
        version: '${MEMCACHED_IMAGE_TAG}',
        image: '%s:%s' % ['${MEMCACHED_IMAGE}', lcCfg.version],
        commonLabels+: obs.config.commonLabels,
        exporterVersion: '${MEMCACHED_EXPORTER_IMAGE_TAG}',
        exporterImage: '%s:%s' % ['${MEMCACHED_EXPORTER_IMAGE}', lcCfg.exporterVersion],
        enableChuckCache: true,
        enableIndexQueryCache: true,
        enableResultsCache: true,
        replicas: {
          chunk_cache: 1,  // overwritten in observatorium-logs-template.libsonnet
          index_query_cache: 1,  // overwritten in observatorium-logs-template.libsonnet
          results_cache: 1,  // overwritten in observatorium-logs-template.libsonnet
        },
      },
      serviceMonitors: {
        chunk_cache: {
          metadata+: {
            name: 'observatorium-loki-chunk-cache',
            labels+: {
              prometheus: 'app-sre',
              'app.kubernetes.io/version':: 'hidden',
            },
          },
          spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
        },
        index_query_cache+: {
          metadata+: {
            name: 'observatorium-loki-index-query-cache',
            labels+: {
              prometheus: 'app-sre',
              'app.kubernetes.io/version':: 'hidden',
            },
          },
          spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
        },
        results_cache: {
          metadata+: {
            name: 'observatorium-loki-results-cache',
            labels+: {
              prometheus: 'app-sre',
              'app.kubernetes.io/version':: 'hidden',
            },
          },
          spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
        },
      },
    },

  loki+::
    l +
    l.withMemberList +
    l.withResources +
    l.withVolumeClaimTemplate +
    l.withChunkStoreCache +
    l.withIndexQueryCache +
    l.withResultsCache +
    l.withServiceMonitor {
      config+:: {
        local lConfig = self,
        name: obs.config.name + '-' + lConfig.commonLabels['app.kubernetes.io/name'],
        namespace: '${NAMESPACE}',
        version: '${LOKI_IMAGE_TAG}',
        image: '%s:%s' % ['${LOKI_IMAGE}', lConfig.version],
        commonLabels+: obs.config.commonLabels,
        objectStorageConfig: {
          secretName: '${LOKI_S3_SECRET}',
          bucketsKey: 'bucket',
          regionKey: 'aws_region',
          accessKeyIdKey: 'aws_access_key_id',
          secretAccessKeyKey: 'aws_secret_access_key',
        },
        replicas: {
          compactor: 1,  // Loki supports only a single compactor instance
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
        chunkCache: 'dns+%s.%s.svc.cluster.local:%s' % [
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
      },
      serviceMonitors: {
        compactor: {
          metadata+: {
            name: 'observatorium-loki-compactor',
            labels+: {
              prometheus: 'app-sre',
              'app.kubernetes.io/version':: 'hidden',
            },
          },
          spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
        },
        distributor: {
          metadata+: {
            name: 'observatorium-loki-distributor',
            labels+: {
              prometheus: 'app-sre',
              'app.kubernetes.io/version':: 'hidden',
            },
          },
          spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
        },
        querier: {
          metadata+: {
            name: 'observatorium-loki-querier',
            labels+: {
              prometheus: 'app-sre',
              'app.kubernetes.io/version':: 'hidden',
            },
          },
          spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
        },
        query_frontend: {
          metadata+: {
            name: 'observatorium-loki-query-frontend',
            labels+: {
              prometheus: 'app-sre',
              'app.kubernetes.io/version':: 'hidden',
            },
          },
          spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
        },
        ingester: {
          metadata+: {
            name: 'observatorium-loki-ingester',
            labels+: {
              prometheus: 'app-sre',
              'app.kubernetes.io/version':: 'hidden',
            },
          },
          spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
        },
      },
      defaultConfig+:: {
        tracing: {
          enabled: true,
        },
      },
      manifests+:: {
        [name]+:
          local m = super[name];
          if m.kind == 'Deployment' || m.kind == 'StatefulSet' then
            m {
              spec+: {
                template+: {
                  spec+: {
                    containers: [
                      c {
                        args+: [
                          '-distributor.replication-factor=${LOKI_REPLICATION_FACTOR}',
                          '-querier.worker-parallelism=${LOKI_QUERY_PARALLELISM}',
                        ],
                      }
                      for c in super.containers
                    ],
                  },
                },
              } + jaegerAgentSidecar.spec,
            }
          else
            m
        for name in std.objectFields(super.manifests)
      },
    },
}
