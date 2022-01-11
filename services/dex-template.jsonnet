local dex = (import 'github.com/observatorium/observatorium/configuration/components/dex.libsonnet')({
  name:: 'dex',
  namespace:: '${NAMESPACE}',
  image:: '${IMAGE}:${IMAGE_TAG}',
  version:: '${IMAGE_TAG}',
  config:: {
    oauth2: {
      passwordConnector: 'local',
    },
    staticClients: [
      {
        id: 'test',
        name: 'test',
        secret: 'ZXhhbXBsZS1hcHAtc2VjcmV0',
      },
    ],
    enablePasswordDB: true,
    staticPasswords: [
      {
        email: 'admin@example.com',
        // bcrypt hash of the string "password"
        hash: '$2a$10$2b2cU8CPhOTaGrs1HRQuAueS7JTT5ZHsHSzYiFPm1leZck7Mc8T4W',
        username: 'admin',
        userID: '08a8684b-db88-4b73-90a9-3cd1661f5466',
      },
    ],
    issuer: 'http://${NAMESPACE}.${NAMESPACE}.svc.cluster.local:5556/dex',
    storage: {
      type: 'sqlite3',
      config: { file: '/storage/dex.db' },
    },
    web: {
      http: '0.0.0.0:5556',
    },
    logger: { level: 'debug' },
  },
  replicas: 1,
}) + {
  deployment+: {
    spec+: {
      replicas: '${{REPLICAS}}',  // additional parenthesis does matter, they convert argument to an int.
      template+: {
        spec+: {
          containers: [
            super.containers[0] {
              resources: {
                requests: {
                  cpu: '${DEX_CPU_REQUEST}',
                  memory: '${DEX_MEMORY_REQUEST}',
                },
                limits: {
                  cpu: '${DEX_CPU_LIMITS}',
                  memory: '${DEX_MEMORY_LIMITS}',
                },
              },
              volumeMounts: [
                { name: 'config', mountPath: '/etc/dex/cfg' },
                { name: 'storage', mountPath: '/storage', readOnly: false },
              ],
            },
          ],
          volumes: [
            {
              name: 'config',
              secret: {
                secretName: dex.config.name,
                items: [
                  { key: 'config.yaml', path: 'config.yaml' },
                ],
              },
            },
            {
              name: 'storage',
              persistentVolumeClaim: { claimName: dex.config.name },
            },
          ],
        },
      },
    },
  },
};

{
  apiVersion: 'v1',
  kind: 'Template',
  metadata: {
    name: 'dex',
  },
  objects: [
    dex[name] {
      metadata+: {
        namespace:: 'hidden',
      },
    }
    for name in std.objectFields(dex)
  ],
  parameters: [
    { name: 'NAMESPACE', value: 'dex' },
    { name: 'IMAGE', value: 'dexidp/dex' },
    { name: 'IMAGE_TAG', value: 'v2.30.0' },
    { name: 'REPLICAS', value: '1' },
    { name: 'DEX_CPU_REQUEST', value: '100m' },
    { name: 'DEX_MEMORY_REQUEST', value: '200Mi' },
    { name: 'DEX_CPU_LIMITS', value: '100m' },
    { name: 'DEX_MEMORY_LIMITS', value: '200Mi' },
  ],
}
