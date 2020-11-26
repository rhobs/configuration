{
  local replicas = {
    'chunk-cache-statefulset': '${{LOKI_CHUNK_CACHE_REPLICAS}}',
    'index-query-cache-statefulset': '${{LOKI_INDEX_QUERY_CACHE_REPLICAS}}',
    'results-cache-statefulset': '${{LOKI_RESULTS_CACHE_REPLICAS}}',
  },

  lokiCaches+:: {
    manifests+:: {
      [name]+: super[name] {
        spec+: {
          replicas: replicas[name],
        },
      }
      for name in std.objectFields(super.manifests)
      if std.member(std.objectFields(replicas), name)
    },
  },
}
