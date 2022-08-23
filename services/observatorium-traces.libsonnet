local tracing = (import 'github.com/observatorium/observatorium/configuration/components/tracing.libsonnet');
{
  local obs = self,

  elasticsearch:: {
    apiVersion: 'logging.openshift.io/v1',
    kind: 'Elasticsearch',
    metadata: {
      annotations: {
        'logging.openshift.io/elasticsearch-cert-management': 'true',
        'logging.openshift.io/elasticsearch-cert.jaeger-${ELASTICSEARCH_NAME}': 'user.jaeger',
        'logging.openshift.io/elasticsearch-cert.curator-${ELASTICSEARCH_NAME}': 'system.logging.curator',
      },
      name: '${ELASTICSEARCH_NAME}',
      namespace: '${NAMESPACE}',
    },
    spec: {
      managementState: 'Managed',
      nodeSpec: {
        resources: {
          limits: {
            memory: '${ELASTICSEARCH_MEMORY}',
          },
          requests: {
            cpu: '${ELASTICSEARCH_REQUEST_CPU}',
            memory: '${ELASTICSEARCH_MEMORY}',
          },
        },
      },
      nodes: [
        {
          nodeCount: '${{ELASTICSEARCH_NODE_COUNT}}',
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
      redundancyPolicy: '${ELASTICSEARCH_REDUNDANCY_POLICY}',
    },
  },

  tracing:: tracing({
    name: obs.config.name,
    namespace: '${NAMESPACE}',
    commonLabels+:: obs.config.commonLabels,
    enabled: true,
    monitoring: true,
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
      strategy: 'production',
      storage: {
        type: 'elasticsearch',
        elasticsearch: {
          name: '${ELASTICSEARCH_NAME}',
          useCertManagement: true,
          doNotProvision: true,
        },
      },
    },
  }),

}
