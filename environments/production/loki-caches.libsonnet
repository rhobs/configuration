local memcached = (import 'github.com/observatorium/deployments/components/memcached.libsonnet');

{
  local lc = self,

  config:: {
    name:: error 'must provide name',
    namespace:: error 'must provide namespace',
    version:: error 'must provide version',
    image:: error 'must provide image',
    exporterVersion:: error 'must provide exporter version',
    exporterImage:: error 'must provide exporter image',
    replicas:: error 'must provide replicas',

    enableChuckCache: false,
    enableIndexQueryCache: false,
    enableResultsCache: false,

    commonLabels:: {
      'app.kubernetes.io/name': 'loki',
      'app.kubernetes.io/instance': lc.config.name,
      'app.kubernetes.io/version': lc.config.version,
    },
  },

  serviceMonitors: {},

  chunkCache:: memcached({
    name: lc.config.name + '-' + lc.config.commonLabels['app.kubernetes.io/name'] + '-chunk-cache',
    namespace: lc.config.namespace,
    commonLabels+:: lc.config.commonLabels {
      'app.kubernetes.io/component': 'chunk-cache',
    },
    version:: lc.config.version,
    image:: lc.config.image,
    exporterVersion: lc.config.exporterVersion,
    exporterImage:: lc.config.exporterImage,
    replicas: lc.config.replicas.chunk_cache,
    maxItemSize:: '2m',
    memoryLimitMb: 4096,
    serviceMonitor: true,
  }) + if std.objectHas(lc.serviceMonitors, 'chunk_cache') then {
    serviceMonitor+: lc.serviceMonitors.chunk_cache,
  } else {},

  indexQueryCache:: memcached({
    name: lc.config.name + '-' + lc.config.commonLabels['app.kubernetes.io/name'] + '-index-query-cache',
    namespace: lc.config.namespace,
    commonLabels+:: lc.config.commonLabels {
      'app.kubernetes.io/component': 'index-query-cache',
    },
    version:: lc.config.version,
    image:: lc.config.image,
    exporterVersion: lc.config.exporterVersion,
    exporterImage:: lc.config.exporterImage,
    replicas: lc.config.replicas.index_query_cache,
    maxItemSize:: '5m',
    serviceMonitor: true,
  }) + if std.objectHas(lc.serviceMonitors, 'index_query_cache') then {
    serviceMonitor+: lc.serviceMonitors.index_query_cache,
  } else {},

  resultsCache:: memcached({
    name: lc.config.name + '-' + lc.config.commonLabels['app.kubernetes.io/name'] + '-results-cache',
    namespace: lc.config.namespace,
    commonLabels+:: lc.config.commonLabels {
      'app.kubernetes.io/component': 'results-cache',
    },
    version:: lc.config.version,
    image:: lc.config.image,
    exporterVersion: lc.config.exporterVersion,
    exporterImage:: lc.config.exporterImage,
    replicas: lc.config.replicas.results_cache,
    serviceMonitor: true,
  }) + if std.objectHas(lc.serviceMonitors, 'results_cache') then {
    serviceMonitor+: lc.serviceMonitors.results_cache,
  } else {},

  withServiceMonitors: {
    local l = self,
    serviceMonitors:: {},

    manifests+:: {
      'chunk-cache-service-monitor': l.chunkCache.serviceMonitor,
      'index-query-cache-service-monitor': l.indexQueryCache.serviceMonitor,
      'results-cache-service-monitor': l.resultsCache.serviceMonitor,
    },
  },

  manifests::
    {} +
    (if lc.config.enableChuckCache then {
       'chunk-cache-service': lc.chunkCache.service,
       'chunk-cache-statefulset': lc.chunkCache.statefulSet,
     } else {}) +
    (if lc.config.enableIndexQueryCache then {
       'index-query-cache-service': lc.indexQueryCache.service,
       'index-query-cache-statefulset': lc.indexQueryCache.statefulSet,
     } else {}) +
    (if lc.config.enableResultsCache then {
       'results-cache-service': lc.resultsCache.service,
       'results-cache-statefulset': lc.resultsCache.statefulSet,
     } else {}),
}
