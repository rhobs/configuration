local utils = (import 'github.com/grafana/jsonnet-libs/mixin-utils/utils.libsonnet');
local thanos = (import '../services/observatorium.libsonnet').thanos;

{
  thanos: (import 'github.com/thanos-io/thanos/mixin/config.libsonnet') {
    local t = self,

    targetGroups+:: {
      namespace: 'thanos_status',
    },
    overview+:: {
      title: '%(prefix)sOverview' % t.dashboard.prefix,
    },
    query+:: {
      selector: 'job="%s"' % thanos.query.config.name,
    },
    store+:: {
      selector: 'job=~"%s.*"' % thanos.stores.config.name,
    },
    receive+:: {
      local hashrings = ['%s.*' % thanos.receivers[hashring].config.name for hashring in std.objectFields(thanos.receivers)],
      selector: 'job=~"%s"' % std.join('|', hashrings),
    },
    receiveController+:: {
      selector: 'job="%s"' % thanos.receiveController.config.name,
      receiveSelector: t.receive.selector,
    },
    rule+:: {
      selector: 'job=~"%s.*"' % thanos.rule.config.name,
    },
    compact+:: {
      selector: 'job="%s"' % thanos.compact.config.name,
    },
  },

  loki: {
    grafanaDashboards+: {
      'loki-chunks.json'+: {
        showMultiCluster:: false,
        namespaceQuery:: '${OBSERVATORIUM_LOGS_NAMESPACE}',
        namespaceType:: 'custom',
        matchers:: {
          ingester:: [utils.selector.eq('job', 'observatorium-loki-ingester-http')],
        },
      },
      'loki-logs.json'+: {
        showMultiCluster:: false,
      },
      'loki-operational.json'+: {
        showAnnotations:: false,
        showLinks:: false,
        showMultiCluster:: false,
        namespaceQuery:: '${OBSERVATORIUM_LOGS_NAMESPACE}',
        namespaceType:: 'custom',
        matchers:: {
          cortexgateway:: [],
          distributor:: [utils.selector.eq('job', 'observatorium-loki-distributor-http')],
          ingester:: [utils.selector.eq('job', 'observatorium-loki-ingester-http')],
          querier:: [utils.selector.eq('job', 'observatorium-loki-querier-http')],
        },
      },
      'loki-reads.json'+: {
        showMultiCluster:: false,
        namespaceQuery:: '${OBSERVATORIUM_LOGS_NAMESPACE}',
        namespaceType:: 'custom',
        matchers:: {
          cortexgateway:: [],
          queryFrontend:: [utils.selector.eq('job', 'observatorium-loki-query-frontend-http')],
          querier:: [utils.selector.eq('job', 'observatorium-loki-querier-http')],
          ingester:: [utils.selector.eq('job', 'observatorium-loki-ingester-http')],
        },
      },
      'loki-writes.json'+: {
        showMultiCluster:: false,
        namespaceQuery:: '${OBSERVATORIUM_LOGS_NAMESPACE}',
        namespaceType:: 'custom',
        matchers:: {
          cortexgateway:: [],
          distributor:: [utils.selector.eq('job', 'observatorium-loki-distributor-http')],
          ingester:: [utils.selector.eq('job', 'observatorium-loki-ingester-http')],
        },
      },
    },
  },
}
