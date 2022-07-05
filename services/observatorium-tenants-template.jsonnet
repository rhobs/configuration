{
  apiVersion: 'v1',
  kind: 'Template',
  metadata: {
    name: '${SECRET_NAME}',
    annotations: {
      'qontract.recycle': 'true',
    },
  },
  objects: [
    {
      apiVersion: 'v1',
      kind: 'Secret',
      metadata+: {
        name: '${SECRET_NAME}',
        annotations: {
          'qontract.recycle': 'true',
        },
      },
      type: 'Opaque',
      stringData: {
        'client-id': '${CLIENT_ID}',
        'client-secret': '${CLIENT_SECRET}',
        'issuer-url': 'https://sso.redhat.com/auth/realms/redhat-external',
        'tenants.yaml': '${TENANTS}',
      },
    },
  ],
  parameters: [
    { name: 'SECRET_NAME' },
    { name: 'CLIENT_ID' },
    { name: 'CLIENT_SECRET' },
    { name: 'TENANTS' },
  ],
}
