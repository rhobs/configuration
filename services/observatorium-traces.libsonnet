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
  }),


  tracingsubs:: {
    otelcol:: {
      apiVersion: 'operators.coreos.com/v1alpha1',
      kind: 'Subscription',
      metadata: {
        name: 'rhobs-opentelemetry',
        namespace: 'openshift-operators',
      },
      spec: {
        channel: 'stable',
        installPlanApproval: 'Automatic',
        name: 'opentelemetry-product',
        source: 'redhat-operators',
        sourceNamespace: 'openshift-marketplace',
        startingCSV: 'opentelemetry-operator.v${OPENTELEMETRY_OPERATOR_RH_VERSION}',
      },
    },

    jaeger:: {
      apiVersion: 'operators.coreos.com/v1alpha1',
      kind: 'Subscription',
      metadata: {
        name: 'rhobs-jaeger',
        namespace: 'openshift-operators',
      },
      spec: {
        channel: 'stable',
        installPlanApproval: 'Automatic',
        name: 'jaeger-product',
        source: 'redhat-operators',
        sourceNamespace: 'openshift-marketplace',
        startingCSV: 'jaeger-operator.v${JAEGER_OPERATOR_RH_VERSION}',
      },
    },
  },
}
