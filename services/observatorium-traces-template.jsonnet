local obs = import 'observatorium.libsonnet';
{
  apiVersion: 'template.openshift.io/v1',
  kind: 'Template',
  metadata: {
    name: 'observatorium-traces',
  },
  objects: [
    obs.tracingsubs.otelcol,
    obs.tracingsubs.jaeger,
    obs.tracingsubs.elasticsearch,
  ] + [
    obs.tracing.manifests[name] {
      metadata+: {
      },
    }
    for name in std.objectFields(obs.tracing.manifests)
  ],
  parameters: [
    { name: 'NAMESPACE', value: 'observatorium-traces' },
    { name: 'OPENTELEMETRY_OPERATOR_VERSION', value: '0.44.1-1' },
    { name: 'OPENTELEMETRY_OPERATOR_NAMESPACE', value: 'openshift-operators' },
    { name: 'OPENTELEMETRY_OPERATOR_SOURCE', value: 'redhat-operators' },
    { name: 'OPENTELEMETRY_COLLECTOR_IMAGE', value: 'ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib' },
    { name: 'OPENTELEMETRY_COLLECTOR_IMAGE_TAG', value: '0.46.0' },
    { name: 'JAEGER_OPERATOR_VERSION', value: '1.30.2' },
    { name: 'JAEGER_OPERATOR_NAMESPACE', value: 'openshift-operators' },
    { name: 'JAEGER_OPERATOR_SOURCE', value: 'redhat-operators' },
    { name: 'ELASTICSEARCH_OPERATOR_VERSION', value: '5.4.1-24' },
    { name: 'ELASTICSEARCH_OPERATOR_NAMESPACE', value: 'openshift-operators' },
    { name: 'ELASTICSEARCH_OPERATOR_SOURCE', value: 'redhat-operators' },
  ],
}
