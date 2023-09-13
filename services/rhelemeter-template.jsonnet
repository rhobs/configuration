local rhelemeter = (import 'rhelemeter.libsonnet') {
  _config+:: {
    namespace: '${NAMESPACE}',

    rhelemeterServer+:: {
      image: '${IMAGE}:${IMAGE_TAG}',
      replicas: '${{REPLICAS}}',
      logLevel: '${RHELEMETER_LOG_LEVEL}',
      rhelemeterForwardURL: '${RHELEMETER_FORWARD_URL}',
      rhelemeterTenantID: '${RHELEMETER_TENANT_ID}',
      oidcIssuer: '${RHELEMETER_OIDC_ISSUER}',
      clientID: '${RHELEMETER_CLIENT_ID}',
      clientSecret: '${RHELEMETER_CLIENT_SECRET}',
      externalMtlsCa: '${RHELEMETER_EXTERNAL_MTLS_CA}',
      externalMtlsCrt: '${RHELEMETER_EXTERNAL_MTLS_CRT}',
      externalMtlsKey: '${RHELEMETER_EXTERNAL_MTLS_KEY}',
      clientInfoPSK: '${RHELEMETER_CLIENT_INFO_PSK}',
      resourceLimits:: {
        cpu: '${RHELEMETER_SERVER_CPU_LIMIT}',
        memory: '${RHELEMETER_SERVER_MEMORY_LIMIT}',
      },
      resourceRequests:: {
        cpu: '${RHELEMETER_SERVER_CPU_REQUEST}',
        memory: '${RHELEMETER_SERVER_MEMORY_REQUEST}',
      },
    },
  },
};

{
  apiVersion: 'template.openshift.io/v1',
  kind: 'Template',
  metadata: { name: 'rhelemeter' },
  objects: [
    rhelemeter.rhelemeterServer[name] {
      metadata+: { namespace:: 'hidden' },
    }
    for name in std.objectFields(rhelemeter.rhelemeterServer)
  ],
  parameters: [
    { name: 'NAMESPACE', value: 'rhelemeter' },
    { name: 'IMAGE_TAG', value: '82f71d3' },
    { name: 'IMAGE', value: 'quay.io/app-sre/telemeter' },
    { name: 'REPLICAS', value: '2' },
    { name: 'RHELEMETER_TENANT_ID', value: 'rhel' },
    { name: 'RHELEMETER_FORWARD_URL', value: '' },
    { name: 'RHELEMETER_OIDC_ISSUER', value: '' },
    { name: 'RHELEMETER_CLIENT_ID', value: '' },
    { name: 'RHELEMETER_CLIENT_SECRET', value: '' },
    { name: 'RHELEMETER_EXTERNAL_MTLS_CA', value: '' },
    { name: 'RHELEMETER_EXTERNAL_MTLS_CRT', value: '' },
    { name: 'RHELEMETER_EXTERNAL_MTLS_KEY', value: '' },
    { name: 'RHELEMETER_CLIENT_INFO_PSK', value: '' },
    { name: 'RHELEMETER_LOG_LEVEL', value: 'warn' },
    { name: 'RHELEMETER_SERVER_CPU_LIMIT', value: '1' },
    { name: 'RHELEMETER_SERVER_CPU_REQUEST', value: '100m' },
    { name: 'RHELEMETER_SERVER_MEMORY_LIMIT', value: '1Gi' },
    { name: 'RHELEMETER_SERVER_MEMORY_REQUEST', value: '500Mi' },
  ],
}
