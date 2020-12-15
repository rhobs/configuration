local obs = import 'observatorium.libsonnet';
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
  tenantID: 'FB870BF3-9F3A-44FF-9BF7-D7A047A52F43',
});

{
  apiVersion: 'v1',
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
  ],
  parameters: [
    { name: 'NAMESPACE', value: 'telemeter' },
    { name: 'STORAGE_CLASS', value: 'gp2' },
    { name: 'IMAGE', value: 'quay.io/openshift/origin-telemeter' },
    { name: 'IMAGE_TAG', value: 'v4.0' },
    { name: 'REPLICAS', value: '10' },
    { name: 'IMAGE_CANARY', value: 'quay.io/openshift/origin-telemeter' },
    { name: 'IMAGE_CANARY_TAG', value: 'v4.0' },
    { name: 'REPLICAS_CANARY', value: '0' },
    { name: 'TELEMETER_FORWARD_URL', value: '' },
    { name: 'TELEMETER_SERVER_TOKEN_EXPIRE_SECONDS', value: '3600' },
    { name: 'TELEMETER_LOG_LEVEL', value: 'warn' },
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
    { name: 'PROMETHEUS_IMAGE', value: 'quay.io/prometheus/prometheus' },
    { name: 'PROMETHEUS_VERSION', value: 'v2.12.0' },
    { name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_IMAGE', value: 'quay.io/app-sre/observatorium-receive-proxy' },
    { name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_VERSION', value: '14e844d' },
    { name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_TARGET', value: 'observatorium-thanos-receive' },
  ],
}
