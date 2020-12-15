local utils = (import 'github.com/grafana/jsonnet-libs/mixin-utils/utils.libsonnet');
local thanos = (import '../services/observatorium.libsonnet').thanos;

{
  thanos: {
    local t = self,
    _config+:: {
      local cfg = self,
      // TODO: Move this to the new style of selectors that kube-thanos uses
      thanosReceiveSelector: t.receive.selector,
      thanosReceiveControllerJobPrefix: thanos.receiveController.service.metadata.name,
      thanosReceiveControllerSelector: 'job="%s"' % cfg.thanosReceiveControllerJobPrefix,
    },

    dashboard+:: {
      tags: ['thanos-mixin'],
      namespaceQuery: 'kube_pod_info',
    },
    overview+:: {
      title: '%(prefix)sOverview' % t.dashboard.prefix,
    },
    compact+:: {
      local compact = self,
      jobPrefix: thanos.compact.service.metadata.name,
      selector: 'job="%s"' % compact.jobPrefix,
      title: '%(prefix)sCompact' % t.dashboard.prefix,
    },
    query+:: {
      local query = self,
      jobPrefix: thanos.query.service.metadata.name,
      selector: 'job="%s"' % query.jobPrefix,
      title: '%(prefix)sQuery' % t.dashboard.prefix,
    },
    receive+:: {
      local receive = self,
      jobPrefix: thanos.receivers.default.service.metadata.name,
      selector: 'job=~"%s.*"' % receive.jobPrefix,
      title: '%(prefix)sReceive' % t.dashboard.prefix,
    },
    store+:: {
      local store = self,
      jobPrefix: 'observatorium-thanos-store',
      selector: 'job=~"%s.*"' % store.jobPrefix,
      title: '%(prefix)sStore' % t.dashboard.prefix,
    },
    rule+:: {
      local rule = self,
      jobPrefix: thanos.rule.service.metadata.name,
      selector: 'job="%s"' % rule.jobPrefix,
      title: '%(prefix)sRule' % t.dashboard.prefix,
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
