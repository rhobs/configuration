local telemeter = (import 'telemeter.libsonnet') {
  _config+:: {
    namespace: '${NAMESPACE}',

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

      whitelist+: (import '../configuration/telemeter/metrics.json') + (import '../configuration/telemeter-rosa/metrics.json'),
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
  },

  memcached+:: {
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
    exporter+:: {
      resourceLimits:: {
        cpu: '${MEMCACHED_EXPORTER_CPU_LIMIT}',
        memory: '${MEMCACHED_EXPORTER_MEMORY_LIMIT}',
      },
      resourceRequests:: {
        cpu: '${MEMCACHED_EXPORTER_CPU_REQUEST}',
        memory: '${MEMCACHED_EXPORTER_MEMORY_REQUEST}',
      },
    },
  },
};
local prometheusAms = (import 'prometheus/remote-write-proxy.libsonnet')({
  name: 'prometheus-ams',
  namespace: '${NAMESPACE}',
  version: '${PROMETHEUS_AMS_REMOTE_WRITE_PROXY_VERSION}',
  image: '${PROMETHEUS_AMS_REMOTE_WRITE_PROXY_IMAGE}:${PROMETHEUS_AMS_REMOTE_WRITE_PROXY_VERSION}',
  target: '${PROMETHEUS_AMS_REMOTE_WRITE_PROXY_TARGET}',
  targetPort: '${PROMETHEUS_AMS_REMOTE_WRITE_PROXY_PORT}',
  targetNamespace: '${OBSERVATORIUM_METRICS_NAMESPACE}',
  tenantID: 'FB870BF3-9F3A-44FF-9BF7-D7A047A52F43',
});

local oauthProxy = import './sidecars/oauth-proxy.libsonnet';

local tr = (import 'github.com/observatorium/token-refresher/jsonnet/lib/token-refresher.libsonnet')({
  name: 'telemeter-token-refresher',
  namespace: '${NAMESPACE}',
  version: '${TOKEN_REFRESHER_IMAGE_TAG}',
  url: 'http://observatorium-observatorium-api.${OBSERVATORIUM_NAMESPACE}.svc:8080/api/metrics/v1/telemeter',
  secretName: '${TOKEN_REFRESHER_SECRET_NAME}',
  logLevel: '${TOKEN_REFRESHER_LOG_LEVEL}',
  serviceMonitor: true,
}) + {
  local tr = self,
  config+:: {
    serviceAccountName: '${SERVICE_ACCOUNT_NAME}',
  },

  local oauth = oauthProxy({
    name: 'token-refresher',
    image: '${OAUTH_PROXY_IMAGE}:${OAUTH_PROXY_IMAGE_TAG}',
    upstream: 'http://localhost:8080',
    serviceAccountName: tr.config.serviceAccountName,
    sessionSecretName: 'token-refresher-proxy',
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

  proxySecret: oauth.proxySecret {
    metadata+: { labels+: tr.config.commonLabels },
  },

  service+: oauth.service,

  deployment+: oauth.deployment,

  serviceMonitor+: {
    spec+: {
      namespaceSelector: {
        matchNames: ['${NAMESPACE}'],
      },
    },
  },
};

{
  apiVersion: 'template.openshift.io/v1',
  kind: 'Template',
  metadata: { name: 'telemeter' },
  objects: [
    telemeter.telemeterServer[name] {
      metadata+: { namespace:: 'hidden' },
    }
    for name in std.objectFields(telemeter.telemeterServer)
  ] + [
    telemeter.memcached[name] {
      metadata+: { namespace:: 'hidden' },
    }
    for name in std.objectFields(telemeter.memcached)
  ] + [
    prometheusAms[name] {
      metadata+: { namespace:: 'hidden' },
    }
    for name in std.objectFields(prometheusAms)
  ] + [
    tr[name] {
      metadata+: { namespace:: 'hidden' },
    }
    for name in std.objectFields(tr)
  ],
  parameters: [
    { name: 'NAMESPACE', value: 'telemeter' },

    { name: 'IMAGE_CANARY_TAG', value: 'b4f226c' },
    { name: 'IMAGE_CANARY', value: 'quay.io/app-sre/telemeter' },
    { name: 'IMAGE_TAG', value: 'df72531' },
    { name: 'IMAGE', value: 'quay.io/app-sre/telemeter' },
    { name: 'MEMCACHED_CPU_LIMIT', value: '3' },
    { name: 'MEMCACHED_CPU_REQUEST', value: '500m' },
    { name: 'MEMCACHED_EXPORTER_CPU_LIMIT', value: '200m' },
    { name: 'MEMCACHED_EXPORTER_CPU_REQUEST', value: '50m' },
    { name: 'MEMCACHED_EXPORTER_IMAGE_TAG', value: 'v0.6.0' },
    { name: 'MEMCACHED_EXPORTER_IMAGE', value: 'docker.io/prom/memcached-exporter' },
    { name: 'MEMCACHED_EXPORTER_MEMORY_LIMIT', value: '200Mi' },
    { name: 'MEMCACHED_EXPORTER_MEMORY_REQUEST', value: '50Mi' },
    { name: 'MEMCACHED_IMAGE_TAG', value: '1.6.13-alpine' },
    { name: 'MEMCACHED_IMAGE', value: 'docker.io/memcached' },
    { name: 'MEMCACHED_MEMORY_LIMIT', value: '1844Mi' },
    { name: 'MEMCACHED_MEMORY_REQUEST', value: '1329Mi' },
    { name: 'OAUTH_PROXY_IMAGE', value: 'quay.io/openshift/origin-oauth-proxy' },
    { name: 'OAUTH_PROXY_IMAGE_TAG', value: '4.7.0' },
    { name: 'OAUTH_PROXY_CPU_REQUEST', value: '100m' },
    { name: 'OAUTH_PROXY_MEMORY_REQUEST', value: '100Mi' },
    { name: 'OAUTH_PROXY_CPU_LIMITS', value: '200m' },
    { name: 'OAUTH_PROXY_MEMORY_LIMITS', value: '200Mi' },
    { name: 'OBSERVATORIUM_NAMESPACE', value: 'observatorium' },
    { name: 'OBSERVATORIUM_METRICS_NAMESPACE', value: 'observatorium-metrics' },
    { name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_IMAGE', value: 'quay.io/app-sre/observatorium-receive-proxy' },
    { name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_TARGET', value: 'observatorium-thanos-receive' },
    { name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_PORT', value: '19291' },
    { name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_VERSION', value: '14e844d' },
    { name: 'PROMETHEUS_IMAGE', value: 'quay.io/prometheus/prometheus' },
    { name: 'PROMETHEUS_VERSION', value: 'v2.12.0' },
    { name: 'REPLICAS_CANARY', value: '0' },
    { name: 'REPLICAS', value: '10' },
    { name: 'SERVICE_ACCOUNT_NAME', value: 'prometheus-telemeter' },
    { name: 'STORAGE_CLASS', value: 'gp2' },
    { name: 'TELEMETER_FORWARD_URL', value: '' },
    { name: 'TELEMETER_LOG_LEVEL', value: 'warn' },
    { name: 'TELEMETER_SERVER_CPU_LIMIT', value: '1' },
    { name: 'TELEMETER_SERVER_CPU_REQUEST', value: '100m' },
    { name: 'TELEMETER_SERVER_MEMORY_LIMIT', value: '1Gi' },
    { name: 'TELEMETER_SERVER_MEMORY_REQUEST', value: '500Mi' },
    { name: 'TELEMETER_SERVER_TOKEN_EXPIRE_SECONDS', value: '3600' },
    { name: 'TOKEN_REFRESHER_IMAGE_TAG', value: 'master-2021-03-05-b34376b' },
    { name: 'TOKEN_REFRESHER_LOG_LEVEL', value: 'info' },
    { name: 'TOKEN_REFRESHER_SECRET_NAME', value: 'token-refresher-oidc' },
  ],
}
