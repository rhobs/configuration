local t = (import 'github.com/thanos-io/kube-thanos/jsonnet/kube-thanos/thanos.libsonnet');
local trc = (import 'github.com/observatorium/thanos-receive-controller/jsonnet/lib/thanos-receive-controller.libsonnet');
local api = (import 'github.com/observatorium/observatorium/jsonnet/lib/observatorium-api.libsonnet');
local ja = (import 'github.com/observatorium/deployments/components/jaeger-agent.libsonnet');
local l = (import 'github.com/observatorium/deployments/components/loki.libsonnet');
local lc = (import 'github.com/observatorium/deployments/components/loki-caches.libsonnet');
local mc = (import 'github.com/observatorium/deployments/components/memcached.libsonnet');
local up = (import 'github.com/observatorium/deployments/components/up.libsonnet');
local gubernator = (import 'github.com/observatorium/deployments/components/gubernator.libsonnet');
local telemeterRules = (import 'github.com/openshift/telemeter/jsonnet/telemeter/rules.libsonnet');


(import 'github.com/observatorium/deployments/components/observatorium.libsonnet') {
  local obs = self,

  local s3EnvVars = [
    {
      name: 'AWS_ACCESS_KEY_ID',
      valueFrom: {
        secretKeyRef: {
          key: 'aws_access_key_id',
          name: '${THANOS_S3_SECRET}',
        },
      },
    },
    {
      name: 'AWS_SECRET_ACCESS_KEY',
      valueFrom: {
        secretKeyRef: {
          key: 'aws_secret_access_key',
          name: '${THANOS_S3_SECRET}',
        },
      },
    },
  ],

  compact+::
    t.compact.withVolumeClaimTemplate +
    t.compact.withResources +
    t.compact.withServiceMonitor {
      serviceMonitor+: {
        metadata+: {
          name: 'observatorium-thanos-compactor',
          labels+: {
            prometheus: 'app-sre',
            'app.kubernetes.io/version':: 'hidden',
          },
        },
        spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
      },
    } +
    (import 'github.com/observatorium/deployments/components/oauth-proxy.libsonnet') +
    (import 'github.com/observatorium/deployments/components/oauth-proxy.libsonnet').statefulSetMixin {
      statefulSet+: {
        spec+: {
          template+: {
            spec+: {
              containers: [
                if c.name == 'thanos-compact' then c {
                  env+: s3EnvVars,
                } else c
                for c in super.containers
              ],
            },
          },
        },
      },
    },

  thanosReceiveController+::
    trc.withResources +
    trc.withServiceMonitor {
      serviceMonitor+: {
        metadata+: {
          name: 'observatorium-thanos-receive-controller',
          labels+: {
            prometheus: 'app-sre',
            'app.kubernetes.io/version':: 'hidden',
          },
        },

        spec+: {
          selector+: {
            // TODO: Remove once fixed upstream
            matchLabels+: {
              'app.kubernetes.io/version':: 'hidden',
            },
          },
          namespaceSelector+: { matchNames: ['${NAMESPACE}'] },
        },
      },
    },

  rule+::
    local nameResource = obs.config.name + '-rule';
    local nameFile = obs.config.name + '.yaml';
    t.rule.withResources +
    t.rule.withServiceMonitor {
      serviceMonitor+: {
        metadata+: {
          name: 'observatorium-thanos-rule',
          labels+: {
            prometheus: 'app-sre',
            'app.kubernetes.io/version':: 'hidden',
          },
        },
        spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
      },
    } +
    ja.statefulSetMixin {
      statefulSet+: {
        spec+: {
          template+: {
            spec+: {
              containers: [
                if c.name == 'thanos-rule' then c {
                  env+: s3EnvVars,
                  args+: ['--rule-file=/var/thanos/config/rules/' + nameFile],
                  volumeMounts+: [{
                    name: nameResource,
                    mountPath: '/var/thanos/config/rules',
                  }],
                } else c
                for c in super.containers
              ],
              volumes+: [{
                name: nameResource,
                configMap: {
                  name: nameResource,
                },
              }],
            },
          },
        },
      },
    } + {
      configmap:
        local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';
        local configmap = k.core.v1.configMap;
        configmap.new() +
        configmap.mixin.metadata.withName(nameResource) +
        configmap.mixin.metadata.withLabels(obs.config.commonLabels) +
        configmap.mixin.metadata.withAnnotations({
          'qontract.recycle': 'true',
        }) +
        configmap.withData({
          [nameFile]: std.manifestYamlDoc({
            groups: [{
              name: 'observatorium.rules',
              interval: '3m',
              rules: telemeterRules.prometheus.recordingrules.groups[0].rules,
            }],
          }),
        }),
    },

  store+:: {
    ['shard' + i]+:
      t.store.withVolumeClaimTemplate +
      t.store.withResources + {
        config+:: {
          memcached+: {
            local memcached = obs.store['shard' + i].config.memcached,
            indexCache: memcached {
              addresses: ['dnssrv+_client._tcp.%s.%s.svc' % [obs.storeIndexCache.service.metadata.name, obs.storeIndexCache.service.metadata.namespace]],
            },
            bucketCache: memcached {
              addresses: ['dnssrv+_client._tcp.%s.%s.svc' % [obs.storeBucketCache.service.metadata.name, obs.storeBucketCache.service.metadata.namespace]],
            },
          },
        },
      } +
      ja.statefulSetMixin {
        statefulSet+: {
          spec+: {
            template+: {
              spec+: {
                containers: [
                  if c.name == 'thanos-store' then c {
                    env+: s3EnvVars,
                  } else c
                  for c in super.containers
                ],
              },
            },
          },
        },
      }
    for i in std.range(0, obs.config.store.shards - 1)
  },

  storeMonitor: t.store.withServiceMonitor {
    config:: obs.store.shard0.config {
      commonLabels+: {
        'store.observatorium.io/shard':: 'hidden',
      },
      podLabelSelector+: {
        'store.observatorium.io/shard':: 'hidden',
      },
    },
    serviceMonitor+: {
      metadata+: {
        namespace:: 'hidden',
        name: 'observatorium-thanos-store-shard',
        labels+: {
          prometheus: 'app-sre',
          'app.kubernetes.io/version':: 'hidden',

        },
      },
      spec+: {
        namespaceSelector+: { matchNames: ['${NAMESPACE}'] },
      },
    },
  },

  storeCache:: {},

  storeIndexCache::
    mc +
    mc.withResources +
    mc.withServiceMonitor {
      serviceMonitor+: {
        metadata+: {
          name: 'observatorium-thanos-store-index-cache',
          labels+: {
            prometheus: 'app-sre',
            'app.kubernetes.io/version':: 'hidden',
          },
        },
        spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
      },
    } + {
      config+:: {
        local cfg = self,
        name: obs.config.name + '-thanos-store-index-cache-' + cfg.commonLabels['app.kubernetes.io/name'],
        namespace: obs.config.namespace,
        commonLabels+:: obs.config.commonLabels {
          'app.kubernetes.io/component': 'store-index-cache',
        },
      },
      statefulSet+: {
        spec+: {
          volumeClaimTemplates:: null,
        },
      },
    },

  storeBucketCache::
    mc +
    mc.withResources +
    mc.withServiceMonitor {
      serviceMonitor+: {
        metadata+: {
          name: 'observatorium-thanos-store-bucket-cache',
          labels+: {
            prometheus: 'app-sre',
            'app.kubernetes.io/version':: 'hidden',
          },
        },
        spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
      },
    } + {
      config+:: {
        local cfg = self,
        name: obs.config.name + '-thanos-store-bucket-cache-' + cfg.commonLabels['app.kubernetes.io/name'],
        namespace: obs.config.namespace,
        commonLabels+:: obs.config.commonLabels {
          'app.kubernetes.io/component': 'store-bucket-cache',
        },
      },
      statefulSet+: {
        spec+: {
          volumeClaimTemplates:: null,
        },
      },
    },

  receivers+:: {
    [hashring.hashring]+:
      t.receive.withVolumeClaimTemplate +
      t.receive.withPodDisruptionBudget +
      t.receive.withResources + {
        statefulSet+: {
          spec+: {
            template+: {
              spec+: {
                containers: [
                  if c.name == 'thanos-receive' then c {
                    args+: [
                      '--receive.default-tenant-id=FB870BF3-9F3A-44FF-9BF7-D7A047A52F43',
                    ],
                    env+: s3EnvVars,
                  } + {
                    args: [
                      if std.startsWith(a, '--tsdb.path') then '--tsdb.path=${THANOS_RECEIVE_TSDB_PATH}'
                      else if std.startsWith(a, '--tsdb.retention') then '--tsdb.retention=4d' else a
                      for a in super.args
                    ],
                  } else c
                  for c in super.containers
                ],
              },
            },
          },
        },
      } + ja.statefulSetMixin
    for hashring in obs.config.hashrings
  },

  receiversMonitor:: t.store.withServiceMonitor {
    config:: obs.receivers.default.config,
    serviceMonitor+: {
      metadata+: {
        labels+: {
          prometheus: 'app-sre',
          'app.kubernetes.io/version':: 'hidden',
        },
        namespace:: 'hidden',
      },
      spec+: {
        namespaceSelector+: { matchNames: ['${NAMESPACE}'] },
      },
    },
  },

  query+::
    t.query.withResources +
    t.query.withServiceMonitor +
    t.query.withLookbackDelta + {
      serviceMonitor+: {
        metadata+: {
          name: 'observatorium-thanos-querier',
          labels+: {
            prometheus: 'app-sre',
            'app.kubernetes.io/version':: 'hidden',
          },
        },
        spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
      },
    } +
    (import 'github.com/observatorium/deployments/components/oauth-proxy.libsonnet') +
    (import 'github.com/observatorium/deployments/components/oauth-proxy.libsonnet').deploymentMixin +
    ja.deploymentMixin,

  queryFrontend+::
    t.queryFrontend.withResources +
    t.queryFrontend.withServiceMonitor {
      serviceMonitor+: {
        metadata+: {
          name: 'observatorium-thanos-query-frontend',
          labels+: {
            prometheus: 'app-sre',
            'app.kubernetes.io/version':: 'hidden',
          },
        },
        spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
      },
    } +
    (import 'github.com/observatorium/deployments/components/oauth-proxy.libsonnet') +
    (import 'github.com/observatorium/deployments/components/oauth-proxy.libsonnet').deploymentMixin +
    ja.deploymentMixin,

  gubernator+:: gubernator.withServiceMonitor {
    serviceMonitor+: {
      metadata+: {
        name: 'observatorium-gubernator',
        labels+: {
          prometheus: 'app-sre',
          'app.kubernetes.io/version':: 'hidden',
        },
      },
      spec+: {
        selector+: {
          matchLabels+: {
            'app.kubernetes.io/version':: 'hidden',
          },
        },
        namespaceSelector+: { matchNames: ['${NAMESPACE}'] },
      },
    },
  },

  api+::
    api.withResources +
    api.withServiceMonitor {
      local api = self,
      serviceMonitor+: {
        metadata+: {
          name: 'observatorium-api',
          labels+: {
            prometheus: 'app-sre',
            'app.kubernetes.io/version':: 'hidden',
          },
        },
        spec+: {
          selector+: {
            matchLabels+: {
              'app.kubernetes.io/version':: 'hidden',
            },
          },
          namespaceSelector+: { matchNames: ['${NAMESPACE}'] },
        },
      },
    } + (if obs['opa-ams'] != null then {
           deployment+: {
             spec+: {
               template+: {
                 spec+: {
                   containers+: [
                     {
                       name: 'opa-ams',
                       image: obs['opa-ams'].config.image,
                       args: [
                         '--web.listen=127.0.0.1:%s' % obs['opa-ams'].config.ports.api,
                         '--web.internal.listen=0.0.0.0:%s' % obs['opa-ams'].config.ports.metrics,
                         '--web.healthchecks.url=http://127.0.0.1:%s' % obs['opa-ams'].config.ports.api,
                         '--log.level=warn',
                         '--ams.url=' + obs['opa-ams'].config.amsURL,
                         '--resource-type-prefix=' + obs['opa-ams'].config.resourceTypePrefix,
                         '--oidc.client-id=$(CLIENT_ID)',
                         '--oidc.client-secret=$(CLIENT_SECRET)',
                         '--oidc.issuer-url=$(ISSUER_URL)',
                         '--opa.package=' + obs['opa-ams'].config.opaPackage,
                       ] + (
                         if std.objectHas(obs['opa-ams'].config, 'memcached') then
                           [
                             '--memcached=' + obs['opa-ams'].config.memcached,
                           ]
                         else []
                       ) + (
                         if std.objectHas(obs['opa-ams'].config, 'memcachedExpire') then
                           [
                             '--memcached.expire=' + obs['opa-ams'].config.memcachedExpire,
                           ]
                         else []
                       ) + (
                         if std.objectHas(obs['opa-ams'].config, 'mappings') then
                           [
                             '--ams.mappings=%s=%s' % [tenant, obs['opa-ams'].config.mappings[tenant]]
                             for tenant in std.objectFields(obs['opa-ams'].config.mappings)
                           ]
                         else []
                       ),
                       env: [
                         {
                           name: 'ISSUER_URL',
                           valueFrom: {
                             secretKeyRef: {
                               name: obs['opa-ams'].config.secretName,
                               key: obs['opa-ams'].config.issuerURLKey,
                             },
                           },
                         },
                         {
                           name: 'CLIENT_ID',
                           valueFrom: {
                             secretKeyRef: {
                               name: obs['opa-ams'].config.secretName,
                               key: obs['opa-ams'].config.clientIDKey,
                             },
                           },
                         },
                         {
                           name: 'CLIENT_SECRET',
                           valueFrom: {
                             secretKeyRef: {
                               name: obs['opa-ams'].config.secretName,
                               key: obs['opa-ams'].config.clientSecretKey,
                             },
                           },
                         },
                       ],
                       ports: [
                         {
                           name: 'opa-ams-' + name,
                           containerPort: obs['opa-ams'].config.ports[name],
                         }
                         for name in std.objectFields(obs['opa-ams'].config.ports)
                       ],
                       livenessProbe: {
                         failureThreshold: 10,
                         periodSeconds: 30,
                         httpGet: {
                           path: '/live',
                           port: obs['opa-ams'].config.ports.metrics,
                           scheme: 'HTTP',
                         },
                       },
                       readinessProbe: {
                         failureThreshold: 12,
                         periodSeconds: 5,
                         httpGet: {
                           path: '/ready',
                           port: obs['opa-ams'].config.ports.metrics,
                           scheme: 'HTTP',
                         },
                       },
                       resources: obs['opa-ams'].config.resources,
                     },
                   ],
                 },
               },
             },
           },

           service+: {
             spec+: {
               ports+: [
                 {
                   name: 'opa-ams-' + name,
                   port: obs['opa-ams'].config.ports[name],
                   targetPort: obs['opa-ams'].config.ports[name],
                 }
                 for name in std.objectFields(obs['opa-ams'].config.ports)
               ],
             },
           },

           serviceMonitor+: {
             spec+: {
               endpoints+: [
                 { port: 'opa-ams-metrics' },
               ],
             },
           },
         } else {}),

  up+:: up {
    serviceMonitor+: {
      metadata+: {
        name: 'observatorium-up',
        labels+: {
          prometheus: 'app-sre',
          'app.kubernetes.io/version':: 'hidden',
        },
      },
      spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
    },
  },

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
          chunk_cache: '${{LOKI_CHUNK_CACHE_REPLICAS}}',
          index_query_cache: '${{LOKI_INDEX_QUERY_CACHE_REPLICAS}}',
          results_cache: '${{LOKI_RESULTS_CACHE_REPLICAS}}',
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
        queryConcurrency: 32,
        // Parallelism based on formular:
        // LOKI_QUERIER_CONCURRENCY / LOKI_QUERY_FRONTEND_REPLICAS
        queryParallelism: 16,
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
            m + ja.specMixin {
              config+: {
                jaegerAgent: {
                  image: obs.config.jaegerAgentImage,
                  collectorAddress: obs.config.jaegerAgentCollectorAddress,
                },
              },
            }
          else
            m
        for name in std.objectFields(super.manifests)
      },
    },

  manifests+:: {
    ['observatorium-up-' + name]: obs.up[name]
    for name in std.objectFields(obs.up)
    if obs.up[name] != null
  },
} + {
  local obs = self,

  config+:: {
    name: 'observatorium',
    namespace:: '${NAMESPACE}',
    thanosImage:: '${THANOS_IMAGE}:${THANOS_IMAGE_TAG}',
    thanosVersion: '${THANOS_IMAGE_TAG}',
    oauthProxyImage:: '${PROXY_IMAGE}:${PROXY_IMAGE_TAG}',
    jaegerAgentImage:: '${JAEGER_AGENT_IMAGE}:${JAEGER_AGENT_IMAGE_TAG}',
    jaegerAgentCollectorAddress:: 'dns:///jaeger-collector-headless.$(NAMESPACE).svc:14250',
    objectStorageConfig:: {
      thanos: {
        name: '${THANOS_CONFIG_SECRET}',
        key: 'thanos.yaml',
      },
      loki: {
        secretName: '${LOKI_S3_SECRET}',
        bucketsKey: 'buckets',
        regionKey: 'region',
        accessKeyIdKey: 'aws_access_key_id',
        secretAccessKeyKey: 'aws_secret_access_key',
      },
    },

    hashrings: [
      {
        hashring: 'default',
        tenants: [
          // Match all for now
          // 'foo',
          // 'bar',
        ],
      },
    ],

    compact+: {
      logLevel: '${THANOS_COMPACTOR_LOG_LEVEL}',
      image: obs.config.thanosImage,
      version: obs.config.thanosVersion,
      objectStorageConfig: obs.config.objectStorageConfig.thanos,
      retentionResolutionRaw: '14d',
      retentionResolution5m: '1s',
      retentionResolution1h: '1s',
      replicas: '${{THANOS_COMPACTOR_REPLICAS}}',
      resources: {
        requests: {
          cpu: '${THANOS_COMPACTOR_CPU_REQUEST}',
          memory: '${THANOS_COMPACTOR_MEMORY_REQUEST}',
        },
        limits: {
          cpu: '${THANOS_COMPACTOR_CPU_LIMIT}',
          memory: '${THANOS_COMPACTOR_MEMORY_LIMIT}',
        },
      },
      oauthProxy: {
        image: obs.config.oauthProxyImage,
        httpsPort: 8443,
        upstream: 'http://localhost:' + obs.compact.service.spec.ports[0].port,
        tlsSecretName: 'compact-tls',
        sessionSecretName: 'compact-proxy',
        sessionSecret: '',
        serviceAccountName: 'prometheus-telemeter',
        resources: {
          requests: {
            cpu: '${JAEGER_PROXY_CPU_REQUEST}',
            memory: '${JAEGER_PROXY_MEMORY_REQUEST}',
          },
          limits: {
            cpu: '${JAEGER_PROXY_CPU_LIMITS}',
            memory: '${JAEGER_PROXY_MEMORY_LIMITS}',
          },
        },
      },
      volumeClaimTemplate: {
        spec: {
          accessModes: ['ReadWriteOnce'],
          resources: {
            requests: {
              storage: '${THANOS_COMPACTOR_PVC_REQUEST}',
            },
          },
          storageClassName: '${STORAGE_CLASS}',
        },
      },
    },

    thanosReceiveController+: {
      image: '${THANOS_RECEIVE_CONTROLLER_IMAGE}:${THANOS_RECEIVE_CONTROLLER_IMAGE_TAG}',
      version: '${THANOS_RECEIVE_CONTROLLER_IMAGE_TAG}',
      hashrings: obs.config.hashrings,
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
      jaegerAgent: {
        image: obs.config.jaegerAgentImage,
        collectorAddress: obs.config.jaegerAgentCollectorAddress,
      },
    },

    receivers+: {
      logLevel: '${THANOS_RECEIVE_LOG_LEVEL}',
      debug: '${THANOS_RECEIVE_DEBUG_ENV}',
      image: obs.config.thanosImage,
      version: obs.config.thanosVersion,
      objectStorageConfig: obs.config.objectStorageConfig.thanos,
      hashrings: obs.config.hashrings,
      replicas: '${{THANOS_RECEIVE_REPLICAS}}',
      replicationFactor: 3,
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
          resources: {
            requests: {
              storage: '50Gi',
            },
          },
          storageClassName: '${STORAGE_CLASS}',
        },
      },
      jaegerAgent: {
        image: obs.config.jaegerAgentImage,
        collectorAddress: obs.config.jaegerAgentCollectorAddress,
      },
    },

    rule+: {
      logLevel: '${THANOS_RULER_LOG_LEVEL}',
      image: obs.config.thanosImage,
      version: obs.config.thanosVersion,
      objectStorageConfig: obs.config.objectStorageConfig.thanos,
      replicas: '${{THANOS_RULER_REPLICAS}}',
      resources: {
        requests: {
          cpu: '${THANOS_RULER_CPU_REQUEST}',
          memory: '${THANOS_RULER_MEMORY_REQUEST}',
        },
        limits: {
          cpu: '${THANOS_RULER_CPU_LIMIT}',
          memory: '${THANOS_RULER_MEMORY_LIMIT}',
        },
      },
      jaegerAgent: {
        image: obs.config.jaegerAgentImage,
        collectorAddress: obs.config.jaegerAgentCollectorAddress,
      },
    },

    store+: {
      logLevel: '${THANOS_STORE_LOG_LEVEL}',
      image: obs.config.thanosImage,
      version: obs.config.thanosVersion,
      shards: 3,
      objectStorageConfig: obs.config.objectStorageConfig.thanos,
      replicas: '${{THANOS_STORE_REPLICAS}}',
      memcached+: {
        indexCache+: {
          // Default Memcached Max Connection Limit is '3072', this is related to concurrency.
          maxIdleConnections: 1300,  // default: 100 - For better performances, this should be set to a number higher than your peak parallel requests.
          timeout: '400ms',  // default: 500ms
          maxAsyncBufferSize: 200000,  // default: 10_000
          maxAsyncConcurrency: 200,  // default: 20
          maxGetMultiBatchSize: 100,  // default: 0 - No batching.
          maxGetMultiConcurrency: 1000,  // default: 100
          maxItemSize: '5MiB',  // default: 1Mb
        },
        bucketCache+: {
          // Default Memcached Max Connection Limit is '3072', this is related to concurrency.
          maxIdleConnections: 1100,  // default: 100 - For better performances, this should be set to a number higher than your peak parallel requests.
          timeout: '400ms',  // default: 500ms
          maxAsyncBufferSize: 25000,  // default: 10_000
          maxAsyncConcurrency: 50,  // default: 20
          maxGetMultiBatchSize: 100,  // default: 0 - No batching.
          maxGetMultiConcurrency: 1000,  // default: 100
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
      volumeClaimTemplate: {
        spec: {
          accessModes: ['ReadWriteOnce'],
          resources: {
            requests: {
              storage: '50Gi',
            },
          },
          storageClassName: '${STORAGE_CLASS}',
        },
      },
      jaegerAgent: {
        image: obs.config.jaegerAgentImage,
        collectorAddress: obs.config.jaegerAgentCollectorAddress,
      },
    },

    storeIndexCache+: {
      local scConfig = self,
      version: '${MEMCACHED_IMAGE_TAG}',
      image: '%s:%s' % ['${MEMCACHED_IMAGE}', scConfig.version],
      exporterVersion: '${MEMCACHED_EXPORTER_IMAGE_TAG}',
      exporterImage: '%s:%s' % ['${MEMCACHED_EXPORTER_IMAGE}', scConfig.exporterVersion],
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
    },

    storeBucketCache+: {
      local scConfig = self,
      version: '${MEMCACHED_IMAGE_TAG}',
      image: '%s:%s' % ['${MEMCACHED_IMAGE}', scConfig.version],
      exporterVersion: '${MEMCACHED_EXPORTER_IMAGE_TAG}',
      exporterImage: '%s:%s' % ['${MEMCACHED_EXPORTER_IMAGE}', scConfig.exporterVersion],
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
    },

    query+: {
      logLevel: '${THANOS_QUERIER_LOG_LEVEL}',
      image: obs.config.thanosImage,
      version: obs.config.thanosVersion,
      replicas: '${{THANOS_QUERIER_REPLICAS}}',
      lookbackDelta: '15m',
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
      oauthProxy: {
        image: obs.config.oauthProxyImage,
        httpsPort: 9091,
        upstream: 'http://localhost:' + obs.query.service.spec.ports[1].port,
        tlsSecretName: 'query-tls',
        sessionSecretName: 'query-proxy',
        sessionSecret: '',
        serviceAccountName: 'prometheus-telemeter',
        resources: {
          requests: {
            cpu: '${JAEGER_PROXY_CPU_REQUEST}',
            memory: '${JAEGER_PROXY_MEMORY_REQUEST}',
          },
          limits: {
            cpu: '${JAEGER_PROXY_CPU_LIMITS}',
            memory: '${JAEGER_PROXY_MEMORY_LIMITS}',
          },
        },
      },
      jaegerAgent: {
        image: obs.config.jaegerAgentImage,
        collectorAddress: obs.config.jaegerAgentCollectorAddress,
      },
    },

    queryFrontend+: {
      image: obs.config.thanosImage,
      version: obs.config.thanosVersion,
      replicas: '${{THANOS_QUERY_FRONTEND_REPLICAS}}',
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
      splitInterval: '${THANOS_QUERY_FRONTEND_SPLIT_INTERVAL}',
      maxRetries: '${THANOS_QUERY_FRONTEND_MAX_RETRIES}',
      logQueriesLongerThan: '${THANOS_QUERY_FRONTEND_LOG_QUERIES_LONGER_THAN}',
      fifoCache: {
        maxSize: '0',
        maxSizeItems: 2048,
        validity: '6h',
      },
      oauthProxy: {
        image: obs.config.oauthProxyImage,
        httpsPort: 9091,
        upstream: 'http://localhost:' + obs.queryFrontend.service.spec.ports[0].port,
        tlsSecretName: 'query-frontend-tls',
        sessionSecretName: 'query-frontend-proxy',
        sessionSecret: '',
        serviceAccountName: 'prometheus-telemeter',
        resources: {
          requests: {
            cpu: '${JAEGER_PROXY_CPU_REQUEST}',
            memory: '${JAEGER_PROXY_MEMORY_REQUEST}',
          },
          limits: {
            cpu: '${JAEGER_PROXY_CPU_LIMITS}',
            memory: '${JAEGER_PROXY_MEMORY_LIMITS}',
          },
        },
      },
      jaegerAgent: {
        image: obs.config.jaegerAgentImage,
        collectorAddress: obs.config.jaegerAgentCollectorAddress,
      },
    },

    gubernator+: {
      local guber = self,
      version: '${GUBERNATOR_IMAGE_TAG}',
      image: '%s:%s' % ['${GUBERNATOR_IMAGE}', guber.version],
      replicas: '${{GUBERNATOR_REPLICAS}}',
      resources: {
        requests: {
          cpu: '${GUBERNATOR_CPU_REQUEST}',
          memory: '${GUBERNATOR_MEMORY_REQUEST}',
        },
        limits: {
          cpu: '${GUBERNATOR_CPU_LIMIT}',
          memory: '${GUBERNATOR_MEMORY_LIMIT}',
        },
      },
    },

    api+: {
      local api = self,
      version: '${OBSERVATORIUM_API_IMAGE_TAG}',
      image: '%s:%s' % ['${OBSERVATORIUM_API_IMAGE}', api.version],
      replicas: '${{OBSERVATORIUM_API_REPLICAS}}',
      logs: {
        readEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
          obs.loki.manifests['query-frontend-http-service'].metadata.name,
          obs.loki.manifests['query-frontend-http-service'].metadata.namespace,
          obs.loki.manifests['query-frontend-http-service'].spec.ports[0].port,
        ],
        tailEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
          obs.loki.manifests['querier-http-service'].metadata.name,
          obs.loki.manifests['querier-http-service'].metadata.namespace,
          obs.loki.manifests['querier-http-service'].spec.ports[0].port,
        ],
        writeEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
          obs.loki.manifests['distributor-http-service'].metadata.name,
          obs.loki.manifests['distributor-http-service'].metadata.namespace,
          obs.loki.manifests['distributor-http-service'].spec.ports[0].port,
        ],
      },
      metrics: {
        readEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
          obs.queryFrontend.service.metadata.name,
          obs.queryFrontend.service.metadata.namespace,
          obs.queryFrontend.service.spec.ports[0].port,
        ],
        writeEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
          obs.receiveService.metadata.name,
          obs.receiveService.metadata.namespace,
          obs.receiveService.spec.ports[2].port,
        ],
      },
      rateLimiter: {
        grpcAddress: '%s.%s.svc.cluster.local:%d' % [
          obs.gubernator.service.metadata.name,
          obs.gubernator.service.metadata.namespace,
          obs.gubernator.service.spec.ports[1].port,
        ],
      },
      rbac: {
        roles: [
          {
            name: 'rhobs',
            resources: [
              'metrics',
              'logs',
            ],
            tenants: [
              'rhobs',
            ],
            permissions: [
              'read',
              'write',
            ],
          },
          {
            name: 'telemeter-write',
            resources: [
              'metrics',
            ],
            tenants: [
              'telemeter',
            ],
            permissions: [
              'write',
            ],
          },
          {
            name: 'dptp-write',
            resources: [
              'logs',
            ],
            tenants: [
              'dptp',
            ],
            permissions: [
              'write',
            ],
          },
          {
            name: 'dptp-read',
            resources: [
              'logs',
            ],
            tenants: [
              'dptp',
            ],
            permissions: [
              'read',
            ],
          },
        ],
        roleBindings: [
          {
            name: 'rhobs',
            roles: [
              'rhobs',
            ],
            subjects: [
              {
                name: 'rhobs',
                kind: 'group',
              },
            ],
          },
          {
            name: 'telemeter-server',
            roles: [
              'telemeter-write',
            ],
            subjects: [
              {
                name: 'service-account-telemeter-service-staging',
                kind: 'user',
              },
              {
                name: 'service-account-telemeter-service',
                kind: 'user',
              },
            ],
          },
          {
            name: 'dptp-collector',
            roles: [
              'dptp-write',
            ],
            subjects: [
              {
                name: 'service-account-observatorium-dptp-collector',
                kind: 'user',
              },
              {
                name: 'service-account-observatorium-dptp-collector-staging',
                kind: 'user',
              },
            ],
          },
          {
            name: 'dptp-reader',
            roles: [
              'dptp-read',
            ],
            subjects: [
              {
                name: 'service-account-observatorium-dptp-reader',
                kind: 'user',
              },
              {
                name: 'service-account-observatorium-dptp-reader-staging',
                kind: 'user',
              },
            ],
          },
        ],
      },
      tenants: {
        tenants: [
          {
            name: 'rhobs',
            id: '770c1124-6ae8-4324-a9d4-9ce08590094b',
            oidc: {
              clientID: 'id',
              clientSecret: 'secret',
              issuerURL: 'https://rhobs.tenants.observatorium.io',
              usernameClaim: 'preferred_username',
              groupClaim: 'groups',
            },
          },
          {
            name: 'telemeter',
            id: 'FB870BF3-9F3A-44FF-9BF7-D7A047A52F43',
            oidc: {
              clientID: 'id',
              clientSecret: 'secret',
              issuerURL: 'https://sso.redhat.com/auth/realms/redhat-external',
              usernameClaim: 'preferred_username',
            },
          },
          {
            name: 'dptp',
            id: 'AC879303-C60F-4D0D-A6D5-A485CFD638B8',
            oidc: {
              clientID: 'id',
              clientSecret: 'secret',
              issuerURL: 'https://sso.redhat.com/auth/realms/redhat-external',
              usernameClaim: 'email',
            },
          },
        ],
      },
      resources: {
        requests: {
          cpu: '${OBSERVATORIUM_API_CPU_REQUEST}',
          memory: '${OBSERVATORIUM_API_MEMORY_REQUEST}',
        },
        limits: {
          cpu: '${OBSERVATORIUM_API_CPU_LIMIT}',
          memory: '${OBSERVATORIUM_API_MEMORY_LIMIT}',
        },
      },
      oauthProxy: {
        image: obs.config.oauthProxyImage,
        httpsPort: 9091,
        upstream: 'http://localhost:' + obs.api.service.spec.ports[1].port,
        tlsSecretName: 'observatorium-api-tls',
        sessionSecretName: 'observatorium-api-proxy',
        sessionSecret: '',
        serviceAccountName: 'prometheus-telemeter',
        resources: {
          requests: {
            cpu: '${JAEGER_PROXY_CPU_REQUEST}',
            memory: '${JAEGER_PROXY_MEMORY_REQUEST}',
          },
          limits: {
            cpu: '${JAEGER_PROXY_CPU_LIMITS}',
            memory: '${JAEGER_PROXY_MEMORY_LIMITS}',
          },
        },
      },
    },

    'opa-ams'+:: {
      image: '${OPA_AMS_IMAGE}:${OPA_AMS_IMAGE_TAG}',
      secretName: obs.api.config.name,
      clientIDKey: 'client-id',
      clientSecretKey: 'client-secret',
      issuerURLKey: 'issuer-url',
      amsURL: '${AMS_URL}',
      memcached: 'memcached-0.memcached.${NAMESPACE}.svc.cluster.local:11211',
      memcachedExpire: '${OPA_AMS_MEMCACHED_EXPIRE}',
      mappings: {
        // A map from Observatorium tenant names to AMS organization IDs, e.g.:
        // tenant: 'organizationID',
      },
      ports: {
        api: 8082,
        metrics: 8083,
      },
      opaPackage: 'observatorium',
      resourceTypePrefix: 'observatorium',
      resources: {
        requests: {
          cpu: '${OPA_AMS_CPU_REQUEST}',
          memory: '${OPA_AMS_MEMORY_REQUEST}',
        },
        limits: {
          cpu: '${OPA_AMS_CPU_LIMIT}',
          memory: '${OPA_AMS_MEMORY_LIMIT}',
        },
      },
    },

    loki+:: {},
    lokiCaches+:: {},

    up: {
      local cfg = self,
      name: obs.config.name + '-' + cfg.commonLabels['app.kubernetes.io/name'],
      namespace: obs.config.namespace,
      endpointType: 'metrics',
      readEndpoint: 'http://%s.%s.svc:9090/api/v1/query' % [obs.queryFrontend.service.metadata.name, obs.queryFrontend.service.metadata.namespace],
      version: 'master-2020-06-15-d763595',
      image: 'quay.io/observatorium/up:' + cfg.version,
      queryConfig: (import 'queries.libsonnet'),
      serviceMonitor: true,
      resources: {
        requests: {
          cpu: '5m',
          memory: '10Mi',
        },
        limits: {
          cpu: '20m',
          memory: '50Mi',
        },
      },

      commonLabels+:: obs.config.commonLabels,
    },
  },
} + (import 'github.com/observatorium/deployments/components/observatorium-configure.libsonnet') + {
  local obs = self,
  up+:: {
    config+:: obs.config.up {
      queryConfig: (import 'queries.libsonnet'),
    },
  },

  storeIndexCache+:: {
    config+:: obs.config.storeIndexCache,
  },

  storeBucketCache+:: {
    config+:: obs.config.storeBucketCache,
  },

  'opa-ams'+:: {
    config+:: obs.config['opa-ams'],
  },
} + {
  local obs = self,

  local telemeter = (import 'telemeter.jsonnet') {
    _config+:: {
      namespace: obs.config.namespace,
    },
  },

  local prometheusAMS = (import 'telemeter-prometheus-ams.jsonnet') {
    _config+:: {
      namespace: obs.config.namespace,
    },
  },

  metricsOpenshiftTemplate:: {
    apiVersion: 'v1',
    kind: 'Template',
    metadata: {
      name: 'observatorium',
    },
    objects:
      [
        obs.manifests[name] {
          metadata+: {
            namespace:: 'hidden',
          },
        }
        for name in std.objectFields(obs.manifests)
        if obs.manifests[name] != null
      ] +
      [obs.storeMonitor.serviceMonitor] +
      [obs.receiversMonitor.serviceMonitor] +
      [
        obs.storeIndexCache[name] {
          metadata+: {
            namespace:: 'hidden',
          },
        }
        for name in std.objectFields(obs.storeIndexCache)
      ] +
      [
        obs.storeBucketCache[name] {
          metadata+: {
            namespace:: 'hidden',
          },
        }
        for name in std.objectFields(obs.storeBucketCache)
      ] + [
        object {
          metadata+: {
            namespace:: 'hidden',
          },
        }
        for object in telemeter.objects
      ] + [
        object {
          metadata+: {
            namespace:: 'hidden',
          },
        }
        for object in prometheusAMS.objects
      ],
    parameters: [
      {
        name: 'NAMESPACE',
        value: 'telemeter',
      },
      {
        name: 'THANOS_IMAGE',
        value: 'quay.io/thanos/thanos',
      },
      {
        name: 'THANOS_IMAGE_TAG',
        value: 'master-2020-08-12-70f89d83',
      },
      {
        name: 'STORAGE_CLASS',
        value: 'gp2',
      },
      {
        name: 'PROXY_IMAGE',
        value: 'quay.io/openshift/origin-oauth-proxy',
      },
      {
        name: 'PROXY_IMAGE_TAG',
        value: '4.4.0',
      },
      {
        name: 'JAEGER_AGENT_IMAGE',
        value: 'jaegertracing/jaeger-agent',
      },
      {
        name: 'JAEGER_AGENT_IMAGE_TAG',
        value: '1.14.0',
      },
      {
        name: 'THANOS_RECEIVE_CONTROLLER_IMAGE',
        value: 'quay.io/observatorium/thanos-receive-controller',
      },
      {
        name: 'THANOS_RECEIVE_CONTROLLER_IMAGE_TAG',
        value: 'master-2019-10-18-d55fee2',
      },
      {
        name: 'THANOS_QUERIER_REPLICAS',
        value: '3',
      },
      {
        name: 'THANOS_STORE_REPLICAS',
        value: '5',
      },
      {
        name: 'THANOS_COMPACTOR_LOG_LEVEL',
        value: 'info',
      },
      {
        name: 'THANOS_COMPACTOR_REPLICAS',
        value: '1',
      },
      {
        name: 'THANOS_RECEIVE_REPLICAS',
        value: '5',
      },
      {
        name: 'THANOS_CONFIG_SECRET',
        value: 'thanos-objectstorage',
      },
      {
        name: 'THANOS_S3_SECRET',
        value: 'telemeter-thanos-stage-s3',
      },
      {
        name: 'THANOS_QUERIER_LOG_LEVEL',
        value: 'info',
      },
      {
        name: 'THANOS_QUERIER_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'THANOS_QUERIER_CPU_LIMIT',
        value: '1',
      },
      {
        name: 'THANOS_QUERIER_MEMORY_REQUEST',
        value: '256Mi',
      },
      {
        name: 'THANOS_QUERIER_MEMORY_LIMIT',
        value: '1Gi',
      },
      {
        name: 'THANOS_QUERY_FRONTEND_REPLICAS',
        value: '3',
      },
      {
        name: 'THANOS_QUERY_FRONTEND_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'THANOS_QUERY_FRONTEND_CPU_LIMIT',
        value: '1',
      },
      {
        name: 'THANOS_QUERY_FRONTEND_MEMORY_REQUEST',
        value: '256Mi',
      },
      {
        name: 'THANOS_QUERY_FRONTEND_MEMORY_LIMIT',
        value: '1Gi',
      },
      {
        name: 'THANOS_QUERY_FRONTEND_SPLIT_INTERVAL',
        value: '24h',
      },
      {
        name: 'THANOS_QUERY_FRONTEND_MAX_RETRIES',
        value: '0',
      },
      {
        name: 'THANOS_QUERY_FRONTEND_LOG_QUERIES_LONGER_THAN',
        value: '5s',
      },
      {
        name: 'THANOS_STORE_LOG_LEVEL',
        value: 'info',
      },
      {
        name: 'THANOS_STORE_CPU_REQUEST',
        value: '500m',
      },
      {
        name: 'THANOS_STORE_CPU_LIMIT',
        value: '2',
      },
      {
        name: 'THANOS_STORE_MEMORY_REQUEST',
        value: '1Gi',
      },
      {
        name: 'THANOS_STORE_MEMORY_LIMIT',
        value: '8Gi',
      },
      {
        name: 'THANOS_STORE_INDEX_CACHE_REPLICAS',
        value: '3',
      },
      {
        name: 'THANOS_STORE_INDEX_CACHE_MEMORY_LIMIT_MB',
        value: '2048',
      },
      {
        name: 'THANOS_STORE_INDEX_CACHE_CONNECTION_LIMIT',
        value: '3072',
      },
      {
        name: 'THANOS_STORE_INDEX_CACHE_MEMCACHED_CPU_REQUEST',
        value: '500m',
      },
      {
        name: 'THANOS_STORE_INDEX_CACHE_MEMCACHED_CPU_LIMIT',
        value: '3',
      },
      {
        name: 'THANOS_STORE_INDEX_CACHE_MEMCACHED_MEMORY_REQUEST',
        value: '2558Mi',
      },
      {
        name: 'THANOS_STORE_INDEX_CACHE_MEMCACHED_MEMORY_LIMIT',
        value: '3Gi',
      },
      {
        name: 'THANOS_STORE_BUCKET_CACHE_REPLICAS',
        value: '3',
      },
      {
        name: 'THANOS_STORE_BUCKET_CACHE_MEMORY_LIMIT_MB',
        value: '2048',
      },
      {
        name: 'THANOS_STORE_BUCKET_CACHE_CONNECTION_LIMIT',
        value: '3072',
      },
      {
        name: 'THANOS_STORE_BUCKET_CACHE_MEMCACHED_CPU_REQUEST',
        value: '500m',
      },
      {
        name: 'THANOS_STORE_BUCKET_CACHE_MEMCACHED_CPU_LIMIT',
        value: '3',
      },
      {
        name: 'THANOS_STORE_BUCKET_CACHE_MEMCACHED_MEMORY_REQUEST',
        value: '2558Mi',
      },
      {
        name: 'THANOS_STORE_BUCKET_CACHE_MEMCACHED_MEMORY_LIMIT',
        value: '3Gi',
      },
      {
        name: 'THANOS_RECEIVE_CPU_REQUEST',
        value: '1',
      },
      {
        name: 'THANOS_RECEIVE_CPU_LIMIT',
        value: '1',
      },
      {
        name: 'THANOS_RECEIVE_MEMORY_REQUEST',
        value: '1Gi',
      },
      {
        name: 'THANOS_RECEIVE_MEMORY_LIMIT',
        value: '1Gi',
      },
      {
        name: 'THANOS_RECEIVE_DEBUG_ENV',
        value: '',
      },
      {
        name: 'THANOS_RECEIVE_LOG_LEVEL',
        value: 'info',
      },
      {
        name: 'THANOS_COMPACTOR_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'THANOS_COMPACTOR_CPU_LIMIT',
        value: '1',
      },
      {
        name: 'THANOS_COMPACTOR_MEMORY_REQUEST',
        value: '1Gi',
      },
      {
        name: 'THANOS_COMPACTOR_MEMORY_LIMIT',
        value: '5Gi',
      },
      {
        name: 'THANOS_COMPACTOR_PVC_REQUEST',
        value: '50Gi',
      },
      {
        name: 'THANOS_RULER_LOG_LEVEL',
        value: 'info',
      },
      {
        name: 'THANOS_RULER_REPLICAS',
        value: '2',
      },
      {
        name: 'THANOS_RULER_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'THANOS_RULER_CPU_LIMIT',
        value: '1',
      },
      {
        name: 'THANOS_RULER_MEMORY_REQUEST',
        value: '512Mi',
      },
      {
        name: 'THANOS_RULER_MEMORY_LIMIT',
        value: '1Gi',
      },
      {
        name: 'THANOS_QUERIER_SVC_URL',
        value: 'http://thanos-querier.observatorium.svc:9090',
      },
      {
        name: 'GUBERNATOR_IMAGE',
        value: 'thrawn01/gubernator',
      },
      {
        name: 'GUBERNATOR_IMAGE_TAG',
        value: '1.0.0-rc.1',
      },
      {
        name: 'GUBERNATOR_REPLICAS',
        value: '2',
      },
      {
        name: 'GUBERNATOR_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'GUBERNATOR_CPU_LIMIT',
        value: '200m',
      },
      {
        name: 'GUBERNATOR_MEMORY_REQUEST',
        value: '100Mi',
      },
      {
        name: 'GUBERNATOR_MEMORY_LIMIT',
        value: '200Mi',
      },
      {
        name: 'OBSERVATORIUM_API_IMAGE',
        value: 'quay.io/observatorium/observatorium',
      },
      {
        name: 'OBSERVATORIUM_API_IMAGE_TAG',
        value: 'master-2020-11-02-v0.1.1-192-ge324057',
      },
      {
        name: 'OBSERVATORIUM_API_REPLICAS',
        value: '3',
      },
      {
        name: 'OBSERVATORIUM_API_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'OBSERVATORIUM_API_CPU_LIMIT',
        value: '1',
      },
      {
        name: 'OBSERVATORIUM_API_MEMORY_REQUEST',
        value: '256Mi',
      },
      {
        name: 'OBSERVATORIUM_API_MEMORY_LIMIT',
        value: '1Gi',
      },
      {
        name: 'OPA_AMS_IMAGE',
        value: 'quay.io/observatorium/opa-ams',
      },
      {
        name: 'OPA_AMS_IMAGE_TAG',
        value: 'master-2020-10-28-902d400',
      },
      {
        name: 'OPA_AMS_MEMCACHED_EXPIRE',
        value: '300',
      },
      {
        name: 'OPA_AMS_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'OPA_AMS_MEMORY_REQUEST',
        value: '100Mi',
      },
      {
        name: 'OPA_AMS_CPU_LIMIT',
        value: '200m',
      },
      {
        name: 'OPA_AMS_MEMORY_LIMIT',
        value: '200Mi',
      },
      {
        name: 'JAEGER_PROXY_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'JAEGER_PROXY_MEMORY_REQUEST',
        value: '100Mi',
      },
      {
        name: 'JAEGER_PROXY_CPU_LIMITS',
        value: '200m',
      },
      {
        name: 'JAEGER_PROXY_MEMORY_LIMITS',
        value: '200Mi',
      },
      {
        name: 'IMAGE',
        value: 'quay.io/openshift/origin-telemeter',
      },
      {
        name: 'IMAGE_TAG',
        value: 'v4.0',
      },
      {
        name: 'REPLICAS',
        value: '10',
      },
      {
        name: 'IMAGE_CANARY',
        value: 'quay.io/openshift/origin-telemeter',
      },
      {
        name: 'IMAGE_CANARY_TAG',
        value: 'v4.0',
      },
      {
        name: 'REPLICAS_CANARY',
        value: '0',
      },
      {
        name: 'TELEMETER_SERVER_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'TELEMETER_SERVER_CPU_LIMIT',
        value: '1',
      },
      {
        name: 'TELEMETER_SERVER_MEMORY_REQUEST',
        value: '500Mi',
      },
      {
        name: 'TELEMETER_SERVER_MEMORY_LIMIT',
        value: '1Gi',
      },
      {
        name: 'MEMCACHED_IMAGE',
        value: 'docker.io/memcached',
      },
      {
        name: 'MEMCACHED_IMAGE_TAG',
        value: '1.5.20-alpine',
      },
      {
        name: 'MEMCACHED_EXPORTER_IMAGE',
        value: 'docker.io/prom/memcached-exporter',
      },
      {
        name: 'MEMCACHED_EXPORTER_IMAGE_TAG',
        value: 'v0.6.0',
      },
      {
        name: 'MEMCACHED_CPU_REQUEST',
        value: '500m',
      },
      {
        name: 'MEMCACHED_CPU_LIMIT',
        value: '3',
      },
      {
        name: 'MEMCACHED_MEMORY_REQUEST',
        value: '1329Mi',
      },
      {
        name: 'MEMCACHED_MEMORY_LIMIT',
        value: '1844Mi',
      },
      {
        name: 'MEMCACHED_EXPORTER_CPU_REQUEST',
        value: '50m',
      },
      {
        name: 'MEMCACHED_EXPORTER_CPU_LIMIT',
        value: '200m',
      },
      {
        name: 'MEMCACHED_EXPORTER_MEMORY_REQUEST',
        value: '50Mi',
      },
      {
        name: 'MEMCACHED_EXPORTER_MEMORY_LIMIT',
        value: '200Mi',
      },
      {
        name: 'TELEMETER_FORWARD_URL',
        value: '',
      },
      {
        name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_IMAGE',
        value: 'quay.io/app-sre/observatorium-receive-proxy',
      },
      {
        name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_VERSION',
        value: '14e844d',
      },
      {
        name: 'THANOS_RECEIVE_TSDB_PATH',
        value: '/var/thanos/receive',
      },
      {
        name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_TARGET',
        value: 'observatorium-thanos-receive',
      },
      {
        name: 'TELEMETER_SERVER_TOKEN_EXPIRE_SECONDS',
        value: '3600',
      },
      {
        name: 'TELEMETER_LOG_LEVEL',
        value: 'warn',
      },
    ],
  },

  logsOpenShiftTemplate:: {
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
      {
        name: 'NAMESPACE',
        value: 'telemeter',
      },
      {
        name: 'STORAGE_CLASS',
        value: 'gp2',
      },
      {
        name: 'LOKI_IMAGE_TAG',
        value: '2.0.0',
      },
      {
        name: 'LOKI_IMAGE',
        value: 'docker.io/grafana/loki',
      },
      {
        name: 'LOKI_S3_SECRET',
        value: 'telemeter-loki-stage-s3',
      },
      {
        name: 'LOKI_COMPACTOR_CPU_REQUESTS',
        value: '500m',
      },
      {
        name: 'LOKI_COMPACTOR_CPU_LIMITS',
        value: '1000m',
      },
      {
        name: 'LOKI_COMPACTOR_MEMORY_REQUESTS',
        value: '2Gi',
      },
      {
        name: 'LOKI_COMPACTOR_MEMORY_LIMITS',
        value: '4Gi',
      },
      {
        name: 'LOKI_DISTRIBUTOR_REPLICAS',
        value: '2',
      },
      {
        name: 'LOKI_DISTRIBUTOR_CPU_REQUESTS',
        value: '500m',
      },
      {
        name: 'LOKI_DISTRIBUTOR_CPU_LIMITS',
        value: '1000m',
      },
      {
        name: 'LOKI_DISTRIBUTOR_MEMORY_REQUESTS',
        value: '500Mi',
      },
      {
        name: 'LOKI_DISTRIBUTOR_MEMORY_LIMITS',
        value: '1Gi',
      },
      {
        name: 'LOKI_INGESTER_REPLICAS',
        value: '2',
      },
      {
        name: 'LOKI_INGESTER_CPU_REQUESTS',
        value: '1000m',
      },
      {
        name: 'LOKI_INGESTER_CPU_LIMITS',
        value: '2000m',
      },
      {
        name: 'LOKI_INGESTER_MEMORY_REQUESTS',
        value: '5Gi',
      },
      {
        name: 'LOKI_INGESTER_MEMORY_LIMITS',
        value: '10Gi',
      },
      {
        name: 'LOKI_QUERIER_REPLICAS',
        value: '2',
      },
      {
        name: 'LOKI_QUERIER_CPU_REQUESTS',
        value: '500m',
      },
      {
        name: 'LOKI_QUERIER_CPU_LIMITS',
        value: '500m',
      },
      {
        name: 'LOKI_QUERIER_MEMORY_REQUESTS',
        value: '600Mi',
      },
      {
        name: 'LOKI_QUERIER_MEMORY_LIMITS',
        value: '1200Mi',
      },
      {
        name: 'LOKI_QUERY_FRONTEND_REPLICAS',
        value: '2',
      },
      {
        name: 'LOKI_QUERY_FRONTEND_CPU_REQUESTS',
        value: '500m',
      },
      {
        name: 'LOKI_QUERY_FRONTEND_CPU_LIMITS',
        value: '500m',
      },
      {
        name: 'LOKI_QUERY_FRONTEND_MEMORY_REQUESTS',
        value: '600Mi',
      },
      {
        name: 'LOKI_QUERY_FRONTEND_MEMORY_LIMITS',
        value: '1200Mi',
      },
      {
        name: 'LOKI_CHUNK_CACHE_REPLICAS',
        value: '2',
      },
      {
        name: 'LOKI_INDEX_QUERY_CACHE_REPLICAS',
        value: '2',
      },
      {
        name: 'LOKI_RESULTS_CACHE_REPLICAS',
        value: '2',
      },
      {
        name: 'LOKI_PVC_REQUEST',
        value: '50Gi',
      },
      {
        name: 'JAEGER_AGENT_IMAGE',
        value: 'jaegertracing/jaeger-agent',
      },
      {
        name: 'JAEGER_AGENT_IMAGE_TAG',
        value: '1.14.0',
      },
      {
        name: 'JAEGER_PROXY_CPU_REQUEST',
        value: '100m',
      },
      {
        name: 'JAEGER_PROXY_MEMORY_REQUEST',
        value: '100Mi',
      },
      {
        name: 'JAEGER_PROXY_CPU_LIMITS',
        value: '200m',
      },
      {
        name: 'JAEGER_PROXY_MEMORY_LIMITS',
        value: '200Mi',
      },
      {
        name: 'MEMCACHED_IMAGE',
        value: 'docker.io/memcached',
      },
      {
        name: 'MEMCACHED_IMAGE_TAG',
        value: '1.5.20-alpine',
      },
      {
        name: 'MEMCACHED_EXPORTER_IMAGE',
        value: 'docker.io/prom/memcached-exporter',
      },
      {
        name: 'MEMCACHED_EXPORTER_IMAGE_TAG',
        value: 'v0.6.0',
      },
      {
        name: 'MEMCACHED_CPU_REQUEST',
        value: '500m',
      },
      {
        name: 'MEMCACHED_CPU_LIMIT',
        value: '3',
      },
      {
        name: 'MEMCACHED_MEMORY_REQUEST',
        value: '1329Mi',
      },
      {
        name: 'MEMCACHED_MEMORY_LIMIT',
        value: '1844Mi',
      },
      {
        name: 'MEMCACHED_EXPORTER_CPU_REQUEST',
        value: '50m',
      },
      {
        name: 'MEMCACHED_EXPORTER_CPU_LIMIT',
        value: '200m',
      },
      {
        name: 'MEMCACHED_EXPORTER_MEMORY_REQUEST',
        value: '50Mi',
      },
      {
        name: 'MEMCACHED_EXPORTER_MEMORY_LIMIT',
        value: '200Mi',
      },
    ],
  },

  openShiftTemplates:: {
    'observatorium-template': obs.metricsOpenshiftTemplate,
    'observatorium-logs-template': obs.logsOpenShiftTemplate,
  },
}
