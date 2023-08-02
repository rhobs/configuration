local minio = (import 'github.com/observatorium/observatorium/configuration/components/minio.libsonnet')({
  name:: 'minio',
  namespace:: '${NAMESPACE}',
  image:: '${IMAGE}:${IMAGE_TAG}',
  version:: '${IMAGE_TAG}',
  accessKey:: '${MINIO_ACCESS_KEY}',
  secretKey:: '${MINIO_SECRET_KEY}',
  buckets:: ['thanos', 'loki', 'rules', 'parca'],
  replicas: 1,
}) + {
  deployment+: {
    spec+: {
      replicas: '${{REPLICAS}}',  // additional parenthesis does matter, they convert argument to an int.
      template+: {
        spec+: {
          containers: [
            super.containers[0] {
              image: '${IMAGE}:${IMAGE_TAG}',
              resources: {
                requests: {
                  cpu: '${MINIO_CPU_REQUEST}',
                  memory: '${MINIO_MEMORY_REQUEST}',
                },
                limits: {
                  cpu: '${MINIO_CPU_LIMITS}',
                  memory: '${MINIO_MEMORY_LIMITS}',
                },
              },
            },
          ],
        },
      },
    },
  },
  pvc+: {
    spec+: {
      resources: {
        requests: {
          storage: '${MINIO_STORAGE}',
        },
      },
    },
  },
};

{
  apiVersion: 'template.openshift.io/v1',
  kind: 'Template',
  metadata: {
    name: 'minio',
  },
  objects: [
    minio[name] {
      metadata+: {
        namespace:: 'hidden',
      },
    }
    for name in std.objectFields(minio)
  ],
  parameters: [
    { name: 'NAMESPACE', value: 'minio' },
    { name: 'IMAGE', value: 'minio/minio' },
    { name: 'IMAGE_TAG', value: 'RELEASE.2023-05-27T05-56-19Z' },
    { name: 'REPLICAS', value: '1' },
    { name: 'MINIO_CPU_REQUEST', value: '100m' },
    { name: 'MINIO_MEMORY_REQUEST', value: '200Mi' },
    { name: 'MINIO_CPU_LIMITS', value: '100m' },
    { name: 'MINIO_MEMORY_LIMITS', value: '200Mi' },
    { name: 'MINIO_ACCESS_KEY', value: 'minio' },
    { name: 'MINIO_SECRET_KEY', value: 'minio123' },
    { name: 'MINIO_STORAGE', value: '10Gi' },
  ],
}
