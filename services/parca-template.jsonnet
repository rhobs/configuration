local p = import 'github.com/parca-dev/parca/deploy/lib/parca/parca.libsonnet';


local config = {
  name: 'parca',
  namespace: '${NAMESPACE}',  // Target namespace to deploy Parca.
  image: '${IMAGE}:${IMAGE_TAG}',
  version: '${IMAGE_TAG}',
  replicas: 1,  // RUNTIME ERROR: parca replicas has to be number >= 0


  // Don't change this, parca default is 7070, otherwise change args in container or fix parca.libsonnet to
  // do so.
  port: 7070,
  portTLS: 10902,
  serviceAccountName: '${SERVICE_ACCOUNT_NAME}',
  serviceMonitor: true,


  namespaces: {
    default: '${NAMESPACE}',
    metrics: '${OBSERVATORIUM_METRICS_NAMESPACE}',
    mst: '${OBSERVATORIUM_MST_NAMESPACE}',
    logs: '${OBSERVATORIUM_LOGS_NAMESPACE}',
    telemeter: '${TELEMETER_NAMESPACE}',
  },

  rawconfig+:: {
    debug_info: {
      bucket: {
        type: 'FILESYSTEM',
        config: { directory: '/parca' },
      },
      cache: {
        type: 'FILESYSTEM',
        config: { directory: '/parca' },
      },
    },
    scrape_configs: [
      {
        job_name: 'parca',
        scrape_interval: '1m',
        scrape_timeout: '30s',
        static_configs: [
          {
            targets: ['localhost:7070'],
            labels: {
              instance: 'parca',
              job: 'parca',
            },
          },
        ],
      },
      {
        job_name: 'rhobs',
        kubernetes_sd_configs: [{
          namespaces: { names: [
            config.namespaces.default,
            config.namespaces.metrics,
            config.namespaces.mst,
          ] },
          role: 'pod',
        }],
        relabel_configs: [
          // gubernator does not appear to expose pprof endpoints
          {
            action: 'drop',
            regex: 'gubernator',
            source_labels: ['__meta_kubernetes_pod_container_name'],
          },
          {
            action: 'keep',
            regex: 'observatorium-.+',
            source_labels: ['__meta_kubernetes_pod_name'],
          },
          {
            action: 'keep',
            regex: 'http',
            source_labels: ['__meta_kubernetes_pod_container_port_name'],
          },
          {
            source_labels: ['__meta_kubernetes_namespace'],
            target_label: 'namespace',
          },
          {
            source_labels: ['__meta_kubernetes_pod_name'],
            target_label: 'pod',
          },
          {
            source_labels: ['__meta_kubernetes_pod_container_name'],
            target_label: 'container',
          },
        ],
        scrape_interval: '1m',
        scrape_timeout: '30s',
      },
      {
        job_name: 'loki',
        kubernetes_sd_configs: [{
          namespaces: { names: ['${OBSERVATORIUM_LOGS_NAMESPACE}'] },
          role: 'pod',
        }],
        relabel_configs: [
          {
            action: 'keep',
            regex: 'observatorium-loki-.+',
            source_labels: ['__meta_kubernetes_pod_name'],
          },
          {
            action: 'keep',
            regex: 'observatorium-loki-.+',
            source_labels: ['__meta_kubernetes_pod_container_name'],
          },
          {
            action: 'keep',
            regex: 'metrics',
            source_labels: ['__meta_kubernetes_pod_container_port_name'],
          },
          {
            source_labels: ['__meta_kubernetes_namespace'],
            target_label: 'namespace',
          },
          {
            source_labels: ['__meta_kubernetes_pod_name'],
            target_label: 'pod',
          },
          {
            source_labels: ['__meta_kubernetes_pod_container_name'],
            target_label: 'container',
          },
        ],
        scrape_interval: '1m',
        scrape_timeout: '30s',
      },
      {
        job_name: 'telemeter',
        kubernetes_sd_configs: [{
          namespaces: { names: [config.namespaces.telemeter] },
          role: 'pod',
        }],
        relabel_configs: [
          {
            action: 'keep',
            regex: 'telemeter-server.+',
            source_labels: ['__meta_kubernetes_pod_name'],
          },
          {
            action: 'keep',
            regex: 'internal',
            source_labels: ['__meta_kubernetes_pod_container_port_name'],
          },
          {
            source_labels: ['__meta_kubernetes_namespace'],
            target_label: 'namespace',
          },
          {
            source_labels: ['__meta_kubernetes_pod_name'],
            target_label: 'pod',
          },
          {
            source_labels: ['__meta_kubernetes_pod_container_name'],
            target_label: 'container',
          },
        ],
        scrape_interval: '1m',
        scrape_timeout: '30s',
        scheme: 'https',
        tls_config: {
          insecure_skip_verify: true,
        },
      },
    ],
  },
};

local parca = p(config);

local ourRole = parca.role {
  rules: [{
    apiGroups: [''],
    resources: ['services', 'endpoints', 'pods'],
    verbs: ['get', 'list', 'watch'],
  }],
};

local ourRoleBinding = parca.roleBinding {
  subjects: [{
    kind: 'ServiceAccount',
    name: config.serviceAccountName,
    namespace: config.namespaces.default,
  }],
};

local proxyContainer = {
  name: 'proxy',
  image: '${OAUTH_PROXY_IMAGE}:${OAUTH_PROXY_IMAGE_TAG}',
  args: [
    '-provider=openshift',
    '-https-address=:%d' % config.portTLS,
    '-http-address=',
    '-email-domain=*',
    '-upstream=http://localhost:%d' % config.port,
    '-openshift-service-account=' + config.serviceAccountName,
    '-openshift-sar={"resource": "namespaces", "verb": "get", "name": "${NAMESPACE}", "namespace": "${NAMESPACE}"}',
    '-openshift-delegate-urls={"/": {"resource": "namespaces", "verb": "get", "name": "${NAMESPACE}", "namespace": "${NAMESPACE}"}}',
    '-tls-cert=/etc/tls/private/tls.crt',
    '-tls-key=/etc/tls/private/tls.key',
    '-client-secret-file=/var/run/secrets/kubernetes.io/serviceaccount/token',
    '-cookie-secret-file=/etc/proxy/secrets/session_secret',
    '-openshift-ca=/etc/pki/tls/cert.pem',
    '-openshift-ca=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
  ],
  ports: [
    { name: 'https', containerPort: config.portTLS },
  ],
  volumeMounts: [
    { name: 'secret-parca-tls', mountPath: '/etc/tls/private', readOnly: false },
    { name: 'secret-parca-proxy', mountPath: '/etc/proxy/secrets', readOnly: false },
  ],
  resources: {
    requests: {
      cpu: '${PARCA_PROXY_CPU_REQUEST}',
      memory: '${PARCA_PROXY_MEMORY_REQUEST}',
    },
    limits: {
      cpu: '${PARCA_PROXY_CPU_LIMITS}',
      memory: '${PARCA_PROXY_MEMORY_LIMITS}',
    },
  },
};

{
  'parca-template': {
    apiVersion: 'template.openshift.io/v1',
    kind: 'Template',
    metadata: {
      name: 'parca',
    },
    objects: [
      parca.configmap {
        metadata+: {
          namespace:: 'hidden',
          annotations+: {
            'qontract.recycle': 'true',
          },
        },
        data: {
          'parca.yaml': std.manifestYamlDoc(config.rawconfig),
        },
      },
      parca.deployment {
        metadata+: { namespace:: 'hidden' },
        spec+: {
          template+: {
            spec+: {
              securityContext: null,
              serviceAccountName: config.serviceAccountName,
              containers: [
                super.containers[0] {
                  args+: ['--storage-tsdb-retention-time=${RETENTION_TIME}'],
                  resources: {
                    requests: {
                      cpu: '${PARCA_CPU_REQUEST}',
                      memory: '${PARCA_MEMORY_REQUEST}',
                    },
                    limits: {
                      cpu: '${PARCA_CPU_LIMITS}',
                      memory: '${PARCA_MEMORY_LIMITS}',
                    },
                  },
                },
              ] + [proxyContainer],
              volumes+: [
                { name: 'secret-parca-tls', secret: { secretName: 'conprof-tls' } },
                { name: 'secret-parca-proxy', secret: { secretName: 'conprof-proxy' } },
              ],
            },
          },
        },
      },
      parca.service {
        metadata+: {
          namespace:: 'hidden',
          annotations+: {
            'service.alpha.openshift.io/serving-cert-secret-name': 'conprof-tls',
          },
        },
        spec+: {
          ports: [
            { name: 'https', port: 10902, targetPort: config.portTLS },
            { name: 'http', port: 8443, targetPort: config.port },
          ],
        },
      },
      ourRole {
        metadata+: { namespace:: 'hidden' },
      },
      ourRoleBinding {
        metadata+: { namespace:: 'hidden' },
      },
      parca.serviceMonitor,
    ],
    parameters: [
      { name: 'NAMESPACE', value: 'observatorium' },
      { name: 'OBSERVATORIUM_METRICS_NAMESPACE', value: 'observatorium-metrics' },
      { name: 'OBSERVATORIUM_MST_NAMESPACE', value: 'observatorium-mst' },
      { name: 'OBSERVATORIUM_LOGS_NAMESPACE', value: 'observatorium-logs' },
      { name: 'TELEMETER_NAMESPACE', value: 'telemeter' },
      { name: 'IMAGE', value: 'ghcr.io/parca-dev/parca' },
      { name: 'IMAGE_TAG', value: 'v0.12.0' },
      { name: 'PARCA_REPLICAS', value: '1' },
      { name: 'PARCA_CPU_REQUEST', value: '1' },
      { name: 'PARCA_MEMORY_REQUEST', value: '4Gi' },
      { name: 'PARCA_CPU_LIMITS', value: '2' },
      { name: 'PARCA_MEMORY_LIMITS', value: '8Gi' },
      { name: 'OAUTH_PROXY_IMAGE', value: 'quay.io/openshift/origin-oauth-proxy' },
      { name: 'OAUTH_PROXY_IMAGE_TAG', value: '4.7.0' },
      { name: 'PARCA_PROXY_CPU_REQUEST', value: '100m' },
      { name: 'PARCA_PROXY_MEMORY_REQUEST', value: '100Mi' },
      { name: 'PARCA_PROXY_CPU_LIMITS', value: '200m' },
      { name: 'PARCA_PROXY_MEMORY_LIMITS', value: '200Mi' },
      { name: 'SERVICE_ACCOUNT_NAME', value: 'observatorium' },
      { name: 'RETENTION_TIME', value: '12h' },
    ],
  },
  'parca-observatorium-remote-ns-rbac-template': {
    apiVersion: 'template.openshift.io/v1',
    kind: 'Template',
    metadata: {
      name: 'parca-observatorium-rbac',
    },
    objects: [
      ourRole {
        metadata+: { namespace: '${NAMESPACE}' },
      },
      ourRoleBinding {
        metadata+: { namespace: '${NAMESPACE}' },
      },
      ourRole {
        metadata+: { namespace: '${OBSERVATORIUM_METRICS_NAMESPACE}' },
      },
      ourRoleBinding {
        metadata+: { namespace: '${OBSERVATORIUM_METRICS_NAMESPACE}' },
      },
      ourRole {
        metadata+: { namespace: '${OBSERVATORIUM_MST_NAMESPACE}' },
      },
      ourRoleBinding {
        metadata+: { namespace: '${OBSERVATORIUM_MST_NAMESPACE}' },
      },
      ourRole {
        metadata+: { namespace: '${OBSERVATORIUM_LOGS_NAMESPACE}' },
      },
      ourRoleBinding {
        metadata+: { namespace: '${OBSERVATORIUM_LOGS_NAMESPACE}' },
      },
      ourRole {
        metadata+: { namespace: '${TELEMETER_NAMESPACE}' },
      },
      ourRoleBinding {
        metadata+: { namespace: '${TELEMETER_NAMESPACE}' },
      },
    ],
    parameters: [
      { name: 'IMAGE_TAG', value: 'v0.12.0' },
      { name: 'NAMESPACE', value: 'observatorium' },
      { name: 'OBSERVATORIUM_METRICS_NAMESPACE', value: 'observatorium-metrics' },
      { name: 'OBSERVATORIUM_MST_NAMESPACE', value: 'observatorium-mst' },
      { name: 'OBSERVATORIUM_LOGS_NAMESPACE', value: 'observatorium-logs' },
      { name: 'TELEMETER_NAMESPACE', value: 'telemeter' },
      { name: 'SERVICE_ACCOUNT_NAME', value: 'observatorium' },
    ],
  },
}
