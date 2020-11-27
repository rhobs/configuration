local list = import 'github.com/openshift/telemeter/jsonnet/telemeter/lib/list.libsonnet';

// These are the defaults for this components configuration.
local prometheusAms = {
  local pa = self,

  config+:: {
    namespace:: '${NAMESPACE}',

    receiveTenantId: 'FB870BF3-9F3A-44FF-9BF7-D7A047A52F43',
    ports: {
      proxy: 8080,
      target: 19291,
    },

    commonLabels:: {
      'app.kubernetes.io/part-of': 'observatorium',
      'app.kubernetes.io/name': 'nginx',
      'app.kubernetes.io/instance': 'remote-write-proxy',
      'app.kubernetes.io/component': 'prometheus-ams',
    },
    selectorLabels:: {
      'app.kubernetes.io/name': 'nginx',
      'app.kubernetes.io/instance': 'remote-write-proxy',
    },
  },

  proxyService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'prometheus-%s-remote-write-proxy' % 'ams',
      namespace: pa.config.namespace,
      labels: pa.config.commonLabels,
    },
    spec: {
      ports: [
        { name: 'http', targetPort: 'http', port: 8080 },
      ],
      selector: pa.config.selectorLabels,
    },
  },

  deployment:
    local c = {
      name: 'remote-write-proxy',
      image: '${PROMETHEUS_AMS_REMOTE_WRITE_PROXY_IMAGE}:${PROMETHEUS_AMS_REMOTE_WRITE_PROXY_VERSION}',
      command: 'nginx',
      args: [
        '-c',
        '/config/nginx.conf',
      ],

      ports: [{ name: 'http', containerPort: pa.config.ports.proxy }],
      volumeMounts: [
        { name: pa.configmap.metadata.name, mountPath: '/config', readOnly: true },
      ],
      resources: {
        requests: { cpu: '50m', memory: '16Mi' },
        limits: { cpu: '100m', memory: '64Mi' },
      },
    };

    {
      apiVersion: 'apps/v1',
      kind: 'Deployment',
      metadata: {
        name: 'prometheus-remote-write-proxy',
        namespace: pa.config.namespace,
        labels: pa.config.commonLabels,
      },
      spec: {
        replicas: '{{REPLICAS}}',
        selector: { matchLabels: pa.config.selectorLabels },
        template: {
          metadata: {
            labels: pa.config.commonLabels,
          },
          spec: {
            containers: [c],
            volumes: [
              { name: pa.configmap.metadata.name, configMap: { name: pa.configmap.metadata.name } },
            ],
          },
        },
      },
    },

  configmap: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'prometheus-remote-write-proxy-config',
      namespace: pa.config.namespace,
      labels: pa.config.commonLabels,
    },
    data: {
      local f = importstr './prometheus/remote_write_proxy.conf',

      'nginx.conf': std.format(f, {
        listen_port: pa.config.ports.proxy,
        forward_host: 'http://%s.%s.svc.cluster.local:%d' % [
          '${PROMETHEUS_AMS_REMOTE_WRITE_PROXY_TARGET}',
          '${NAMESPACE}',
          pa.config.ports.target,
        ],
        thanos_tenant: pa.config.receiveTenantId,
      }),
    },
  },
};

{
  apiVersion: 'v1',
  kind: 'Template',
  metadata: {
    name: 'observatorium-prometheus',
  },
  objects: [
    prometheusAms[name] {
      metadata+: { namespace:: 'hidden' },
    }
    for name in std.objectFields(prometheusAms)
  ],
  parameters: [
    { name: 'NAMESPACE', value: 'observatorium' },
    { name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_IMAGE', value: 'quay.io/app-sre/observatorium-receive-proxy' },
    { name: 'PROMETHEUS_AMS_REMOTE_WRITE_PROXY_VERSION', value: '14e844d' },
    { name: 'PROMETHEUS_IMAGE', value: 'quay.io/prometheus/prometheus' },
    { name: 'PROMETHEUS_VERSION', value: 'v2.12.0' },
    { name: 'REPLICAS', value: '1' },
  ],
}
