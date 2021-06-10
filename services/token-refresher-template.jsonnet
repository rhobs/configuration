local oauthProxy = import './sidecars/oauth-proxy.libsonnet';

local tr = (import 'github.com/observatorium/token-refresher/jsonnet/lib/token-refresher.libsonnet')({
  name: 'telemeter-token-refresher',
  namespace: '${NAMESPACE}',
  version: '${TOKEN_REFRESHER_IMAGE_TAG}',
  url: 'http://observatorium-observatorium-api.${OBSERVATORIUM_NAMESPACE}.svc:8080',
  secretName: '${TOKEN_REFRESHER_SECRET_NAME}',
}) + {
  local tr = self,
  config+:: {
    serviceAccountName: '${SERVICE_ACCOUNT_NAME}',
  },

  local oauth = oauthProxy({
    name: 'token-refresher',
    image: '${OAUTH_PROXY_IMAGE}:${OAUTH_PROXY_IMAGE_TAG}',
    upstream: 'http://localhost:8080',
    serviceAccountName: tr.config.serviceAccountName,
    sessionSecretName: 'token-refresher-proxy',
    resources: {
      requests: {
        cpu: '${OAUTH_PROXY_CPU_REQUEST}',
        memory: '${OAUTH_PROXY_MEMORY_REQUEST}',
      },
      limits: {
        cpu: '${OAUTH_PROXY_CPU_LIMITS}',
        memory: '${OAUTH_PROXY_MEMORY_LIMITS}',
      },
    },
  }),

  proxySecret: oauth.proxySecret {
    metadata+: { labels+: tr.config.commonLabels },
  },

  service+: oauth.service,

  deployment+: oauth.deployment,
};

{
  apiVersion: 'v1',
  kind: 'Template',
  metadata: {
    name: 'token-refresher',
  },
  objects: [
    tr[name] {
      metadata+: {
        namespace:: 'hidden',
      },
    }
    for name in std.objectFields(tr)
  ],
  parameters: [
    { name: 'NAMESPACE', value: 'telemeter' },
    { name: 'OAUTH_PROXY_IMAGE', value: 'quay.io/openshift/origin-oauth-proxy' },
    { name: 'OAUTH_PROXY_IMAGE_TAG', value: '4.7.0' },
    { name: 'OAUTH_PROXY_CPU_REQUEST', value: '100m' },
    { name: 'OAUTH_PROXY_MEMORY_REQUEST', value: '100Mi' },
    { name: 'OAUTH_PROXY_CPU_LIMITS', value: '200m' },
    { name: 'OAUTH_PROXY_MEMORY_LIMITS', value: '200Mi' },
    { name: 'OBSERVATORIUM_NAMESPACE', value: 'observatorium' },
    { name: 'SERVICE_ACCOUNT_NAME', value: 'prometheus-telemeter' },
    { name: 'TOKEN_REFRESHER_IMAGE_TAG', value: 'master-2021-03-05-b34376b' },
    { name: 'TOKEN_REFRESHER_SECRET_NAME', value: 'token-refrsher-oidc' },
  ],
}
