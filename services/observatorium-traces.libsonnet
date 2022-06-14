local tracing = (import 'github.com/observatorium/observatorium/configuration/components/tracing.libsonnet');
{
  local obs = self,

  elasticsearch:: {
    apiVersion: 'logging.openshift.io/v1',
    kind: 'Elasticsearch',
    metadata: {
      annotations: {
        'logging.openshift.io/elasticsearch-cert-management': 'true',
        'logging.openshift.io/elasticsearch-cert.jaeger-shared-es': 'user.jaeger',
        'logging.openshift.io/elasticsearch-cert.curator-shared-es': 'system.logging.curator',
      },
      name: 'shared-es',
      namespace: '${NAMESPACE}',
    },
    spec: {
      managementState: 'Managed',
      nodeSpec: {
        resources: {
          limits: {
            memory: '${ELASTICSEARCH_LIMIT_MEMORY}',
          },
          requests: {
            cpu: '${ELASTICSEARCH_REQUEST_CPU}',
            memory: '${ELASTICSEARCH_REQUEST_MEMORY}',
          },
        },
      },
      nodes: [
        {
          nodeCount: 1,
          proxyResources: {},
          resources: {},
          roles: [
            'master',
            'client',
            'data',
          ],
          storage: {},
        },
      ],
      redundancyPolicy: 'ZeroRedundancy',
    },
  },

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
