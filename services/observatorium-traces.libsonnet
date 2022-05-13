local tracing = (import 'github.com/observatorium/observatorium/configuration/components/tracing.libsonnet');
{
  local obs = self,

  tracing:: tracing({
    namespace: 'observatorium',
    commonLabels+:: obs.config.commonLabels,
    enabled: true,
    tenants: [
      tenant.name
      for tenant in (import '../configuration/observatorium/tenants.libsonnet').tenants
    ],
  }),

  manifests+::
    if obs.tracing.config.enabled then {
      ['tracing-' + name]: obs.tracing.manifests[name]
      for name in std.objectFields(obs.tracing.manifests)
    } else {},
}
