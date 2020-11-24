local api = (import 'github.com/observatorium/observatorium/jsonnet/lib/observatorium-api.libsonnet');
local up = (import 'github.com/observatorium/up/jsonnet/up.libsonnet');
local gubernator = (import 'github.com/observatorium/deployments/components/gubernator.libsonnet');

(import 'github.com/observatorium/deployments/components/observatorium.libsonnet') +
(import './observatorium-metrics.libsonnet') +
(import './observatorium-metrics-template.libsonnet') +
(import './observatorium-logs.libsonnet') +
(import './observatorium-logs-template.libsonnet') +
{
  local obs = self,

  gubernator:: gubernator({
    local cfg = self,
    name: obs.config.name + '-' + cfg.commonLabels['app.kubernetes.io/name'],
    namespace: obs.config.namespace,
    version: '${GUBERNATOR_IMAGE_TAG}',
    image: '%s:%s' % ['${GUBERNATOR_IMAGE}', cfg.version],
    // replicas: '${{GUBERNATOR_REPLICAS}}',
    replicas: 1,
    commonLabels+:: obs.config.commonLabels,
    serviceMonitor: true,
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
  }) {
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

  api::
    api({
      local cfg = self,
      name: 'observatorium-api',
      version: '${OBSERVATORIUM_API_IMAGE_TAG}',
      image: '%s:%s' % ['${OBSERVATORIUM_API_IMAGE}', cfg.version],
      // replicas: '${{OBSERVATORIUM_API_REPLICAS}}',
      replicas: 1,
      serviceMonitor: true,
      logs: {
        readEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
          obs.loki.manifests['query-frontend-http-service'].metadata.name,
          '${OBSERVATORIUM_LOGS_NAMESPACE}',
          obs.loki.manifests['query-frontend-http-service'].spec.ports[0].port,
        ],
        tailEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
          obs.loki.manifests['querier-http-service'].metadata.name,
          '${OBSERVATORIUM_LOGS_NAMESPACE}',
          obs.loki.manifests['querier-http-service'].spec.ports[0].port,
        ],
        writeEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
          obs.loki.manifests['distributor-http-service'].metadata.name,
          '${OBSERVATORIUM_LOGS_NAMESPACE}',
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
          // TODO(kakkoyun): Fix after creting receivers service.
          '',
          '',
          0,
          // obs.receiversService.metadata.name,
          // obs.receiversService.metadata.namespace,
          // obs.receiversService.spec.ports[2].port,
        ],
      },
      rateLimiter: {
        grpcAddress: '%s.%s.svc.cluster.local:%d' % [
          obs.gubernator.service.metadata.name,
          obs.gubernator.service.metadata.namespace,
          obs.gubernator.service.spec.ports[1].port,
        ],
      },
      rbac: (import '../configuration/observatorium/rbac.libsonnet'),
      tenants: (import '../configuration/observatorium/tenants.libsonnet'),
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
    }) + {
      local oauth = (import './sidecars/oauth-proxy.libsonnet')({
        name: 'observatorium-api',
        image: '${PROXY_IMAGE}:${PROXY_IMAGE_TAG}',
        httpsPort: 9091,
        upstream: 'http://localhost:' + obs.api.service.spec.ports[1].port,
        tlsSecretName: 'observatorium-api-tls',
        sessionSecretName: 'observatorium-api-proxy',
        sessionSecret: '',
        serviceAccountName: 'observatorium-api',
        resources: {
          requests: {
            cpu: '${OAUTH_PROXY_CPU_REQUEST}',
            memory: '${OAUTH_PROXY_MEMORY_REQUEST}',
          },
          limits: {
            cpu: '${OAUTH_PROXY_CPU_LIMITS}',
            memory: '${OAUTH_PROXY_MEMORY_LIMITS}',
          },
        },
      }),

      proxySecret: oauth.proxySecret,

      service+: oauth.service,

      deployment+: oauth.deployment,
    } + {
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
      configmap+: {
        metadata+: {
          annotations+: { 'qontract.recycle': 'true' },
        },
      },
    }
    // TODO(kakkoyun): Extract as a sidecar.
    + (if obs['opa-ams'] != null then {
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

         // TODO(kakkoyun): Extract as a sidecar.
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

         // TODO(kakkoyun): Extract as a sidecar.
         serviceMonitor+: {
           spec+: {
             endpoints+: [
               { port: 'opa-ams-metrics' },
             ],
           },
         },
       } else {}),

  up:: up({
    local cfg = self,
    name: obs.config.name + '-' + cfg.commonLabels['app.kubernetes.io/name'],
    namespace: obs.config.namespace,
    commonLabels+:: obs.config.commonLabels,
    version: 'master-2020-06-15-d763595',
    image: 'quay.io/observatorium/up:' + cfg.version,
    replicas: 1,
    endpointType: 'metrics',
    readEndpoint: 'http://%s.%s.svc:9090/api/v1/query' % [obs.queryFrontend.service.metadata.name, obs.queryFrontend.service.metadata.namespace],
    queryConfig: (import '../configuration/observatorium/queries.libsonnet'),
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
  }) {
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
    objectStorageConfig:: {
      //   thanos: {
      //     name: '${THANOS_CONFIG_SECRET}',
      //     key: 'thanos.yaml',
      //   },
      loki: {
        secretName: '${LOKI_S3_SECRET}',
        bucketsKey: 'buckets',
        regionKey: 'region',
        accessKeyIdKey: 'aws_access_key_id',
        secretAccessKeyKey: 'aws_secret_access_key',
      },
    },

    loki+:: {},
    lokiCaches+:: {},

    // TODO(kakkoyun): Extract as a sidecar.
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
  },
} + (import 'github.com/observatorium/deployments/components/observatorium-configure.libsonnet') + {
  local obs = self,

  // TODO(kakkoyun): Extract as a sidecar.
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

  local obsNS = 'telemeter',
  local obsLogsNS = 'observatorium-logs',

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
      // [obs.storeMonitor.serviceMonitor] +
      // [obs.receiversMonitor.serviceMonitor] +
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
        value: obsNS,
      },
      {
        name: 'OBSERVATORIUM_LOGS_NAMESPACE',
        value: obsLogsNS,
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
        value: obsLogsNS,
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
        value: 'observatorium-logs-stage-s3',
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
        name: 'LOKI_REPLICATION_FACTOR',
        // This value should be set equal to
        // LOKI_REPLICATION_FACTOR <= LOKI_INGESTER_REPLICAS
        value: '2',
      },
      {
        name: 'LOKI_QUERY_PARALLELISM',
        // The querier concurrency should be equal to (or less than) the CPU cores of the system the querier runs.
        // A higher value will lead to a querier trying to process more requests than there are available
        // cores and will result in scheduling delays.
        // This value should be set equal to:
        //
        // std.floor( querier-concurrency / LOKI_QUERY_FRONTEND_REPLICAS)
        //
        // e.g. limit to N/2 worker threads per frontend, as we have two frontends.
        value: '2',
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
        name: 'JAEGER_COLLECTOR_NAMESPACE',
        value: obsNS,
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
