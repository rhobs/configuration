local obs = import 'observatorium.libsonnet';
{
  apiVersion: 'v1',
  kind: 'Template',
  metadata: {
    name: 'observatorium-traces',
  },
  objects: [
    obs.tracingsubs.otelcol,
    obs.tracingsubs.jaeger,
  ] + [
    obs.tracing.manifests[name] {
      metadata+: {
        namespace:: 'hidden',
      },
    }
    for name in std.objectFields(obs.tracing.manifests)
  ],
  parameters: [
    { name: 'NAMESPACE', value: 'observatorium-traces' },
    { name: 'OPENTELEMETRY_OPERATOR_VERSION', value: '0.44.1-2' },
    { name: 'OPENTELEMETRY_OPERATOR_NAMESPACE', value: 'openshift-operators' },
    { name: 'OPENTELEMETRY_OPERATOR_SOURCE', value: 'redhat-operators' },
    { name: 'JAEGER_OPERATOR_VERSION', value: '1.30.2' },
    { name: 'JAEGER_OPERATOR_NAMESPACE', value: 'openshift-operators' },
    { name: 'JAEGER_OPERATOR_SOURCE', value: 'redhat-operators' },
  ],
}
