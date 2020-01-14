local prom = import 'observatorium/environments/openshift/telemeter-prometheus-ams.jsonnet';
local tenants = import 'observatorium/tenants.libsonnet';

local sm =
  (import 'kube-thanos/kube-thanos-servicemonitors.libsonnet') +
  {
    thanos+:: {
      querier+: {
        serviceMonitor+: {
          metadata: {
            name: 'observatorium-thanos-querier',
            labels: { prometheus: 'app-sre' },
          },
          spec+: {
            selector+: {
              matchLabels: { 'app.kubernetes.io/name': 'thanos-querier' },
            },
          },
        },
      },
      store+: {
        serviceMonitor+: {
          metadata: {
            name: 'observatorium-thanos-store',
            labels: { prometheus: 'app-sre' },
          },
          spec+: {
            selector+: {
              matchLabels: { 'app.kubernetes.io/name': 'thanos-store' },
            },
          },
        },
      },
      compactor+: {
        serviceMonitor+: {
          metadata: {
            name: 'observatorium-thanos-compactor',
            labels: { prometheus: 'app-sre' },
          },
          spec+: {
            selector+: {
              matchLabels: { 'app.kubernetes.io/name': 'thanos-compactor' },
            },
          },
        },
      },
      thanosReceiveController+: {
        serviceMonitor+: {
          apiVersion: 'monitoring.coreos.com/v1',
          kind: 'ServiceMonitor',
          metadata: {
            name: 'observatorium-thanos-receive-controller',
            labels: { prometheus: 'app-sre' },
          },
          spec+: {
            selector+: {
              matchLabels: { 'app.kubernetes.io/name': 'thanos-receive-controller' },
            },
            endpoints: [
              { port: 'http' },
            ],
          },
        },
      },
      receive+: {
        ['serviceMonitor' + tenant.hashring]:
          super.serviceMonitor +
          {
            metadata: {
              name: 'observatorium-thanos-receive-' + tenant.hashring,
              labels: { prometheus: 'app-sre' },
            },
            spec+: {
              selector+: {
                matchLabels: {
                  'app.kubernetes.io/name': 'thanos-receive',
                  'app.kubernetes.io/instance': tenant.hashring,
                },
              },
            },
          }
        for tenant in tenants
      },
    },
  };

{
  'observatorium-thanos-querier.servicemonitor': sm.thanos.querier.serviceMonitor {
    metadata+: { name+: '-{{environment}}' },
    spec+: { namespaceSelector+: { matchNames: ['{{namespace}}'] } },
  },
  'observatorium-thanos-store.servicemonitor': sm.thanos.store.serviceMonitor {
    metadata+: { name+: '-{{environment}}' },
    spec+: { namespaceSelector+: { matchNames: ['{{namespace}}'] } },
  },
  'observatorium-thanos-compactor.servicemonitor': sm.thanos.compactor.serviceMonitor {
    metadata+: { name+: '-{{environment}}' },
    spec+: { namespaceSelector+: { matchNames: ['{{namespace}}'] } },
  },
  'observatorium-thanos-receive-controller.servicemonitor': sm.thanos.thanosReceiveController.serviceMonitor {
    metadata+: { name+: '-{{environment}}' },
    spec+: { namespaceSelector+: { matchNames: ['{{namespace}}'] } },
  },
  'observatorium-prometheus-ams.servicemonitor': prom.prometheusAms.serviceMonitor {
    metadata: {
      name: prom.prometheusAms.serviceMonitor.metadata.name + '-{{environment}}',
      labels: { prometheus: 'app-sre' },
    },
    spec+: { namespaceSelector+: { matchNames: ['{{namespace}}'] } },
  },
} {
  ['observatorium-thanos-receive-%s.servicemonitor' % tenant.hashring]: sm.thanos.receive['serviceMonitor' + tenant.hashring] {
    metadata+: { name+: '-{{environment}}' },
    spec+: { namespaceSelector+: { matchNames: ['{{namespace}}'] } },
  }
  for tenant in tenants
}
