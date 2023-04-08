local obs = import 'observatorium.libsonnet';
{
  apiVersion: 'template.openshift.io/v1',
  kind: 'Template',
  metadata: { name: 'metric-federation-rule' },
  objects: [
    obs.thanos.manifests[name] {
      metadata+: { namespace:: 'hidden' },
    }
    for name in std.objectFields(obs.thanos.manifests)
    if obs.thanos.manifests[name] != null && std.startsWith(name, 'metric-federation')
  ],
  parameters: [
    { name: 'NAMESPACE', value: 'observatorium-metrics' },
    { name: 'NAMESPACES', value: '["observatorium-metrics"]' },
    { name: 'CONFIGMAP_RELOADER_IMAGE', value: 'quay.io/openshift/origin-configmap-reloader' },
    { name: 'CONFIGMAP_RELOADER_IMAGE_TAG', value: '4.5.0' },
    { name: 'JAEGER_AGENT_IMAGE_TAG', value: '1.29.0' },
    { name: 'JAEGER_AGENT_IMAGE', value: 'quay.io/app-sre/jaegertracing-jaeger-agent' },
    { name: 'JAEGER_COLLECTOR_NAMESPACE', value: '$(NAMESPACE)' },
    { name: 'SERVICE_ACCOUNT_NAME', value: 'prometheus-telemeter' },
    { name: 'STORAGE_CLASS', value: 'gp2' },
    { name: 'THANOS_CONFIG_SECRET', value: 'thanos-objectstorage' },
    { name: 'THANOS_IMAGE_TAG', value: 'v0.30.2' },
    { name: 'THANOS_IMAGE', value: 'quay.io/thanos/thanos' },
    { name: 'THANOS_QUERIER_NAMESPACE', value: 'observatorium-mst' },
    { name: 'THANOS_RULER_CPU_LIMIT', value: '1' },
    { name: 'THANOS_RULER_CPU_REQUEST', value: '500m' },
    { name: 'THANOS_RULER_LOG_LEVEL', value: 'info' },
    { name: 'THANOS_RULER_MEMORY_LIMIT', value: '4Gi' },
    { name: 'THANOS_RULER_MEMORY_REQUEST', value: '4Gi' },
    { name: 'THANOS_RULER_PVC_REQUEST', value: '50Gi' },
    { name: 'THANOS_RULER_REPLICAS', value: '2' },
    { name: 'THANOS_S3_SECRET', value: 'telemeter-thanos-stage-s3' },
  ],
}
