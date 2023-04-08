local mixin = (import 'github.com/jaegertracing/jaeger/monitoring/jaeger-mixin/mixin.libsonnet');
local oauthProxy = import 'sidecars/oauth-proxy.libsonnet';

local jaeger = (import 'components/jaeger-collector.libsonnet')({
  namespace:: '${NAMESPACE}',
  image:: '${IMAGE}:${IMAGE_TAG}',
  version:: '${IMAGE_TAG}',
  replicas: 1,
  pvc+:: { class: '${STORAGE_CLASS}' },
  serviceMonitor: true,
}) + {
  local j = self,

  local oauth = oauthProxy({
    name: 'jaeger',
    image: '${OAUTH_PROXY_IMAGE}:${OAUTH_PROXY_IMAGE_TAG}',
    upstream: 'http://localhost:%d' % j.config.ports.query,
    serviceAccountName: '${SERVICE_ACCOUNT_NAME}',
    tlsSecretName: 'jaeger-query-tls',
    sessionSecretName: 'jaeger-proxy',
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
    metadata+: {
      labels+: {
        'app.kubernetes.io/component': 'tracing',
        'app.kubernetes.io/instance': 'observatorium',
        'app.kubernetes.io/name': 'jaeger',
        'app.kubernetes.io/part-of': 'observatorium',
      },
    },
  },

  queryService+: oauth.service,

  deployment+: {
    spec+: {
      replicas: '${{REPLICAS}}',  // additional parenthesis does matter, they convert argument to an int.
      template+: {
        spec+: {
          containers: [
            super.containers[0] {
              resources: {
                requests: {
                  cpu: '${JAEGER_CPU_REQUEST}',
                  memory: '${JAEGER_MEMORY_REQUEST}',
                },
                limits: {
                  cpu: '${JAEGER_CPU_LIMITS}',
                  memory: '${JAEGER_MEMORY_LIMITS}',
                },
              },
              args+: ['--memory.max-traces=${JAEGER_MAX_TRACES}'],
            },
          ],
        },
      },
    },
  } + oauth.deployment,

  serviceMonitor+: {
    metadata+: {
      labels+: {
        prometheus: 'app-sre',
        'app.kubernetes.io/version':: 'hidden',
      },
    },
  },

  serviceMonitorAgent: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'ServiceMonitor',
    metadata+: {
      name: 'observatorium-jaeger-agent',
      namespace: '${NAMESPACE}',
      labels+: {
        prometheus: 'app-sre',
      },
    },
    spec: {
      namespaceSelector: { matchNames: ['${NAMESPACE}'] },
      selector: {
        matchLabels: {
          'app.kubernetes.io/name': 'jaeger-agent',
        },
      },
      endpoints: [
        { port: 'metrics' },
      ],
    },
  },

  // TODO(kakkoyun): Validate if PrometheusRule defintions actually work!
  prometheusRule: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      name: 'observatorium-jaeger',
      labels: {
        prometheus: 'app-sre',
        role: 'alert-rules',
      },
    },
    spec: mixin.prometheusAlerts,
  },
};

{
  apiVersion: 'template.openshift.io/v1',
  kind: 'Template',
  metadata: {
    name: 'jaeger',
  },
  objects: [
    jaeger[name] {
      metadata+: {
        namespace:: 'hidden',
      },
    }
    for name in std.objectFields(jaeger)
  ],
  parameters: [
    { name: 'NAMESPACE', value: 'observatorium' },
    { name: 'IMAGE', value: 'jaegertracing/all-in-one' },
    { name: 'IMAGE_TAG', value: '1.22.0' },
    { name: 'REPLICAS', value: '1' },
    { name: 'JAEGER_MAX_TRACES', value: '100000' },
    { name: 'JAEGER_CPU_REQUEST', value: '1' },
    { name: 'JAEGER_MEMORY_REQUEST', value: '4Gi' },
    { name: 'JAEGER_CPU_LIMITS', value: '4' },
    { name: 'JAEGER_MEMORY_LIMITS', value: '8Gi' },
    { name: 'OAUTH_PROXY_IMAGE', value: 'quay.io/openshift/origin-oauth-proxy' },
    { name: 'OAUTH_PROXY_IMAGE_TAG', value: '4.8.0' },
    { name: 'OAUTH_PROXY_CPU_REQUEST', value: '100m' },
    { name: 'OAUTH_PROXY_MEMORY_REQUEST', value: '100Mi' },
    { name: 'OAUTH_PROXY_CPU_LIMITS', value: '200m' },
    { name: 'OAUTH_PROXY_MEMORY_LIMITS', value: '200Mi' },
    { name: 'SERVICE_ACCOUNT_NAME', value: 'prometheus-telemeter' },
    { name: 'STORAGE_CLASS', value: 'gp2' },
  ],
}
