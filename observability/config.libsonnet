local utils = (import 'github.com/grafana/jsonnet-libs/mixin-utils/utils.libsonnet');
local thanos = (import '../services/observatorium-metrics.libsonnet').thanos;
local var = import 'utils.jsonnet';

{
  thanos: (import 'github.com/thanos-io/thanos/mixin/config.libsonnet') {
    local t = self,

    targetGroups+:: {
      namespace: 'thanos_status',
    },
    // Filter the namespaces in thanos-recieve-controller dashboard
    hierarchies+:: {
      namespace: 'thanos_status',
    },
    overview+:: {
      title: '%(prefix)sOverview' % t.dashboard.prefix,
    },
    query+:: {
      selector: 'job=~"%s.*|%s.*"' % [thanos.query.config.name, thanos.rulerQuery.config.name],
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
      selector: 'job=~"%s.*|%s.*"' % [thanos.rule.config.name, thanos.metricFederationRule.config.name],
    },
    compact+:: {
      selector: 'job="%s"' % thanos.compact.config.name,
    },
    dashboard+:: {
      instance_name_filter: var.instance_name_filter,
    },
  },
  alertmanager: (import 'github.com/prometheus/alertmanager/doc/alertmanager-mixin/config.libsonnet') {
    _config+:: {
      alertmanagerClusterLabels: 'namespace,job',
      alertmanagerNameLabels: 'pod',
    },
  },
  loki: {
    local withDatasource = function(ds) ds + (
      if ds.name == 'datasource' then {
        regex: '${OBSERVATORIUM_DATASOURCE_REGEX}',
        current: {
          selected: true,
          text: '${OBSERVATORIUM_API_DATASOURCE}',
          value: '${OBSERVATORIUM_API_DATASOURCE}',
        },
      } else {}
    ),

    local withNamespace = function(ns) ns + (
      if ns.label == 'namespace' then {
        datasource: {
          type: 'prometheus',
          uid: '${datasource}',
        },
        current: {
          selected: true,
          text: '${OBSERVATORIUM_API_NAMESPACE}',
          value: '${OBSERVATORIUM_API_NAMESPACE}',
        },
        definition: 'label_values(kube_pod_info, namespace)',
        query: {
          query: 'label_values(kube_pod_info, namespace)',
          refId: 'StandardVariableQuery',
        },
        regex: 'observatorium-logs|mst-.+',
      } else {}
    ),

    local withLatencyAxis = function(p) p + (
      if std.length(std.findSubstr('atency', p.title)) != 0 then {
        yaxes: [
          y {
            format: 's',
          }
          for y in p.yaxes
        ],
      } else {}
    ),

    local defaultLokiTags = function(t)
      std.uniq(t + ['observatorium', 'observatorium-logs']),

    local replaceMatchers = function(replacements)
      function(p) p {
        targets: [
          t {
            expr: std.foldl(function(x, rp) std.strReplace(x, rp.from, rp.to), replacements, t.expr),
          }
          for t in p.targets
          if std.objectHas(p, 'targets')
        ],
      },

    // dropPanels removes unnecessary panels from the loki-operational dashboard
    // that are of obsolete usage on our AWS-based deployment environment.
    local dropPanels = function(panels, dropList)
      [
        p
        for p in panels
        if !std.member(dropList, p.title)
      ],

    // mapPanels applies recursively a set of functions over all panels.
    // Note: A Grafana dashboard panel can include other panels.
    // Example: Replace job label in expression and add axis units for all panels.
    local mapPanels = function(funcs, panels)
      [
        // Transform the current panel by applying all transformer funcs.
        // Keep the last version after foldl ends.
        std.foldl(function(agg, fn) fn(agg), funcs, p) + (
          // Recursively apply all transformer functions to any
          // children panels.
          if std.objectHas(p, 'panels') then {
            panels: mapPanels(funcs, p.panels),
          } else {}
        )
        for p in panels
      ],

    // mapTemplateParameters applies a static list of transformer functions to
    // all dashboard template parameters. The static list includes:
    // - RHOBS cluster-prometheus as datasource based on RHOBS environment.
    // - filtered list of namespaces based on selected RHOBS cluster.
    local mapTemplateParameters = function(ls)
      [
        std.foldl(function(x, fn) fn(x), [withDatasource, withNamespace], item)
        for item in ls
        if item.name != 'cluster'
      ],

    prometheusRules+: {
      groups: [
        g {
          rules: [
            r {
              expr: std.strReplace(r.expr, 'cluster, ', ''),
              record: std.strReplace(r.record, 'cluster_', ''),
            }
            for r in g.rules
          ],
        }
        for g in super.groups
      ],
    },
    grafanaDashboards+: {
      // Exclude the following dashboards
      'loki-deletion.json':: super['loki-deletion.json'],
      'loki-mixin-recording-rules.json':: super['loki-mixin-recording-rules.json'],
      'loki-reads-resources.json':: super['loki-reads-resources.json'],
      'loki-writes-resources.json':: super['loki-writes-resources.json'],

      'loki-retention.json'+: {
        local dropList = ['Logs'],
        local replacements = [
          { from: 'cluster=~"$cluster",', to: '' },
          { from: 'container="compactor"', to: 'container="observatorium-loki-compactor"' },
          { from: 'job=~"($namespace)/compactor"', to: 'job="observatorium-loki-compactor"' },
        ],
        uid: 'RetCujSHzC8gd9i5fck9a3v9n2EvTzA',
        tags: defaultLokiTags(super.tags),
        rows: [
          r {
            panels: mapPanels([replaceMatchers(replacements)], r.panels),
          }
          for r in dropPanels(super.rows, dropList)
        ],
        // Adapt dashboard template parameters:
        // - Match default selected datasource to RHOBS cluster.
        // - Match namespaces to RHOBS cluster namespaces
        templating+: {
          list: mapTemplateParameters(super.list),
        },
      },
      'loki-chunks.json'+: {
        uid: 'GtCujSHzC8gd9i5fck9a3v9n2EvTzA',
        tags: defaultLokiTags(super.tags),
        showMultiCluster:: false,
        namespaceQuery:: 'label_values(kube_pod_info, namespace)',
        namespaceType:: 'query',
        labelsSelector:: 'job="observatorium-loki-ingester"',
        // Adapt dashboard template parameters:
        // - Match default selected datasource to RHOBS cluster.
        // - Match namespaces to RHOBS cluster namespaces
        templating+: {
          list: mapTemplateParameters(super.list),
        },
      },
      'loki-operational.json'+: {
        local sjm = super.jobMatchers,

        uid: 'E2CAJBcLcg3NNfd2jLKe4fhQpf2LaU',
        tags: defaultLokiTags(super.tags),
        showAnnotations:: false,
        showLinks:: false,
        showMultiCluster:: false,
        namespaceQuery:: 'label_values(kube_pod_info, namespace)',
        namespaceType:: 'query',
        jobMatchers:: {
          cortexgateway:: sjm.cortexgateway,
          distributor:: [utils.selector.eq('job', 'observatorium-loki-distributor')],
          ingester:: [utils.selector.eq('job', 'observatorium-loki-ingester')],
          querier:: [utils.selector.eq('job', 'observatorium-loki-querier')],
        },
        // Adapt dashboard panels to:
        // - Use RHOBS related job label selectors instead of mixin defaults.
        // - Add seconds as time unit for all latency panels
        // - Drop all rows not relevant for the RHOBS Loki deployment (e.g. GCS, BigTable)
        local dropList = ['Consul', 'Big Table', 'GCS', 'Dynamo', 'Azure Blob', 'Cassandra'],
        local replacements = [
          // TODO: This substitution is needed because the 'replaceClusterMatchers' function in upstream lib 'loki-operational.libsonnet' misses 'cluster=~"$cluster"' substitution.
          // Remove this substitution when it has been added to upstream.
          { from: 'cluster=~"$cluster",', to: '' },
          { from: 'job=~"$namespace/cortex-gw(-internal)?",', to: '' },
          { from: 'kube_pod_container_status_restarts_total{ ', to: 'kube_pod_container_status_restarts_total{container=~"observatorium-loki.+", ' },
          { from: ' * 1e3', to: '' },
          { from: 'pod=~"distributor.*"', to: 'pod=~".*distributor.*"' },
          { from: 'pod=~"ingester.*"', to: 'pod=~".*ingester.*"' },
          { from: 'pod=~"querier.*"', to: 'pod=~".*querier.*"' },
          { from: 'job=~"$namespace/ingester",', to: 'job="observatorium-loki-ingester",' },
        ],
        panels: mapPanels([replaceMatchers(replacements), withLatencyAxis], dropPanels(super.panels, dropList)),
        // Adapt dashboard template parameters:
        // - Match default selected datasource to RHOBS cluster.
        // - Match namespaces to RHOBS cluster namespaces
        templating+: {
          list: mapTemplateParameters(super.list),
        },
      },
      'loki-reads.json'+: {
        local dropList = ['BigTable', 'Ingester - Zone Aware'],

        uid: '62q5jjYwhVSaz4Mcrm8tV3My3gcKED',
        tags: defaultLokiTags(super.tags),
        showMultiCluster:: false,
        namespaceQuery:: 'label_values(kube_pod_info, namespace)',
        namespaceType:: 'query',
        matchers:: {
          cortexgateway:: [],
          queryFrontend:: [utils.selector.eq('job', 'observatorium-loki-query-frontend')],
          querier:: [utils.selector.eq('job', 'observatorium-loki-querier')],
          ingester:: [utils.selector.eq('job', 'observatorium-loki-ingester')],
          ingesterZoneAware:: [],
          querierOrIndexGateway:: [],
        },
        rows: [
          r {
            title: std.strReplace(r.title, 'Frontend (query-frontend)', 'API'),
          }
          for r in dropPanels(super.rows, dropList)
        ],
        // Adapt dashboard template parameters:
        // - Match default selected datasource to RHOBS cluster.
        // - Match namespaces to RHOBS cluster namespaces
        templating+: {
          list: mapTemplateParameters(super.list),
        },
      },
      'loki-writes.json'+: {
        local dropList = ['Ingester - Zone Aware'],

        uid: 'F6nRYKuXmFVpVSFQmXr7cgXy5j7UNr',
        tags: defaultLokiTags(super.tags),
        showMultiCluster:: false,
        namespaceQuery:: 'label_values(kube_pod_info, namespace)',
        namespaceType:: 'query',
        matchers:: {
          cortexgateway:: [],
          distributor:: [utils.selector.eq('job', 'observatorium-loki-distributor')],
          ingester:: [utils.selector.eq('job', 'observatorium-loki-ingester')],
          ingester_zone:: [],
        },
        rows: dropPanels(super.rows, dropList),
        // Adapt dashboard template parameters:
        // - Match default selected datasource to RHOBS cluster.
        // - Match namespaces to RHOBS cluster namespaces
        templating+: {
          list: mapTemplateParameters(super.list),
        },
      },
    },
  },
}
