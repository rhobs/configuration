local subscriptions = import 'observatorium-traces-subscriptions.libsonnet';
{
  apiVersion: 'template.openshift.io/v1',
  kind: 'Template',
  metadata: {
    name: 'observatorium-traces-subscriptions',
  },
  objects: [
    subscriptions.otelcol,
    subscriptions.jaeger,
    subscriptions.elasticsearch,
  ],
  parameters: [
    { name: 'OPENTELEMETRY_OPERATOR_VERSION', value: '0.44.1-1' },
    { name: 'OPENTELEMETRY_OPERATOR_NAMESPACE', value: 'openshift-operators' },
    { name: 'OPENTELEMETRY_OPERATOR_SOURCE', value: 'redhat-operators' },
    { name: 'JAEGER_OPERATOR_VERSION', value: '1.30.2' },
    { name: 'JAEGER_OPERATOR_NAMESPACE', value: 'openshift-operators' },
    { name: 'JAEGER_OPERATOR_SOURCE', value: 'redhat-operators' },
    { name: 'ELASTICSEARCH_OPERATOR_VERSION', value: '5.4.1-24' },
    { name: 'ELASTICSEARCH_OPERATOR_NAMESPACE', value: 'openshift-operators' },
    { name: 'ELASTICSEARCH_OPERATOR_SOURCE', value: 'redhat-operators' },
  ],
}
