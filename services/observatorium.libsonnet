local api = (import 'github.com/observatorium/api/jsonnet/lib/observatorium-api.libsonnet');
local up = (import 'github.com/observatorium/up/jsonnet/up.libsonnet');
local gubernator = (import 'github.com/observatorium/observatorium/configuration/components/gubernator.libsonnet');
local memcached = (import 'github.com/observatorium/observatorium/configuration/components/memcached.libsonnet');
local rulesObjstore = (import 'github.com/observatorium/rules-objstore/jsonnet/lib/rules-objstore.libsonnet');
local obsctlReloader = (import 'github.com/rhobs/obsctl-reloader/jsonnet/lib/obsctl-reloader.libsonnet');

(import 'github.com/observatorium/observatorium/configuration/components/observatorium.libsonnet') +
(import 'observatorium-metrics.libsonnet') +
(import 'observatorium-metrics-template-overwrites.libsonnet') +
(import 'observatorium-logs.libsonnet') +
(import 'observatorium-logs-template-overwrites.libsonnet') +
(import 'observatorium-traces.libsonnet') +
{
  local obs = self,

  config:: {
    name: 'observatorium',
    namespaces: {
      default: '${NAMESPACE}',
      metrics: '${OBSERVATORIUM_METRICS_NAMESPACE}',
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
    logLevel: '${GUBERNATOR_LOG_LEVEL}',
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
    serviceAccount+: {
      imagePullSecrets+: [{ name: 'quay.io' }],
    },
  },

  obsctlReloader:: obsctlReloader({
    local cfg = self,
    name: 'rules-obsctl-reloader',
    version: '${OBSCTL_RELOADER_IMAGE_TAG}',
    image: '%s:%s' % ['${OBSCTL_RELOADER_IMAGE}', cfg.version],
    replicas: '${{OBSCTL_RELOADER_REPLICAS}}',
    logLevel: 'debug',
    commonLabels+:: {
      'app.kubernetes.io/name': 'rules-obsctl-reloader',
      'app.kubernetes.io/component': 'rules-obsctl-reloader',
    } + obs.config.commonLabels,
    env: {
      observatoriumURL: '${OBSERVATORIUM_URL}',
      oidcAudience: '${OIDC_AUDIENCE}',
      oidcIssuerURL: '${OIDC_ISSUER_URL}',
      sleepDurationSeconds: '${SLEEP_DURATION_SECONDS}',
      configReloadIntervalSeconds: '${CONFIG_RELOAD_INTERVAL_SECONDS}',
      managedTenants: '${MANAGED_TENANTS}',
    },
    // Tenants normally follows a lower-case format.
    // However tenant attribute in below map items need to be uppercase to be the proper prefix for the env variable to create.
    tenantSecretMap: [
      {
        tenant: 'RHOBS',
        secret: '${RHOBS_RELOADER_SECRET_NAME}',
        idKey: 'client_id',
        secretKey: 'client_secret',
      },
      {
        tenant: 'OSD',
        secret: '${OSD_RELOADER_SECRET_NAME}',
        idKey: 'client-id',
        secretKey: 'client-secret',
        // Marking as optional here, as osd tenant only exists on mst,
        // so this should not block pod start.
        optional: true,
      },
      {
        tenant: 'HYPERSHIFT-PLATFORM-STAGING',
        secret: '${HYPERSHIFT_PLATFORM_STAGING_RELOADER_SECRET_NAME}',
        idKey: 'client-id',
        secretKey: 'client-secret',
        // Marking as optional here, as hypershift-platform-staging tenant only exists on mst,
        // so this should not block pod start.
        optional: true,
      },
      {
        tenant: 'HYPERSHIFT-PLATFORM',
        secret: '${HYPERSHIFT_PLATFORM_RELOADER_SECRET_NAME}',
        idKey: 'client-id',
        secretKey: 'client-secret',
        // Marking as optional here, as hypershift-platform tenant only exists on mst,
        // so this should not block pod start.
        optional: true,
      },
      {
        tenant: 'APPSRE',
        secret: '${APPSRE_RELOADER_SECRET_NAME}',
        idKey: 'client-id',
        secretKey: 'client-secret',
        // Marking as optional here, as appsre tenant only exists on mst,
        // so this should not block pod start.
        optional: true,
      },
      {
        tenant: 'RHTAP',
        secret: '${RHTAP_RELOADER_SECRET_NAME}',
        idKey: 'client-id',
        secretKey: 'client-secret',
        // Marking as optional here, as appsre tenant only exists on mst,
        // so this should not block pod start.
        optional: true,
      },
    ],
  }) + {
    serviceMonitor+: {
      metadata+: {
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


  rulesSLOPrometheusRule: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      name: 'rules-reloader-slo',
      labels: {
        tenant: 'rhobs',
      },
    },
    spec: {
      groups: [
        {
          interval: '30s',
          name: 'reloader-slo-alert',
          rules: [
            {
              alert: 'AlwaysFiringAlert',
              expr: 'vector(1)',
              'for': '1m',
              annotations: {
                description: 'Firing alert!',
                message: 'Alert fired.',
              },
              labels: {
                severity: 'page',
              },
            },
            {
              alert: 'AlwaysFiringAlert2',
              expr: 'vector(1)',
              'for': '1m',
              annotations: {
                description: 'Firing alert 2!',
                message: 'Alert 2 fired.',
              },
              labels: {
                severity: 'page',
              },
            },
            {
              alert: 'NeverFiringAlert',
              expr: 'vector(0) == 1',
              'for': '1m',
              annotations: {
                description: 'Does not fire!',
                message: 'Alert not fired.',
              },
              labels: {
                severity: 'page',
              },
            },
          ],
        },
        {
          interval: '30s',
          name: 'reloader-slo-record',
          rules: [
            {
              record: 'AlwaysRecord',
              expr: 'vector(1)',
              labels: {
                test: 'slo-record',
              },
            },
            {
              record: 'NeverRecord',
              expr: 'vector(0) == 1',
              labels: {
                test: 'slo-record',
              },
            },
          ],
        },
        {
          interval: '30s',
          name: 'reloader-slo-combined',
          rules: [
            {
              record: 'CombinedRecord',
              expr: 'vector(1)',
              labels: {
                test: 'slo-record',
              },
            },
            {
              alert: 'CombinedAlert',
              expr: 'vector(1)',
              'for': '1m',
              annotations: {
                description: 'Combined alert firing!',
                message: 'Combined alert fired.',
              },
              labels: {
                severity: 'page',
              },
            },
          ],
        },
      ],
    },
  },

  rulesObjstore:: rulesObjstore({
    local cfg = self,
    name: 'rules-objstore',
    version: '${RULES_OBJSTORE_IMAGE_TAG}',
    image: '%s:%s' % ['${RULES_OBJSTORE_IMAGE}', cfg.version],
    logLevel: '${RULES_OBJSTORE_LOG_LEVEL}',
    replicas: '${{RULES_OBJSTORE_REPLICAS}}',
    objectStorageConfig: {
      name: '${RULES_OBJSTORE_SECRET}',
      key: 'objstore.yaml',
    },
    commonLabels+:: obs.config.commonLabels,
    serviceMonitor: true,
  }) + {
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'rules-objstore' then c {
                env+: [
                  {
                    name: 'AWS_ACCESS_KEY_ID',
                    valueFrom: {
                      secretKeyRef: {
                        key: 'aws_access_key_id',
                        name: '${RULES_OBJSTORE_S3_SECRET}',
                      },
                    },
                  },
                  {
                    name: 'AWS_SECRET_ACCESS_KEY',
                    valueFrom: {
                      secretKeyRef: {
                        key: 'aws_secret_access_key',
                        name: '${RULES_OBJSTORE_S3_SECRET}',
                      },
                    },
                  },
                ],
              } else c
              for c in super.containers
            ],
          },
        },
      },
    },

    serviceMonitor+: {
      metadata+: {
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
    logLevel: '${OBSERVATORIUM_API_LOG_LEVEL}',
    serviceMonitor: true,
    metrics: {
      readEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
        obs.thanos.queryFrontend.service.metadata.name,
        obs.config.namespaces.metrics,
        obs.thanos.queryFrontend.service.spec.ports[0].port,
      ],
      writeEndpoint: 'http://%s.%s.svc.cluster.local:%s' % [
        '${METRICS_WRITE_SERVICE_NAME}',
        obs.config.namespaces.metrics,
        '${METRICS_WRITE_SERVICE_PORT}',
      ],
      rulesEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
        obs.rulesObjstore.service.metadata.name,
        obs.config.namespaces.default,
        obs.rulesObjstore.service.spec.ports[1].port,
      ],
    },
    alertmanager: {
      endpoint: '${ALERTMANAGER_API_ENDPOINT}',
    },
    rateLimiter: {
      grpcAddress: '%s.%s.svc.cluster.local:%d' % [
        obs.gubernator.service.metadata.name,
        obs.config.namespaces.default,
        obs.gubernator.config.ports.grpc,
      ],
    },
    rbac: (import '../resources/.tmp/tenants/rbac.json'),
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
      collectorAddress: 'dns:///${TRACING_COLLECTOR_ENDPOINT}',
    }),

    local opaAms = (import 'sidecars/opa-ams.libsonnet')({
      image: '${OPA_AMS_IMAGE}:${OPA_AMS_IMAGE_TAG}',
      clientIDKey: 'client-id',
      clientSecretKey: 'client-secret',
      secretName: obs.api.config.name,
      issuerURLKey: 'issuer-url',
      amsURL: '${AMS_URL}',
      mappings: [
        'osd=${OSD_ORGANIZATION_ID}',
        'osd=${SD_OPS_ORGANIZATION_ID}',
        'cnvqe=${CNVQE_ORGANIZATION_ID}',
      ],
      memcached: '%s.%s.svc.cluster.local:%d' % [
        obs.memcached.service.metadata.name,
        obs.config.namespaces.default,
        obs.memcached.service.spec.ports[0].port,
      ],
      memcachedExpire: '${OPA_AMS_MEMCACHED_EXPIRE}',
      opaPackage: 'observatorium',
      logLevel: '${OPA_AMS_LOG_LEVEL}',
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

    secret+: {
      stringData+: {
        'client-id': 'test',
        'client-secret': 'ZXhhbXBsZS1hcHAtc2VjcmV0',
        'issuer-url': 'http://dex.dex.svc.cluster.local:5556/dex',
      },
    },
  },

  up:: up({
    local cfg = self,
    name: obs.config.name + '-' + cfg.commonLabels['app.kubernetes.io/name'],
    namespace: obs.config.namespaces.default,
    commonLabels+:: obs.config.commonLabels,
    version: 'master-2022-03-24-098c31a',
    image: 'quay.io/observatorium/up:' + cfg.version,
    replicas: 1,
    endpointType: 'metrics',
    readEndpoint: 'http://%s.%s.svc:9090' % [obs.thanos.queryFrontend.service.metadata.name, obs.config.namespaces.metrics],
    queryConfig: (import '../configuration/observatorium/queries.libsonnet'),
    serviceMonitor: true,
    resources: {
      requests: {
        cpu: '${UP_CPU_REQUEST}',
        memory: '${UP_MEMORY_REQUEST}',
      },
      limits: {
        cpu: '${UP_CPU_LIMIT}',
        memory: '${UP_MEMORY_LIMIT}',
      },
    },
  }) {
    deployment+: {
      spec+: {
        replicas: '${{UP_REPLICAS}}',
      },
    },
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
    configmap+: {
      metadata+: {
        annotations+: { 'qontract.recycle': 'true' },
      },
    },
  },

  upRuler:: up({
    local cfg = self,
    name: obs.config.name + '-' + cfg.commonLabels['app.kubernetes.io/name'] + '-' + 'ruler',
    namespace: obs.config.namespaces.default,
    commonLabels+:: obs.config.commonLabels,
    version: 'master-2022-03-24-098c31a',
    image: 'quay.io/observatorium/up:' + cfg.version,
    replicas: 1,
    endpointType: 'metrics',
    readEndpoint: 'http://%s.%s.svc:9090' % [obs.thanos.rulerQuery.service.metadata.name, obs.config.namespaces.metrics],
    queryConfig: (import '../configuration/observatorium/queries-ruler.libsonnet'),
    serviceMonitor: true,
    resources: {
      requests: {
        cpu: '${UP_CPU_REQUEST}',
        memory: '${UP_MEMORY_REQUEST}',
      },
      limits: {
        cpu: '${UP_CPU_LIMIT}',
        memory: '${UP_MEMORY_LIMIT}',
      },
    },
  }) {
    deployment+: {
      spec+: {
        replicas: '${{UP_REPLICAS}}',
      },
    },
    serviceMonitor+: {
      metadata+: {
        name: 'observatorium-up-ruler',
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
    configmap+: {
      metadata+: {
        annotations+: { 'qontract.recycle': 'true' },
      },
    },
  },


  avalanche:: {

    local config = {
      name: 'avalanche-remote-writer',
      image: 'quay.io/observatorium/avalanche:make-tenant-header-configurable-2021-10-07-0a2cbf5',
      commonLabels: {
        'app.kubernetes.io/component': 'avalanche',
        'app.kubernetes.io/name': 'avalanche-remote-writer',
        'app.kubernetes.io/part-of': 'observatorium',
      },
    },
    deployment: {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: config.name,
        labels: config.commonLabels,
        namespace: obs.config.namespaces.metrics,
      },
      spec: {
        replicas: '${{AVALANCHE_REPLICAS}}',
        selector: { matchLabels: config.commonLabels },
        template: {
          metadata: {
            labels: config.commonLabels,
          },
          spec: {
            containers: [{
              name: config.name,
              image: config.image,
              args: [
                '--metric-count=1',  // we only get one metric __name__
                '--series-count=8333',  // this is set so that we write 1M samples per hour to our test tenant
                '--remote-url=http://%s.%s.svc.cluster.local:%s/api/v1/receive' % [
                  '${METRICS_WRITE_SERVICE_NAME}',
                  obs.config.namespaces.metrics,
                  '${METRICS_WRITE_SERVICE_PORT}',
                ],  // this is the internal cluster url of the thanos receive service
                '--remote-write-interval=30s',  // how frequently to remote_write data
                '--remote-requests-count=1000000',  // how many requests we make before exiting - make it a big number
                '--value-interval=3600',  // how often to update the metric values
                '--series-interval=315360000',  // 10y - how often to create new series names
                '--metric-interval=315360000',  // 10y - how often to create new metric names
                '--remote-tenant-header=THANOS-TENANT',  // this is tenant header to set in remote write requests
                '--remote-tenant=0fc2b00e-201b-4c17-b9f2-19d91adc4fd2',  // this is tenant we will write data to
              ],
            }],
          },
        },
      },
    },
  },

  manifests+:: {
    ['observatorium-up-' + name]: obs.up[name]
    for name in std.objectFields(obs.up)
    if obs.up[name] != null
  } + {
    ['observatorium-up-ruler-' + name]: obs.upRuler[name]
    for name in std.objectFields(obs.upRuler)
    if obs.upRuler[name] != null
  } + {
    ['observatorium-cache-' + name]: obs.memcached[name]
    for name in std.objectFields(obs.memcached)
    if obs.memcached[name] != null
  } + {
    ['observatorium-avalanche-' + name]: obs.avalanche[name]
    for name in std.objectFields(obs.avalanche)
    if obs.avalanche[name] != null
  } + {
    ['observatorium-rules-objstore-' + name]: obs.rulesObjstore[name]
    for name in std.objectFields(obs.rulesObjstore)
    if obs.rulesObjstore[name] != null
  } + {
    ['observatorium-obsctl-reloader-' + name]: obs.obsctlReloader[name]
    for name in std.objectFields(obs.obsctlReloader)
    if obs.obsctlReloader[name] != null
  } + {
    'observatorium-rules-slo-prom-rule': obs.rulesSLOPrometheusRule,
  },
}
