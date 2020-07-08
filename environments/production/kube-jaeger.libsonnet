local jaeger = (import 'jaeger-mixin/mixin.libsonnet');

(import 'github.com/observatorium/deployments/components/jaeger-collector.libsonnet') + {
  jaeger+:: {

    local j = self,

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
      spec: jaeger.prometheusAlerts,
    },
    serviceMonitor: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata+: {
        name: 'observatorium-jaeger-collector',
        namespace: j.namespace,
        labels+: {
          prometheus: 'app-sre',
        },
      },
      spec: {
        namespaceSelector: {
          matchNames: j.namespace,
        },
        selector: {
          matchLabels: {
            'app.kubernetes.io/name': 'jaeger-all-in-one',
          },
        },
        endpoints: [
          { port: 'admin-http' },
        ],
      },
    },

    serviceMonitorAgent: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'ServiceMonitor',
      metadata+: {
        name: 'observatorium-jaeger-agent',
        namespace: j.namespace,
        labels+: {
          prometheus: 'app-sre',
        },
      },
      spec: {
        namespaceSelector: {
          matchNames: j.namespace,
        },
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

  },
}
