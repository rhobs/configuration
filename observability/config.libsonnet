local utils = (import 'github.com/grafana/jsonnet-libs/mixin-utils/utils.libsonnet');
local thanos = (import '../services/observatorium-metrics.libsonnet').thanos;

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
      local hashrings = ['%s.*' % thanos.receivers.hashrings[hashring].config.name for hashring in std.objectFields(thanos.receivers.hashrings)],
      selector: 'job=~"%s"' % std.join('|', hashrings),
    },
    receiveController+:: {
      selector: 'job="%s"' % thanos.receiveController.config.name,
      receiveSelector: t.receive.selector,
    },
    rule+:: {
      selector: 'job=~"%s.*|%s.*|%s.*|%s.*"' % [thanos.rule.config.name, thanos.statelessRule.config.name, thanos.metricFederationRule.config.name, thanos.metricFederationStatelessRule.config.name],
    },
    compact+:: {
      selector: 'job="%s"' % thanos.compact.config.name,
    },
  },

  local withLokiMetricsDatasource = function(ds, key) ds + (
    if ds.name == key then {
      regex: '${OBSERVATORIUM_DATASOURCE_REGEX}',
      current: {
        selected: true,
        text: '${OBSERVATORIUM_API_DATASOURCE}',
        value: '${OBSERVATORIUM_API_DATASOURCE}',
      },
    } else {}
  ),

  local withLokiMetricsNamespace = function(ns, value) ns + (
    if ns.label == value then {
      query: '${OBSERVATORIUM_NAMESPACE_OPTIONS}',
      current: {
        selected: true,
        text: '${OBSERVATORIUM_API_NAMESPACE}',
        value: '${OBSERVATORIUM_API_NAMESPACE}',
      },
    } else {}
  ),

  local defaultLokiTags = function(t)
    std.uniq(t + ['observatorium', 'observatorium-logs']),

  loki: {
    grafanaDashboards+: {
      'loki-chunks.json'+: {
        uid: 'GtCujSHzC8gd9i5fck9a3v9n2EvTzA',
        tags: defaultLokiTags(super.tags),
        showMultiCluster:: false,
        namespaceQuery:: '${OBSERVATORIUM_API_NAMESPACE}',
        namespaceType:: 'custom',
        matchers:: {
          ingester:: [utils.selector.eq('job', 'observatorium-loki-ingester-http')],
        },
        rows: [
          r {
            panels: [
              p {
                targets: [
                  t {
                    // TODO(@periklis): Remove all the string replaces once we update the dahboards mixin dependencies.
                    //                  This is currently needed because we use Loki 2.7.x and on out-of-date mixin
                    //                  for dashboards from 2020.
                    expr: std.strReplace(t.expr, 'cortex_chunk', 'loki_chunk'),
                  }
                  for t in p.targets
                ],
              }
              for p in r.panels
            ],
          }
          for r in super.rows
        ],
        templating+: {
          list:
            std.map(
              function(e) withLokiMetricsDatasource(e, 'datasource'),
              std.map(
                function(e) withLokiMetricsNamespace(e, 'namespace'),
                super.list
              )
            ),
        },
      },
      'loki-operational.json'+: {
        uid: 'E2CAJBcLcg3NNfd2jLKe4fhQpf2LaU',
        tags: defaultLokiTags(super.tags),
        showAnnotations:: false,
        showLinks:: false,
        showMultiCluster:: false,
        namespaceQuery:: '${OBSERVATORIUM_API_NAMESPACE}',
        namespaceType:: 'custom',
        matchers:: {
          cortexgateway:: [],
          distributor:: [utils.selector.eq('job', 'observatorium-loki-distributor-http')],
          ingester:: [utils.selector.eq('job', 'observatorium-loki-ingester-http')],
          querier:: [utils.selector.eq('job', 'observatorium-loki-querier-http')],
        },
        panels: [
          p {
            panels: [
              ip {
                targets: [
                  t {
                    // TODO(@periklis): Remove all the string replaces once we update the dahboards mixin dependencies.
                    //                  This is currently needed because we use Loki 2.7.x and on out-of-date mixin
                    //                  for dashboards from 2020.
                    expr:
                      std.strReplace(
                        std.strReplace(
                          std.strReplace(
                            std.strReplace(
                              std.strReplace(t.expr, 'cortex_', 'loki_'),
                              'pod=~"distributor.*"',
                              'pod=~".*distributor.*"',
                            ),
                            'pod=~"ingester.*"',
                            'pod=~".*ingester.*"',
                          ),
                          'pod=~"querier.*"',
                          'pod=~".*querier.*"',
                        ),
                        'node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate',
                        'node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate',
                      ),
                  }
                  for t in ip.targets
                ],
              }
              for ip in p.panels
            ],
            targets: [
              t {
                // TODO(@periklis): Remove all the string replaces once we update the dahboards mixin dependencies.
                //                  This is currently needed because we use Loki 2.7.x and on out-of-date mixin
                //                  for dashboards from 2020.
                expr:
                  std.strReplace(
                    t.expr,
                    'kube_pod_container_status_restarts_total{ ',
                    'kube_pod_container_status_restarts_total{container=~"observatorium-loki.+", ',
                  ),
              }
              for t in p.targets
            ],
          }
          for p in super.panels
          if !std.member(['Consul', 'Big Table', 'GCS', 'Dynamo', 'Cassandra'], p.title)
        ],
        templating+: {
          list:
            std.map(
              function(e) withLokiMetricsDatasource(e, 'metrics'),
              std.map(
                function(e) withLokiMetricsNamespace(e, 'namespace'),
                super.list
              )
            ),
        },
      },
      'loki-reads.json'+: {
        uid: '62q5jjYwhVSaz4Mcrm8tV3My3gcKED',
        tags: defaultLokiTags(super.tags),
        showMultiCluster:: false,
        namespaceQuery:: '${OBSERVATORIUM_API_NAMESPACE}',
        namespaceType:: 'custom',
        matchers:: {
          cortexgateway:: [],
          queryFrontend:: [utils.selector.eq('job', 'observatorium-loki-query-frontend-http')],
          querier:: [utils.selector.eq('job', 'observatorium-loki-querier-http')],
          ingester:: [utils.selector.eq('job', 'observatorium-loki-ingester-http')],
        },
        rows: [
          r {
            title: std.strReplace(r.title, 'Frontend (cortex_gw)', 'API'),
          }
          for r in super.rows
          if r.title != 'BigTable'
        ],
        templating+: {
          list:
            std.map(
              function(e) withLokiMetricsDatasource(e, 'datasource'),
              std.map(
                function(e) withLokiMetricsNamespace(e, 'namespace'),
                super.list
              )
            ),
        },
      },
      'loki-writes.json'+: {
        uid: 'F6nRYKuXmFVpVSFQmXr7cgXy5j7UNr',
        tags: defaultLokiTags(super.tags),
        showMultiCluster:: false,
        namespaceQuery:: '${OBSERVATORIUM_API_NAMESPACE}',
        namespaceType:: 'custom',
        matchers:: {
          cortexgateway:: [],
          distributor:: [utils.selector.eq('job', 'observatorium-loki-distributor-http')],
          ingester:: [utils.selector.eq('job', 'observatorium-loki-ingester-http')],
        },
        rows: [
          r {
            title: std.strReplace(r.title, 'Frontend (cortex_gw)', 'API'),
          }
          for r in super.rows
          if r.title != 'BigTable'
        ],
        templating+: {
          list:
            std.map(
              function(e) withLokiMetricsDatasource(e, 'datasource'),
              std.map(
                function(e) withLokiMetricsNamespace(e, 'namespace'),
                super.list
              )
            ),
        },
      },
    },
  },
}
