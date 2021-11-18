local memcached = (import 'github.com/observatorium/observatorium/configuration/components/memcached.libsonnet');

// These are the defaults for this components configuration.
// When calling the function to generate the component's manifest,
// you can pass an object structured like the default to overwrite default values.
local defaults = {
  local defaults = self,
  name: error 'must provide name',
  namespace: error 'must provide namespace',
  version: error 'must provide version',
  image: error 'must provide image',
  exporterVersion: error 'must provide exporter version',
  exporterImage: error 'must provide exporter image',

  components: {
    chunkCache: {
      replicas: 1,
      withServiceMonitor: false,
      resources: {
        requests: {
          cpu: '500m',
          memory: '5016Mi',
        },
        limits: {
          cpu: '3',
          memory: '6Gi',
        },
      },
    },
    indexQueryCache: {
      replicas: 1,
      withServiceMonitor: false,
      resources: {
        requests: {
          cpu: '500m',
          memory: '1329Mi',
        },
        limits: {
          cpu: '3',
          memory: '1536Mi',
        },
      },
    },
    resultsCache: {
      replicas: 1,
      withServiceMonitor: false,
      resources: {
        requests: {
          cpu: '500m',
          memory: '1329Mi',
        },
        limits: {
          cpu: '3',
          memory: '1536Mi',
        },
      },
    },
  },

  commonLabels:: {
    'app.kubernetes.io/name': 'loki',
    'app.kubernetes.io/instance': defaults.name,
    'app.kubernetes.io/version': defaults.version,
  },

  podLabelSelector:: {
    [labelName]: defaults.commonLabels[labelName]
    for labelName in std.objectFields(defaults.commonLabels)
    if labelName != 'app.kubernetes.io/version'
  },
};

function(params) {
  local lc = self,

  // Combine the defaults and the passed params to make the component's config.
  config:: defaults + params,
  // Safety checks for combined config of defaults and params.
  assert std.isObject(lc.config.components),

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
    replicas: lc.config.components.chunkCache.replicas,
    serviceMonitor: lc.config.components.chunkCache.withServiceMonitor,
    maxItemSize:: '2m',
    memoryLimitMb: 4096,
    resources: {
      memcached: {
        requests: {
          cpu: lc.config.components.chunkCache.resources.requests.cpu,
          memory: lc.config.components.chunkCache.resources.requests.memory,
        },
        limits: {
          cpu: lc.config.components.chunkCache.resources.limits.cpu,
          memory: lc.config.components.chunkCache.resources.limits.memory,
        },
      },
    },
  }) {
    serviceAccount+: {
      imagePullSecrets+: [{ name: 'quay.io' }],
    },
  },

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
    replicas: lc.config.components.indexQueryCache.replicas,
    serviceMonitor: lc.config.components.indexQueryCache.withServiceMonitor,
    maxItemSize:: '5m',
    resources: {
      memcached: {
        requests: {
          cpu: lc.config.components.indexQueryCache.resources.requests.cpu,
          memory: lc.config.components.indexQueryCache.resources.requests.memory,
        },
        limits: {
          cpu: lc.config.components.indexQueryCache.resources.limits.cpu,
          memory: lc.config.components.indexQueryCache.resources.limits.memory,
        },
      },
    },
  }) {
    serviceAccount+: {
      imagePullSecrets+: [{ name: 'quay.io' }],
    },
  },

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
    replicas: lc.config.components.resultsCache.replicas,
    serviceMonitor: lc.config.components.resultsCache.withServiceMonitor,
    resources: {
      memcached: {
        requests: {
          cpu: lc.config.components.resultsCache.resources.requests.cpu,
          memory: lc.config.components.resultsCache.resources.requests.memory,
        },
        limits: {
          cpu: lc.config.components.resultsCache.resources.limits.cpu,
          memory: lc.config.components.resultsCache.resources.limits.memory,
        },
      },
    },

  }) {
    serviceAccount+: {
      imagePullSecrets+: [{ name: 'quay.io' }],
    },
  },

  manifests::
    {} +
    (if std.objectHas(lc.config.components, 'chunkCache') && lc.config.components.chunkCache.replicas > 0 then {
       'chunk-cache-service': lc.chunkCache.service,
       'chunk-cache-statefulset': lc.chunkCache.statefulSet,
       'chunk-cache-service-monitor': lc.chunkCache.serviceMonitor,
       'chunk-cache-service-account': lc.chunkCache.serviceAccount,
     } else {}) +
    (if std.objectHas(lc.config.components, 'indexQueryCache') && lc.config.components.indexQueryCache.replicas > 0 then {
       'index-query-cache-service': lc.indexQueryCache.service,
       'index-query-cache-statefulset': lc.indexQueryCache.statefulSet,
       'index-query-cache-service-monitor': lc.indexQueryCache.serviceMonitor,
       'index-query-cache-service-account': lc.indexQueryCache.serviceAccount,
     } else {}) +
    (if std.objectHas(lc.config.components, 'resultsCache') && lc.config.components.resultsCache.replicas > 0 then {
       'results-cache-service': lc.resultsCache.service,
       'results-cache-statefulset': lc.resultsCache.statefulSet,
       'results-cache-service-monitor': lc.resultsCache.serviceMonitor,
       'results-cache-service-account': lc.resultsCache.serviceAccount,
     } else {}),
}
