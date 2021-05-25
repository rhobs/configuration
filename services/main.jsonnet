// TODO(kakkoyun): Remove after CI/CD job migration.
local api = (import 'github.com/observatorium/api/jsonnet/lib/observatorium-api.libsonnet');
local up = (import 'github.com/observatorium/up/jsonnet/up.libsonnet');
local gubernator = (import 'github.com/observatorium/observatorium/configuration/components/gubernator.libsonnet');

local observatorium =
  (import 'github.com/observatorium/observatorium/configuration/components/observatorium.libsonnet') +
  (import 'observatorium-metrics.libsonnet') +
  (import 'observatorium-metrics-template-overwrites.libsonnet') +
  (import 'observatorium-logs.libsonnet') +
  (import 'observatorium-logs-template-overwrites.libsonnet') +
  {
    local obs = self,

    config:: {
      name: 'observatorium',
      namespace: '${NAMESPACE}',

      commonLabels:: {
        'app.kubernetes.io/part-of': 'observatorium',
        'app.kubernetes.io/instance': obs.config.name,
      },
    },

    gubernator:: gubernator({
      local cfg = self,
      name: obs.config.name + '-' + cfg.commonLabels['app.kubernetes.io/name'],
      namespace: obs.config.namespace,
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
          namespaceSelector+: {
            matchNames+: [
              '${NAMESPACE}',
              '${MST_NAMESPACE}',  // TODO(kakkoyun): Remove when we find more permenant solution.
            ],
          },
        },
      },
    },

    api:: api({
      local cfg = self,
      name: 'observatorium-observatorium-api',
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
          obs.thanos.queryFrontend.service.metadata.name,
          obs.thanos.queryFrontend.service.metadata.namespace,
          obs.thanos.queryFrontend.service.spec.ports[0].port,
        ],
        writeEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
          obs.thanos.receiversService.metadata.name,
          obs.thanos.receiversService.metadata.namespace,
          obs.thanos.receiversService.spec.ports[2].port,
        ],
      },
      rateLimiter: {
        grpcAddress: '%s.%s.svc.cluster.local:%d' % [
          obs.gubernator.service.metadata.name,
          obs.gubernator.service.metadata.namespace,
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

      local opaAms = (import './sidecars/opa-ams.libsonnet')({
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
        memcached: 'memcached-0.memcached.${NAMESPACE}.svc.cluster.local:11211',
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
          namespaceSelector+: {
            matchNames+: [
              '${NAMESPACE}',
              '${MST_NAMESPACE}',  // TODO(kakkoyun): Remove when we find more permenant solution.
            ],
          },
        },
      } + opaAms.serviceMonitor,
    },

    up:: up({
      local cfg = self,
      name: obs.config.name + '-' + cfg.commonLabels['app.kubernetes.io/name'],
      namespace: obs.config.namespace,
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
        spec+: { namespaceSelector+: {
          matchNames: [
            '${NAMESPACE}',
            '${MST_NAMESPACE}',  // TODO(kakkoyun): Remove when we find more permenant solution.
          ],
        } },
      },
    },

    manifests+:: {
      ['observatorium-up-' + name]: obs.up[name]
      for name in std.objectFields(obs.up)
      if obs.up[name] != null
    },
  } + {
    local obs = self,

    local telemeter = (import 'telemeter.libsonnet') {
      _config+:: {
        namespace: obs.config.namespace,

        telemeterServerCanary:: {
          image: '${IMAGE_CANARY}:${IMAGE_CANARY_TAG}',
          replicas: '${{REPLICAS_CANARY}}',
        },

        telemeterServer+:: {
          image: '${IMAGE}:${IMAGE_TAG}',
          replicas: '${{REPLICAS}}',
          logLevel: '${TELEMETER_LOG_LEVEL}',
          tokenExpireSeconds: '${TELEMETER_SERVER_TOKEN_EXPIRE_SECONDS}',
          telemeterForwardURL: '${TELEMETER_FORWARD_URL}',

          whitelist+: (import '../configuration/telemeter/metrics.json'),
          elideLabels+: ['prometheus_replica'],
          resourceLimits:: {
            cpu: '${TELEMETER_SERVER_CPU_LIMIT}',
            memory: '${TELEMETER_SERVER_MEMORY_LIMIT}',
          },
          resourceRequests:: {
            cpu: '${TELEMETER_SERVER_CPU_REQUEST}',
            memory: '${TELEMETER_SERVER_MEMORY_REQUEST}',
          },
        },

        memcachedExporter+:: {
          resourceLimits: {
            cpu: '${MEMCACHED_EXPORTER_CPU_LIMIT}',
            memory: '${MEMCACHED_EXPORTER_MEMORY_LIMIT}',
          },
          resourceRequests: {
            cpu: '${MEMCACHED_EXPORTER_CPU_REQUEST}',
            memory: '${MEMCACHED_EXPORTER_MEMORY_REQUEST}',
          },
        },
      },

      memcached+:: {
        replicas:: 1,
        images:: {
          memcached: '${MEMCACHED_IMAGE}',
          exporter: '${MEMCACHED_EXPORTER_IMAGE}',
        },
        tags:: {
          memcached: '${MEMCACHED_IMAGE_TAG}',
          exporter: '${MEMCACHED_EXPORTER_IMAGE_TAG}',
        },
        resourceLimits:: {
          cpu: '${MEMCACHED_CPU_LIMIT}',
          memory: '${MEMCACHED_MEMORY_LIMIT}',
        },
        resourceRequests:: {
          cpu: '${MEMCACHED_CPU_REQUEST}',
          memory: '${MEMCACHED_MEMORY_REQUEST}',
        },
      },
    },

    local prometheusAms = (import 'prometheus/remote-write-proxy.libsonnet')({
      name: 'prometheus-ams',
      namespace: '${NAMESPACE}',
      version: '${PROMETHEUS_AMS_REMOTE_WRITE_PROXY_VERSION}',
      image: '${PROMETHEUS_AMS_REMOTE_WRITE_PROXY_IMAGE}:${PROMETHEUS_AMS_REMOTE_WRITE_PROXY_VERSION}',
      target: '${PROMETHEUS_AMS_REMOTE_WRITE_PROXY_TARGET}',
      tenantID: 'FB870BF3-9F3A-44FF-9BF7-D7A047A52F43',
    }),

    local observatoriumNamespace = 'telemeter',
    local observatoriumLogsNamespace = 'observatorium-logs',

    metricsOpenshiftTemplate:: {
      apiVersion: 'v1',
      kind: 'Template',
      metadata: { name: 'observatorium' },
      objects:
        [
          obs.manifests[name] {
            metadata+: { namespace:: 'hidden' },
          }
          for name in std.objectFields(obs.manifests)
          if obs.manifests[name] != null &&
        !std.startsWith(name, 'thanos-') &&
        !std.startsWith(name, 'loki-')
        ] +
        [
          obs.thanos.manifests[name] {
            metadata+: { namespace:: 'hidden' },
          }
          for name in std.objectFields(obs.thanos.manifests)
          if obs.thanos.manifests[name] != null
        ] +
        [
          telemeter.telemeterServer[name] {
            metadata+: { namespace:: 'hidden' },
          }
          for name in std.objectFields(telemeter.telemeterServer)
        ] +
        [
          telemeter.memcached[name] {
            metadata+: { namespace:: 'hidden' },
          }
          for name in std.objectFields(telemeter.memcached)
        ] +
        [
          prometheusAms[name] {
            metadata+: { namespace:: 'hidden' },
          }
          for name in std.objectFields(prometheusAms)
        ],
      parameters: [
        { name: 'NAMESPACE', value: observatoriumNamespace },
        { name: 'MST_NAMESPACE', value: 'observatorium-mst-production' },
        { name: 'OBSERVATORIUM_METRICS_NAMESPACE', value: observatoriumNamespace },
        { name: 'OBSERVATORIUM_LOGS_NAMESPACE', value: observatoriumLogsNamespace },
        { name: 'SERVICE_ACCOUNT_NAME', value: 'prometheus-telemeter' },
        { name: 'THANOS_IMAGE', value: 'quay.io/thanos/thanos' },
        { name: 'THANOS_IMAGE_TAG', value: 'master-2020-08-12-70f89d83' },
        { name: 'STORAGE_CLASS', value: 'gp2' },
        { name: 'JAEGER_AGENT_IMAGE', value: 'jaegertracing/jaeger-agent' },
        { name: 'JAEGER_AGENT_IMAGE_TAG', value: '1.14.0' },
        { name: 'JAEGER_COLLECTOR_NAMESPACE', value: '$(NAMESPACE)' },
        { name: 'THANOS_RECEIVE_CONTROLLER_IMAGE', value: 'quay.io/observatorium/thanos-receive-controller' },
        { name: 'THANOS_RECEIVE_CONTROLLER_IMAGE_TAG', value: 'master-2019-10-18-d55fee2' },
        { name: 'THANOS_QUERIER_REPLICAS', value: '3' },
        { name: 'THANOS_STORE_REPLICAS', value: '5' },
        { name: 'THANOS_COMPACTOR_LOG_LEVEL', value: 'info' },
        { name: 'THANOS_COMPACTOR_RETENTION_RESOULTION_RAW', value: '14d' },
        { name: 'THANOS_COMPACTOR_RETENTION_RESOULTION_FIVE_MINUTES', value: '1s' },
        { name: 'THANOS_COMPACTOR_RETENTION_RESOULTION_ONE_HOUR', value: '1s' },
        { name: 'THANOS_COMPACTOR_DISABLE_DOWNSAMPLING', value: 'true' },
        { name: 'THANOS_COMPACTOR_REPLICAS', value: '1' },
        { name: 'THANOS_RECEIVE_REPLICAS', value: '5' },
        { name: 'THANOS_CONFIG_SECRET', value: 'thanos-objectstorage' },
        { name: 'THANOS_S3_SECRET', value: 'telemeter-thanos-stage-s3' },
        { name: 'THANOS_QUERIER_LOG_LEVEL', value: 'info' },
        { name: 'THANOS_QUERIER_CPU_REQUEST', value: '100m' },
        { name: 'THANOS_QUERIER_CPU_LIMIT', value: '1' },
        { name: 'THANOS_QUERIER_MEMORY_REQUEST', value: '256Mi' },
        { name: 'THANOS_QUERIER_MEMORY_LIMIT', value: '1Gi' },
        { name: 'THANOS_QUERY_FRONTEND_REPLICAS', value: '3' },
        { name: 'THANOS_QUERY_FRONTEND_CPU_REQUEST', value: '100m' },
        { name: 'THANOS_QUERY_FRONTEND_CPU_LIMIT', value: '1' },
        { name: 'THANOS_QUERY_FRONTEND_MEMORY_REQUEST', value: '256Mi' },
        { name: 'THANOS_QUERY_FRONTEND_MEMORY_LIMIT', value: '1Gi' },
        { name: 'THANOS_QUERY_FRONTEND_SPLIT_INTERVAL', value: '24h' },
        { name: 'THANOS_QUERY_FRONTEND_MAX_RETRIES', value: '0' },
        { name: 'THANOS_QUERY_FRONTEND_LOG_QUERIES_LONGER_THAN', value: '5s' },
        { name: 'THANOS_STORE_LOG_LEVEL', value: 'info' },
        { name: 'THANOS_STORE_CPU_REQUEST', value: '500m' },
        { name: 'THANOS_STORE_CPU_LIMIT', value: '2' },
        { name: 'THANOS_STORE_MEMORY_REQUEST', value: '1Gi' },
        { name: 'THANOS_STORE_MEMORY_LIMIT', value: '8Gi' },
        { name: 'THANOS_STORE_INDEX_CACHE_REPLICAS', value: '3' },
        { name: 'THANOS_STORE_INDEX_CACHE_MEMORY_LIMIT_MB', value: '2048' },
        { name: 'THANOS_STORE_INDEX_CACHE_CONNECTION_LIMIT', value: '3072' },
        { name: 'THANOS_STORE_INDEX_CACHE_MEMCACHED_CPU_REQUEST', value: '500m' },
        { name: 'THANOS_STORE_INDEX_CACHE_MEMCACHED_CPU_LIMIT', value: '3' },
        { name: 'THANOS_STORE_INDEX_CACHE_MEMCACHED_MEMORY_REQUEST', value: '2558Mi' },
        { name: 'THANOS_STORE_INDEX_CACHE_MEMCACHED_MEMORY_LIMIT', value: '3Gi' },
        { name: 'THANOS_STORE_BUCKET_CACHE_REPLICAS', value: '3' },
        { name: 'THANOS_STORE_BUCKET_CACHE_MEMORY_LIMIT_MB', value: '2048' },
        { name: 'THANOS_STORE_BUCKET_CACHE_CONNECTION_LIMIT', value: '3072' },
        { name: 'THANOS_STORE_BUCKET_CACHE_MEMCACHED_CPU_REQUEST', value: '500m' },
        { name: 'THANOS_STORE_BUCKET_CACHE_MEMCACHED_CPU_LIMIT', value: '3' },
        { name: 'THANOS_STORE_BUCKET_CACHE_MEMCACHED_MEMORY_REQUEST', value: '2558Mi' },
        { name: 'THANOS_STORE_BUCKET_CACHE_MEMCACHED_MEMORY_LIMIT', value: '3Gi' },
        { name: 'THANOS_RECEIVE_CPU_REQUEST', value: '1' },
        { name: 'THANOS_RECEIVE_CPU_LIMIT', value: '1' },
        { name: 'THANOS_RECEIVE_MEMORY_REQUEST', value: '1Gi' },
        { name: 'THANOS_RECEIVE_MEMORY_LIMIT', value: '1Gi' },
        { name: 'THANOS_RECEIVE_DEBUG_ENV', value: '' },
        { name: 'THANOS_RECEIVE_LOG_LEVEL', value: 'info' },
        { name: 'THANOS_COMPACTOR_CPU_REQUEST', value: '100m' },
        { name: 'THANOS_COMPACTOR_CPU_LIMIT', value: '1' },
        { name: 'THANOS_COMPACTOR_MEMORY_REQUEST', value: '1Gi' },
        { name: 'THANOS_COMPACTOR_MEMORY_LIMIT', value: '5Gi' },
        { name: 'THANOS_COMPACTOR_PVC_REQUEST', value: '50Gi' },
        { name: 'THANOS_RULER_LOG_LEVEL', value: 'info' },
        { name: 'THANOS_RULER_REPLICAS', value: '2' },
        { name: 'THANOS_RULER_CPU_REQUEST', value: '100m' },
        { name: 'THANOS_RULER_CPU_LIMIT', value: '1' },
        { name: 'THANOS_RULER_MEMORY_REQUEST', value: '512Mi' },
        { name: 'THANOS_RULER_MEMORY_LIMIT', value: '1Gi' },
        { name: 'THANOS_RULER_PVC_REQUEST', value: '50Gi' },
        { name: 'THANOS_QUERIER_SVC_URL', value: 'http://thanos-querier.observatorium.svc:9090' },
        { name: 'GUBERNATOR_IMAGE', value: 'thrawn01/gubernator' },
        { name: 'GUBERNATOR_IMAGE_TAG', value: '1.0.0-rc.1' },
        { name: 'GUBERNATOR_REPLICAS', value: '2' },
        { name: 'GUBERNATOR_CPU_REQUEST', value: '100m' },
        { name: 'GUBERNATOR_CPU_LIMIT', value: '200m' },
        { name: 'GUBERNATOR_MEMORY_REQUEST', value: '100Mi' },
        { name: 'GUBERNATOR_MEMORY_LIMIT', value: '200Mi' },
        { name: 'OBSERVATORIUM_API_IMAGE', value: 'quay.io/observatorium/api' },
        { name: 'OBSERVATORIUM_API_IMAGE_TAG', value: 'master-2021-03-26-v0.1.1-200-gea0242a' },
        { name: 'OBSERVATORIUM_API_REPLICAS', value: '3' },
        { name: 'OBSERVATORIUM_API_CPU_REQUEST', value: '100m' },
        { name: 'OBSERVATORIUM_API_CPU_LIMIT', value: '1' },
        { name: 'OBSERVATORIUM_API_MEMORY_REQUEST', value: '256Mi' },
        { name: 'OBSERVATORIUM_API_MEMORY_LIMIT', value: '1Gi' },
        { name: 'OBSERVATORIUM_API_IMAGE_TAG', value: 'master-2021-03-29-v0.1.1-201-gd40a037' },
        { name: 'OBSERVATORIUM_API_PER_POD_CONCURRENT_REQUETST_LIMIT', value: '50' },
        { name: 'AMS_URL', value: '' },
        { name: 'OPA_AMS_IMAGE', value: 'quay.io/observatorium/opa-ams' },
        { name: 'OPA_AMS_IMAGE_TAG', value: 'master-2021-02-17-ed50046' },
        { name: 'OPA_AMS_MEMCACHED_EXPIRE', value: '300' },
        { name: 'OPA_AMS_CPU_REQUEST', value: '100m' },
        { name: 'OPA_AMS_MEMORY_REQUEST', value: '100Mi' },
        { name: 'OPA_AMS_CPU_LIMIT', value: '200m' },
        { name: 'OPA_AMS_MEMORY_LIMIT', value: '200Mi' },
        { name: 'OSD_ORGANIZATION_ID', value: '' },
        { name: 'DPTP_ORGANIZATION_ID', value: '' },
        { name: 'MANAGEDKAFKA_ORGANIZATION_ID', value: '' },
        { name: 'OAUTH_PROXY_IMAGE', value: 'quay.io/openshift/origin-oauth-proxy' },
        { name: 'OAUTH_PROXY_IMAGE_TAG', value: '4.7.0' },
        { name: 'OAUTH_PROXY_CPU_REQUEST', value: '100m' },
        { name: 'OAUTH_PROXY_MEMORY_REQUEST', value: '100Mi' },
        { name: 'OAUTH_PROXY_CPU_LIMITS', value: '200m' },
        { name: 'OAUTH_PROXY_MEMORY_LIMITS', value: '200Mi' },
        { name: 'IMAGE', value: 'quay.io/openshift/origin-telemeter' },
        { name: 'IMAGE_TAG', value: 'v4.0' },
        { name: 'REPLICAS', value: '10' },
        { name: 'IMAGE_CANARY', value: 'quay.io/openshift/origin-telemeter' },
        { name: 'IMAGE_CANARY_TAG', value: 'v4.0' },
        { name: 'REPLICAS_CANARY', value: '0' },
        { name: 'TELEMETER_SERVER_CPU_REQUEST', value: '100m' },
        { name: 'TELEMETER_SERVER_CPU_LIMIT', value: '1' },
        { name: 'TELEMETER_SERVER_MEMORY_REQUEST', value: '500Mi' },
        { name: 'TELEMETER_SERVER_MEMORY_LIMIT', value: '1Gi' },
        { name: 'MEMCACHED_IMAGE', value: 'docker.io/memcached' },
        { name: 'MEMCACHED_IMAGE_TAG', value: '1.5.20-alpine' },
        { name: 'MEMCACHED_EXPORTER_IMAGE', value: 'docker.io/prom/memcached-exporter' },
        { name: 'MEMCACHED_EXPORTER_IMAGE_TAG', value: 'v0.6.0' },
        { name: 'MEMCACHED_CPU_REQUEST', value: '500m' },
        { name: 'MEMCACHED_CPU_LIMIT', value: '3' },
        { name: 'MEMCACHED_MEMORY_REQUEST', value: '1329Mi' },
        { name: 'MEMCACHED_MEMORY_LIMIT', value: '1844Mi' },
        { name: 'MEMCACHED_EXPORTER_CPU_REQUEST', value: '50m' },
        { name: 'MEMCACHED_EXPORTER_CPU_LIMIT', value: '200m' },
        { name: 'MEMCACHED_EXPORTER_MEMORY_REQUEST', value: '50Mi' },
        { name: 'MEMCACHED_EXPORTER_MEMORY_LIMIT', value: '200Mi' },
        { name: 'TELEMETER_FORWARD_URL', value: '' },
        { name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_IMAGE', value: 'quay.io/app-sre/observatorium-receive-proxy' },
        { name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_VERSION', value: '14e844d' },
        { name: 'THANOS_RECEIVE_TSDB_PATH', value: '/var/thanos/receive' },
        { name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_TARGET', value: 'observatorium-thanos-receive' },
        { name: 'TELEMETER_SERVER_TOKEN_EXPIRE_SECONDS', value: '3600' },
        { name: 'TELEMETER_LOG_LEVEL', value: 'warn' },
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
        { name: 'NAMESPACE', value: observatoriumLogsNamespace },
        { name: 'STORAGE_CLASS', value: 'gp2' },
        { name: 'LOKI_IMAGE_TAG', value: 'v2.2.0-1' },
        { name: 'LOKI_IMAGE', value: 'quay.io/openshift-logging/loki' },
        { name: 'LOKI_S3_SECRET', value: 'observatorium-logs-stage-s3' },
        { name: 'LOKI_COMPACTOR_CPU_REQUESTS', value: '500m' },
        { name: 'LOKI_COMPACTOR_CPU_LIMITS', value: '1000m' },
        { name: 'LOKI_COMPACTOR_MEMORY_REQUESTS', value: '2Gi' },
        { name: 'LOKI_COMPACTOR_MEMORY_LIMITS', value: '4Gi' },
        { name: 'LOKI_DISTRIBUTOR_REPLICAS', value: '2' },
        { name: 'LOKI_DISTRIBUTOR_CPU_REQUESTS', value: '500m' },
        { name: 'LOKI_DISTRIBUTOR_CPU_LIMITS', value: '1000m' },
        { name: 'LOKI_DISTRIBUTOR_MEMORY_REQUESTS', value: '500Mi' },
        { name: 'LOKI_DISTRIBUTOR_MEMORY_LIMITS', value: '1Gi' },
        { name: 'LOKI_INGESTER_REPLICAS', value: '2' },
        { name: 'LOKI_INGESTER_CPU_REQUESTS', value: '1000m' },
        { name: 'LOKI_INGESTER_CPU_LIMITS', value: '2000m' },
        { name: 'LOKI_INGESTER_MEMORY_REQUESTS', value: '5Gi' },
        { name: 'LOKI_INGESTER_MEMORY_LIMITS', value: '10Gi' },
        { name: 'LOKI_QUERIER_REPLICAS', value: '2' },
        { name: 'LOKI_QUERIER_CPU_REQUESTS', value: '500m' },
        { name: 'LOKI_QUERIER_CPU_LIMITS', value: '500m' },
        { name: 'LOKI_QUERIER_MEMORY_REQUESTS', value: '600Mi' },
        { name: 'LOKI_QUERIER_MEMORY_LIMITS', value: '1200Mi' },
        { name: 'LOKI_QUERY_FRONTEND_REPLICAS', value: '2' },
        { name: 'LOKI_QUERY_FRONTEND_CPU_REQUESTS', value: '500m' },
        { name: 'LOKI_QUERY_FRONTEND_CPU_LIMITS', value: '500m' },
        { name: 'LOKI_QUERY_FRONTEND_MEMORY_REQUESTS', value: '600Mi' },
        { name: 'LOKI_QUERY_FRONTEND_MEMORY_LIMITS', value: '1200Mi' },
        // This value should be set equal t
        // LOKI_REPLICATION_FACTOR <= LOKI_INGESTER_REPLICAS
        { name: 'LOKI_REPLICATION_FACTOR', value: '2' },
        // The querier concurrency should be equal to (or less than) the CPU cores of the system the querier runs
        // A higher value will lead to a querier trying to process more requests than there are available
        // cores and will result in scheduling delays.
        // This value should be set equal to:
        //
        // std.floor( querier-concurrency / LOKI_QUERY_FRONTEND_REPLICAS)
        //
        // e.g. limit to N/2 worker threads per frontend, as we have two frontends.
        { name: 'LOKI_QUERY_PARALLELISM', value: '2' },
        { name: 'LOKI_CHUNK_CACHE_REPLICAS', value: '2' },
        { name: 'LOKI_INDEX_QUERY_CACHE_REPLICAS', value: '2' },
        { name: 'LOKI_RESULTS_CACHE_REPLICAS', value: '2' },
        { name: 'LOKI_PVC_REQUEST', value: '50Gi' },
        { name: 'JAEGER_COLLECTOR_NAMESPACE', value: observatoriumNamespace },
        { name: 'JAEGER_AGENT_IMAGE', value: 'jaegertracing/jaeger-agent' },
        { name: 'JAEGER_AGENT_IMAGE_TAG', value: '1.14.0' },
        { name: 'JAEGER_PROXY_CPU_REQUEST', value: '100m' },
        { name: 'JAEGER_PROXY_MEMORY_REQUEST', value: '100Mi' },
        { name: 'JAEGER_PROXY_CPU_LIMITS', value: '200m' },
        { name: 'JAEGER_PROXY_MEMORY_LIMITS', value: '200Mi' },
        { name: 'MEMCACHED_IMAGE', value: 'docker.io/memcached' },
        { name: 'MEMCACHED_IMAGE_TAG', value: '1.5.20-alpine' },
        { name: 'MEMCACHED_EXPORTER_IMAGE', value: 'docker.io/prom/memcached-exporter' },
        { name: 'MEMCACHED_EXPORTER_IMAGE_TAG', value: 'v0.6.0' },
        { name: 'MEMCACHED_CPU_REQUEST', value: '500m' },
        { name: 'MEMCACHED_CPU_LIMIT', value: '3' },
        { name: 'MEMCACHED_MEMORY_REQUEST', value: '1329Mi' },
        { name: 'MEMCACHED_MEMORY_LIMIT', value: '1844Mi' },
        { name: 'MEMCACHED_EXPORTER_CPU_REQUEST', value: '50m' },
        { name: 'MEMCACHED_EXPORTER_CPU_LIMIT', value: '200m' },
        { name: 'MEMCACHED_EXPORTER_MEMORY_REQUEST', value: '50Mi' },
        { name: 'MEMCACHED_EXPORTER_MEMORY_LIMIT', value: '200Mi' },
      ],
    },
  };

{
  'observatorium-template': observatorium.metricsOpenshiftTemplate,
  'observatorium-logs-template': observatorium.logsOpenShiftTemplate,
}
