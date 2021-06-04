// JaegerAgent sidecar shared across components, thus instantiated outside components.
local jaegerAgentSidecar = (import 'sidecars/jaeger-agent.libsonnet')({
  image: '${JAEGER_AGENT_IMAGE}:${JAEGER_AGENT_IMAGE_TAG}',
  collectorAddress: 'dns:///jaeger-collector-headless.${JAEGER_COLLECTOR_NAMESPACE}.svc:14250',
});

{
  local replicas = {
    'chunk-cache-statefulset': '${{LOKI_CHUNK_CACHE_REPLICAS}}',
    'index-query-cache-statefulset': '${{LOKI_INDEX_QUERY_CACHE_REPLICAS}}',
    'results-cache-statefulset': '${{LOKI_RESULTS_CACHE_REPLICAS}}',
  },

  lokiCaches+:: {
    [name]+: {
      serviceMonitor+: {
        metadata+: {
          labels+: {
            prometheus: 'app-sre',
            'app.kubernetes.io/version':: 'hidden',
          },
        },
        spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
      },
    }
    for name in std.objectFieldsAll(super.lokiCaches)
    if std.objectHas(super.lokiCaches[name], 'serviceMonitor')
  } + {
    manifests+:: {
      [name]+: {
        spec+: {
          replicas: replicas[name],
          template+: {
            spec+: {
              securityContext: {},
            },
          },
        },
      }
      for name in std.objectFields(super.manifests)
      if std.member(std.objectFields(replicas), name)
    },
  },

  loki+:: {
    serviceMonitors+:: {
      [name]+: {
        metadata+: {
          labels+: {
            prometheus: 'app-sre',
            'app.kubernetes.io/version':: 'hidden',
          },
        },
        spec+: { namespaceSelector+: { matchNames: ['${NAMESPACE}'] } },
      }
      for name in std.objectFields(super.serviceMonitors)
    },

    manifests+:: {
      [name]+:
        local m = super[name];
        if m.kind == 'Deployment' || m.kind == 'StatefulSet' then
          m {
            spec+: {
              template+: {
                spec+: {
                  containers: [
                    c {
                      args: std.filter(function(arg)
                              !std.member([
                                '-distributor.replication-factor',
                                '-querier.worker-parallelism',
                              ], std.split(arg, '=')[0]), super.args)
                            + [
                              '-distributor.replication-factor=${LOKI_REPLICATION_FACTOR}',
                              '-querier.worker-parallelism=${LOKI_QUERY_PARALLELISM}',
                            ],
                    }
                    for c in super.containers
                  ],
                },
              },
            } + jaegerAgentSidecar.spec,
          }
        else
          m
      for name in std.objectFields(super.manifests)
    },
  },
}
