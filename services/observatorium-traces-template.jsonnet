local obs = import 'observatorium.libsonnet';
{
  apiVersion: 'v1',
  kind: 'Template',
  metadata: {
    name: 'observatorium-traces',
  },
  objects: [
    obs.tracing.manifests[name] {
      metadata+: {
        namespace:: 'hidden',
      },
    }
    for name in std.objectFields(obs.tracing.manifests)
  ] + [
    obs.otelcolsubs,
    obs.jaegersubs,
  ],
  parameters: [
    { name: 'NAMESPACE', value: 'observatorium-traces' },
    { name: 'OPENTELEMETRY_OPERATOR_RH_VERSION', value: '0.44.1-2' },
    { name: 'JAEGER_OPERATOR_RH_VERSION', value: '1.30.2' },
  ],
}
