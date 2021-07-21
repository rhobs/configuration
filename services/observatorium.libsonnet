local api = (import 'github.com/observatorium/api/jsonnet/lib/observatorium-api.libsonnet');
local up = (import 'github.com/observatorium/up/jsonnet/up.libsonnet');
local gubernator = (import 'github.com/observatorium/observatorium/configuration/components/gubernator.libsonnet');
local memcached = (import 'github.com/observatorium/observatorium/configuration/components/memcached.libsonnet');

(import 'github.com/observatorium/observatorium/configuration/components/observatorium.libsonnet') +
(import 'observatorium-metrics.libsonnet') +
(import 'observatorium-metrics-template-overwrites.libsonnet') +
(import 'observatorium-logs.libsonnet') +
(import 'observatorium-logs-template-overwrites.libsonnet') +
{
  local obs = self,

  config:: {
    name: 'observatorium',
    namespaces: {
      default: '${NAMESPACE}',
      metrics: '${OBSERVATORIUM_METRICS_NAMESPACE}',
      logs: '${OBSERVATORIUM_LOGS_NAMESPACE}',
    },

    commonLabels:: {
      'app.kubernetes.io/part-of': 'observatorium',
      'app.kubernetes.io/instance': obs.config.name,
    },
  },

  gubernator:: gubernator({
    local cfg = self,
    name: obs.config.name + '-' + cfg.commonLabels['app.kubernetes.io/name'],
    namespace: obs.config.namespaces.default,
    version: '${GUBERNATOR_IMAGE_TAG}',
    image: '%s:%s' % ['${GUBERNATOR_IMAGE}', cfg.version],
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
    deployment+: {
      spec+: {
        replicas: '${{GUBERNATOR_REPLICAS}}',
      },
    },
    serviceAccount+: {
      imagePullSecrets+: [{ name: 'quay.io' }],
    },
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
        namespaceSelector: {
          // NOTICE:
          // When using the ${{PARAMETER_NAME}} syntax only a single parameter reference is allowed and leading/trailing characters are not permitted.
          // The resulting value will be unquoted unless, after substitution is performed, the result is not a valid json object.
          // If the result is not a valid json value, the resulting value will be quoted and treated as a standard string.
          matchNames: '${{NAMESPACES}}',
        },
      },
    },
  },

  memcached: memcached({
    local cfg = self,
    serviceMonitor: true,
    name: 'observatorium-api-cache-' + cfg.commonLabels['app.kubernetes.io/name'],
    namespace: obs.config.namespaces.default,
    commonLabels:: {
      'app.kubernetes.io/component': 'api-cache',
      'app.kubernetes.io/instance': 'observatorium',
      'app.kubernetes.io/name': 'memcached',
      'app.kubernetes.io/part-of': 'observatorium',
      'app.kubernetes.io/version': cfg.version,
    },

    version: '${MEMCACHED_IMAGE_TAG}',
    image: '%s:%s' % ['${MEMCACHED_IMAGE}', cfg.version],
    exporterVersion: '${MEMCACHED_EXPORTER_IMAGE_TAG}',
    exporterImage: '%s:%s' % ['${MEMCACHED_EXPORTER_IMAGE}', cfg.exporterVersion],
    connectionLimit: '${MEMCACHED_CONNECTION_LIMIT}',
    memoryLimitMb: '${MEMCACHED_MEMORY_LIMIT_MB}',
    maxItemSize: '5m',
    replicas: 1,  // overwritten in observatorium-metrics-template.libsonnet
    securityContext: {},
    resources: {
      memcached: {
        requests: {
          cpu: '${MEMCACHED_CPU_REQUEST}',
          memory: '${MEMCACHED_MEMORY_REQUEST}',
        },
        limits: {
          cpu: '${MEMCACHED_CPU_LIMIT}',
          memory: '${MEMCACHED_MEMORY_LIMIT}',
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
    serviceMonitor+: {
      metadata+: {
        labels+: {
          prometheus: 'app-sre',
          'app.kubernetes.io/version':: 'hidden',
        },
      },
      spec+: {
        namespaceSelector: {
          // NOTICE:
          // When using the ${{PARAMETER_NAME}} syntax only a single parameter reference is allowed and leading/trailing characters are not permitted.
          // The resulting value will be unquoted unless, after substitution is performed, the result is not a valid json object.
          // If the result is not a valid json value, the resulting value will be quoted and treated as a standard string.
          matchNames: '${{NAMESPACES}}',
        },
      },
    },
  },

  api:: api({
    local cfg = self,
    // OBSERVATORIUM_API_IDENTIFIER referes to all the associated resource names (config map, secret, service) required for serving Observatorium API.
    name: '${OBSERVATORIUM_API_IDENTIFIER}',
    commonLabels:: {
      'app.kubernetes.io/component': 'api',
      'app.kubernetes.io/instance': 'observatorium',
      'app.kubernetes.io/name': 'observatorium-api',
      'app.kubernetes.io/part-of': 'observatorium',
      'app.kubernetes.io/version': '${OBSERVATORIUM_API_IMAGE_TAG}',
    },
    version: '${OBSERVATORIUM_API_IMAGE_TAG}',
    image: '%s:%s' % ['${OBSERVATORIUM_API_IMAGE}', cfg.version],
    replicas: 1,
    serviceMonitor: true,
    logs: {
      readEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
        obs.loki.manifests['query-frontend-http-service'].metadata.name,
        obs.config.namespaces.logs,
        obs.loki.manifests['query-frontend-http-service'].spec.ports[0].port,
      ],
      tailEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
        obs.loki.manifests['querier-http-service'].metadata.name,
        obs.config.namespaces.logs,
        obs.loki.manifests['querier-http-service'].spec.ports[0].port,
      ],
      writeEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
        obs.loki.manifests['distributor-http-service'].metadata.name,
        obs.config.namespaces.logs,
        obs.loki.manifests['distributor-http-service'].spec.ports[0].port,
      ],
    },
    metrics: {
      readEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
        obs.thanos.queryFrontend.service.metadata.name,
        obs.config.namespaces.metrics,
        obs.thanos.queryFrontend.service.spec.ports[0].port,
      ],
      writeEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
        obs.thanos.receiversService.metadata.name,
        obs.config.namespaces.metrics,
        obs.thanos.receiversService.spec.ports[2].port,
      ],
    },
    rateLimiter: {
      grpcAddress: '%s.%s.svc.cluster.local:%d' % [
        obs.gubernator.service.metadata.name,
        obs.config.namespaces.default,
        obs.gubernator.config.ports.grpc,
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
    internal: {
      tracing: {
        endpoint: 'localhost:6831',
      },
    },
  }) + {
    // TODO: Enable in a separate MR.
    // local oauth = (import 'sidecars/oauth-proxy.libsonnet')({
    //   name: 'observatorium-api',
    //   image: '${OAUTH_PROXY_IMAGE}:${OAUTH_PROXY_IMAGE_TAG}',
    //   httpsPort: 9091,
    //   upstream: 'http://localhost:' + obs.api.service.spec.ports[1].port,
    //   tlsSecretName: 'observatorium-api-tls',
    //   sessionSecretName: 'observatorium-api-proxy',
    //   serviceAccountName: 'observatorium-api',
    //   resources: {
    //     requests: {
    //       cpu: '${OAUTH_PROXY_CPU_REQUEST}',
    //       memory: '${OAUTH_PROXY_MEMORY_REQUEST}',
    //     },
    //     limits: {
    //       cpu: '${OAUTH_PROXY_CPU_LIMITS}',
    //       memory: '${OAUTH_PROXY_MEMORY_LIMITS}',
    //     },
    //   },
    // }),

    local jaegerAgent = (import './sidecars/jaeger-agent.libsonnet')({
      image: '${JAEGER_AGENT_IMAGE}:${JAEGER_AGENT_IMAGE_TAG}',
      collectorAddress: 'dns:///jaeger-collector-headless.${JAEGER_COLLECTOR_NAMESPACE}.svc:14250',
    }),

    local opaAms = (import 'sidecars/opa-ams.libsonnet')({
      image: '${OPA_AMS_IMAGE}:${OPA_AMS_IMAGE_TAG}',
      clientIDKey: 'client-id',
      clientSecretKey: 'client-secret',
      secretName: obs.api.config.name,
      issuerURLKey: 'issuer-url',
      amsURL: '${AMS_URL}',
      mappings: {
        osd: '${OSD_ORGANIZATION_ID}',
        dptp: '${DPTP_ORGANIZATION_ID}',
        managedkafka: '${MANAGEDKAFKA_ORGANIZATION_ID}',
      },
      memcached: '%s.%s.svc.cluster.local:%d' % [
        obs.memcached.service.metadata.name,
        obs.config.namespaces.default,
        obs.memcached.service.spec.ports[0].port,
      ],
      memcachedExpire: '${OPA_AMS_MEMCACHED_EXPIRE}',
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
      internal: {
        tracing: {
          endpoint: 'localhost:6831',
        },
      },
    }),

    // proxySecret: oauth.proxySecret,

    // service+: oauth.service + opaAms.service,
    service+: opaAms.service,

    deployment+: {
      spec+: {
        replicas: '${{OBSERVATORIUM_API_REPLICAS}}',
      },
    } + opaAms.deployment + jaegerAgent.deployment,
    // + oauth.deployment

    configmap+: {
      metadata+: {
        annotations+: { 'qontract.recycle': 'true' },
      },
    },

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
        namespaceSelector: {
          // NOTICE:
          // When using the ${{PARAMETER_NAME}} syntax only a single parameter reference is allowed and leading/trailing characters are not permitted.
          // The resulting value will be unquoted unless, after substitution is performed, the result is not a valid json object.
          // If the result is not a valid json value, the resulting value will be quoted and treated as a standard string.
          matchNames: '${{NAMESPACES}}',
        },
      },
    } + opaAms.serviceMonitor,
  },

  up:: up({
    local cfg = self,
    name: obs.config.name + '-' + cfg.commonLabels['app.kubernetes.io/name'],
    namespace: obs.config.namespaces.default,
    commonLabels+:: obs.config.commonLabels,
    version: 'master-2020-06-15-d763595',
    image: 'quay.io/observatorium/up:' + cfg.version,
    replicas: 1,
    endpointType: 'metrics',
    readEndpoint: 'http://%s.%s.svc:9090/api/v1/query' % [obs.thanos.queryFrontend.service.metadata.name, obs.thanos.queryFrontend.service.metadata.namespace],
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
      spec+: {
        namespaceSelector: {
          // NOTICE:
          // When using the ${{PARAMETER_NAME}} syntax only a single parameter reference is allowed and leading/trailing characters are not permitted.
          // The resulting value will be unquoted unless, after substitution is performed, the result is not a valid json object.
          // If the result is not a valid json value, the resulting value will be quoted and treated as a standard string.
          matchNames: '${{NAMESPACES}}',
        },
      },
    },
  },

  manifests+:: {
    ['observatorium-up-' + name]: obs.up[name]
    for name in std.objectFields(obs.up)
    if obs.up[name] != null
  } + {
    ['observatorium-cache-' + name]: obs.memcached[name]
    for name in std.objectFields(obs.memcached)
    if obs.memcached[name] != null
  },
}
