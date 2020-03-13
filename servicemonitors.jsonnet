local prom = import 'configuration/environments/openshift/telemeter-prometheus-ams.jsonnet';
local t =
  (import 'kube-thanos/thanos.libsonnet') +
  (import 'selectors.libsonnet');

local trc =
  (import 'thanos-receive-controller/thanos-receive-controller.libsonnet') +
  (import 'selectors.libsonnet');

local obs = (import 'configuration/environments/openshift/obs.jsonnet') {
  compact+::
    t.compact.withServiceMonitor {
      serviceMonitor+: {
        metadata+: {
          name: 'observatorium-thanos-compactor',
          namespace: null,
          labels+: {
            prometheus: 'app-sre',
            'app.kubernetes.io/version':: 'hidden',
          },
        },
      },
    },

  thanosReceiveController+::
    trc.withServiceMonitor {
      serviceMonitor+: {
        metadata+: {
          name: 'observatorium-thanos-receive-controller',
          namespace: null,
          labels+: {
            prometheus: 'app-sre',
            'app.kubernetes.io/version':: 'hidden',
          },
        },

        // TODO: Remove once fixed upstream
        spec+: {
          selector+: {
            matchLabels+: {
              'app.kubernetes.io/version':: 'hidden',
            },
          },
        },
      },
    },

  store+:: {
    ['shard' + i]+: t.store.withServiceMonitor {
      serviceMonitor+: {
        metadata+: {
          name: 'observatorium-thanos-store-shard-' + i,
          namespace: null,
          labels+: {
            prometheus: 'app-sre',
            'app.kubernetes.io/version':: 'hidden',
          },
        },
      },
    }
    for i in std.range(0, obs.config.store.shards - 1)
  },

  receivers+:: {
    [hashring.hashring]+: t.receive.withServiceMonitor {
      serviceMonitor+: {
        metadata+: {
          name: 'observatorium-thanos-receive-' + hashring.hashring,
          namespace: null,
          labels+: {
            prometheus: 'app-sre',
            'app.kubernetes.io/version':: 'hidden',
          },
        },
      },
    }
    for hashring in obs.config.hashrings
  },

  query+::
    t.query.withServiceMonitor {
      serviceMonitor+: {
        metadata+: {
          name: 'observatorium-thanos-querier',
          namespace: null,
          labels+: {
            prometheus: 'app-sre',
            'app.kubernetes.io/version':: 'hidden',
          },
        },
      },
    },

  rule+::
    t.rule.withServiceMonitor {
      serviceMonitor+: {
        metadata+: {
          name: 'observatorium-thanos-rule',
          namespace: null,
          labels+: {
            prometheus: 'app-sre',
            'app.kubernetes.io/version':: 'hidden',
          },
        },
      },
    },
};

{
  'observatorium-thanos-query.servicemonitor': obs.query.serviceMonitor {
    metadata+: { name+: '-{{environment}}' },
    spec+: { namespaceSelector+: { matchNames: ['{{namespace}}'] } },
  },
  'observatorium-thanos-compact.servicemonitor': obs.compact.serviceMonitor {
    metadata+: { name+: '-{{environment}}' },
    spec+: { namespaceSelector+: { matchNames: ['{{namespace}}'] } },
  },
  'observatorium-thanos-rule.servicemonitor': obs.rule.serviceMonitor {
    metadata+: { name+: '-{{environment}}' },
    spec+: { namespaceSelector+: { matchNames: ['{{namespace}}'] } },
  },
  'observatorium-thanos-receive-controller.servicemonitor': obs.thanosReceiveController.serviceMonitor {
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
  ['observatorium-thanos-receive-%s.servicemonitor' % hashring.hashring]: obs.receivers[hashring.hashring].serviceMonitor {
    metadata+: { name+: '-{{environment}}' },
    spec+: { namespaceSelector+: { matchNames: ['{{namespace}}'] } },
  }
  for hashring in obs.config.hashrings
} {
  ['observatorium-thanos-store-shard-%d.servicemonitor' % i]: obs.store['shard' + i].serviceMonitor {
    metadata+: { name+: '-{{environment}}' },
    spec+: { namespaceSelector+: { matchNames: ['{{namespace}}'] } },
  }
  for i in std.range(0, obs.config.store.shards - 1)
}
