{
  apiVersion: 'template.openshift.io/v1',
  kind: 'Template',
  metadata: {
    name: '${CONFIGMAP_NAME}',
    annotations: {
      'qontract.recycle': 'true',
    },
  },
  objects: [
    {
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata+: {
        name: '${CONFIGMAP_NAME}',
        annotations: {
          'qontract.recycle': 'true',
        },
      },
      data: {
        'receive.limits.yaml': '${{RECEIVE_LIMITS}}',
      },
    },
  ],
  parameters: [
    { name: 'CONFIGMAP_NAME' },
    { name: 'RECEIVE_LIMITS', description: 'The Thanos-Receive limits configuration' },
  ],
}
