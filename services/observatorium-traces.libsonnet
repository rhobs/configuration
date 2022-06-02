local tracing = (import 'github.com/observatorium/observatorium/configuration/components/tracing.libsonnet');
{
  local obs = self,

  tracing:: tracing({
    name: obs.config.name,
    namespace: '${NAMESPACE}',
    commonLabels+:: obs.config.commonLabels,
    enabled: true,
    tenants: [
      tenant.name
      for tenant in (import '../configuration/observatorium/tenants.libsonnet').tenants
    ],
    otelcolTLS: {
      insecure: false,
      ca_file: '/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt',
    },
    otelcolImage: '${OPENTELEMETRY_COLLECTOR_IMAGE}',
    otelcolVersion: '${OPENTELEMETRY_COLLECTOR_IMAGE_TAG}',
  }),


  tracingsubs:: {
    otelcol:: {
      apiVersion: 'operators.coreos.com/v1alpha1',
      kind: 'Subscription',
      metadata: {
        name: 'rhobs-opentelemetry',
        namespace: '${OPENTELEMETRY_OPERATOR_NAMESPACE}',
      },
      spec: {
        channel: 'stable',
        installPlanApproval: 'Automatic',
        name: 'opentelemetry-product',
        source: '${OPENTELEMETRY_OPERATOR_SOURCE}',
        sourceNamespace: 'openshift-marketplace',
        startingCSV: 'opentelemetry-operator.v${OPENTELEMETRY_OPERATOR_VERSION}',
      },
    },

    jaeger:: {
      apiVersion: 'operators.coreos.com/v1alpha1',
      kind: 'Subscription',
      metadata: {
        name: 'rhobs-jaeger',
        namespace: '${JAEGER_OPERATOR_NAMESPACE}',
      },
      spec: {
        channel: 'stable',
        installPlanApproval: 'Automatic',
        name: 'jaeger-product',
        source: '${JAEGER_OPERATOR_SOURCE}',
        sourceNamespace: 'openshift-marketplace',
        startingCSV: 'jaeger-operator.v${JAEGER_OPERATOR_VERSION}',
      },
    },

    elasticsearch:: {
      apiVersion: 'operators.coreos.com/v1alpha1',
      kind: 'Subscription',
      metadata: {
        name: 'rhobs-elasticsearch',
        namespace: '${ELASTIC_OPERATOR_NAMESPACE}',
      },
      spec: {
        channel: 'stable',
        installPlanApproval: 'Automatic',
        name: 'elasticsearch-operator',
        source: '${ELASTICSEARCH_OPERATOR_SOURCE}',
        sourceNamespace: 'openshift-marketplace',
        startingCSV: 'elasticsearch-operator.${ELASTICSEARCH_OPERATOR_VERSION}',
      },
    },
  },
}
