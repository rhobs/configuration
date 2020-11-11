local defaults = {
  local defaults = self,
  image: error 'must provide image',
  collectorAddress: 'localhost:16879',
  ports: {
    'jaeger-thrift': 6831,
    configs: 5778,
    metrics: 14271,
  },
  resources: {
    requests: { cpu: '32m', memory: '64Mi' },
    limits: { cpu: '128m', memory: '128Mi' },
  },
};

function(params) {
  local ja = self,
  config:: defaults + params,

  local spec = {
    template+: {
      metadata+: {
        labels+: {
          'app.kubernetes.io/tracing': 'jaeger-agent',
        },
      },
      spec+: {
        containers+: [{
          name: 'jaeger-agent',
          image: ja.config.image,
          args: [
            '--reporter.grpc.host-port=' + ja.config.collectorAddress,
            '--reporter.type=grpc',
            '--jaeger.tags=pod.namespace=$(NAMESPACE),pod.name=$(POD)',
          ],
          env: [
            { name: 'NAMESPACE', valueFrom: { fieldRef: { fieldPath: 'metadata.namespace' } } },
            { name: 'POD', valueFrom: { fieldRef: { fieldPath: 'metadata.name' } } },
          ],
          ports: [
            { name: name, containerPort: ja.config.ports[name] }
            for name in std.objectFields(ja.config.ports)
          ],
          livenessProbe: {
            failureThreshold: 5,
            httpGet: {
              path: '/',
              scheme: 'HTTP',
              port: ja.config.ports.metrics,
            },
          },
          resources: ja.config.resources,
        }],
      },
    },
  },

  statefulSet+: {
    spec+: spec,
  },

  deployment+: {
    spec+: spec,
  },
}
