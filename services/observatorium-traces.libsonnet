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
    jaegerSpec: {
      strategy: 'allinone',
    },
  }),

}
