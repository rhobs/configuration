// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  local defaults = self,
  name: 'remote-write-proxy',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must set image for proxy',
  target: error 'must provide target',
  targetNamespace: error 'must provide target namespace',
  tenantID: error 'must provide tenant ID',
  ports: {
    proxy: 8080,
    target: 19291,
  },

  // TODO(kakkoyun): Not in sync with other components. Find out why and fix it.
  commonLabels:: {
    'app.kubernetes.io/part-of': defaults.name,
    'app.kubernetes.io/name': 'nginx',
    'app.kubernetes.io/instance': 'remote-write-proxy',
    'app.kubernetes.io/component': 'prometheus-ams',
    // 'app.kubernetes.io/version': defaults.version,
  },

  selectorLabels:: {
    'app.kubernetes.io/name': 'nginx',
    'app.kubernetes.io/instance': 'remote-write-proxy',
  },
};

function(params) {
  local rwp = self,

  config+:: defaults + params,

  proxyService: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'prometheus-%s-remote-write-proxy' % 'ams',
      namespace: rwp.config.namespace,
      labels: rwp.config.commonLabels,
    },
    spec: {
      ports: [
        { name: 'http', targetPort: 'http', port: 8080 },
      ],
      selector: rwp.config.selectorLabels,
    },
  },

  deployment:
    local c = {
      name: 'remote-write-proxy',
      image: rwp.config.image,
      command: ['nginx'],
      args: [
        '-c',
        '/config/nginx.conf',
      ],
      ports: [{ name: 'http', containerPort: rwp.config.ports.proxy }],
      volumeMounts: [
        { name: rwp.configmap.metadata.name, mountPath: '/config', readOnly: true },
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
        namespace: rwp.config.namespace,
        labels: rwp.config.commonLabels,
      },
      spec: {
        replicas: 1,
        selector: { matchLabels: rwp.config.selectorLabels },
        template: {
          metadata: {
            labels: rwp.config.commonLabels,
          },
          spec: {
            containers: [c],
            volumes: [
              { name: rwp.configmap.metadata.name, configMap: { name: rwp.configmap.metadata.name } },
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
      namespace: rwp.config.namespace,
      labels: rwp.config.commonLabels,
    },
    data: {
      local f = importstr 'remote_write_proxy.conf',

      'nginx.conf': std.format(f, {
        listen_port: rwp.config.ports.proxy,
        forward_host: 'http://%s.%s.svc.cluster.local:%d' % [
          rwp.config.target,
          rwp.config.targetNamespace,
          rwp.config.ports.target,
        ],
        thanos_tenant: rwp.config.tenantID,
      }),
    },
  },
}
