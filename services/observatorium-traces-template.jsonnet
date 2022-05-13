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
  ],
  parameters: [
    { name: 'NAMESPACE', value: 'observatorium-traces' },
  ],
}
