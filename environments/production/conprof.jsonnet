local c = import 'conprof/conprof.libsonnet';
local k3 = import 'ksonnet/ksonnet.beta.3/k.libsonnet';
local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

local conprof = c + c.withConfigMap {
  local conprof = self,

  config+:: {
    name: 'conprof',
    namespace: '${NAMESPACE}',
    image: '${IMAGE}:${IMAGE_TAG}',
    version: '${IMAGE_TAG}',

    rawconfig+:: {
      scrape_configs: [{
        job_name: 'thanos',
        kubernetes_sd_configs: [{
          namespaces: { names: ['${NAMESPACE}'] },
          role: 'pod',
        }],
        relabel_configs: [
          {
            action: 'keep',
            regex: 'observatorium-thanos-.+',
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
        scrape_interval: '30s',
        scrape_timeout: '1m',
      }, {
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
        scrape_interval: '30s',
        scrape_timeout: '1m',
      }, {
        job_name: 'telemeter',
        kubernetes_sd_configs: [{
          namespaces: { names: ['${NAMESPACE}'] },
          role: 'pod',
        }],
        relabel_configs: [
          {
            action: 'keep',
            regex: 'telemeter-server-.+',
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
        scrape_interval: '30s',
        scrape_timeout: '1m',
        scheme: 'https',
        tls_config: {
          insecure_skip_verify: true,
        },
      }],
    },
  },

  roleBindings:
    local roleBinding = k.rbac.v1.roleBinding;

    local newSpecificRoleBinding(namespace) =
      roleBinding.new() +
      roleBinding.mixin.metadata.withName(conprof.config.name) +
      roleBinding.mixin.metadata.withNamespace(namespace) +
      roleBinding.mixin.metadata.withLabels(conprof.config.commonLabels) +
      roleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
      roleBinding.mixin.roleRef.withName(conprof.config.name) +
      roleBinding.mixin.roleRef.mixinInstance({ kind: 'Role' }) +
      roleBinding.withSubjects([{ kind: 'ServiceAccount', name: 'prometheus-telemeter', namespace: conprof.config.namespace }]);

    local roleBindingList = k3.rbac.v1.roleBindingList;
    roleBindingList.new([newSpecificRoleBinding(x) for x in conprof.config.namespaces]),

  service+: {
    metadata+: {
      annotations+: {
        'service.alpha.openshift.io/serving-cert-secret-name': 'conprof-tls',
      },
    },
    spec+: {
      ports+: [
        { name: 'https', port: 8443, targetPort: 8443 },
      ],
    },
  },

  local statefulset = k.apps.v1.statefulSet,
  local volume = statefulset.mixin.spec.template.spec.volumesType,
  local container = statefulset.mixin.spec.template.spec.containersType,
  local volumeMount = container.volumeMountsType,

  statefulset+: {
    spec+: {
      replicas: '${{CONPROF_REPLICAS}}',
      template+: {
        spec+: {
          containers: std.map(
                        function(c) if c.name == 'conprof' then c {
                          resources: {
                            requests: {
                              cpu: '${CONPROF_CPU_REQUEST}',
                              memory: '${CONPROF_MEMORY_REQUEST}',
                            },
                            limits: {
                              cpu: '${CONPROF_CPU_LIMITS}',
                              memory: '${CONPROF_MEMORY_LIMITS}',
                            },
                          },
                        } else c,
                        super.containers
                      )
                      + [
                        container.new('proxy', '${PROXY_IMAGE}:${PROXY_IMAGE_TAG}') +
                        container.withArgs([
                          '-provider=openshift',
                          '-https-address=:%d' % conprof.service.spec.ports[1].port,
                          '-http-address=',
                          '-email-domain=*',
                          '-upstream=http://localhost:%d' % conprof.service.spec.ports[0].port,
                          '-openshift-service-account=prometheus-telemeter',
                          '-openshift-sar={"resource": "namespaces", "verb": "get", "name": "${NAMESPACE}", "namespace": "${NAMESPACE}"}',
                          '-openshift-delegate-urls={"/": {"resource": "namespaces", "verb": "get", "name": "${NAMESPACE}", "namespace": "${NAMESPACE}"}}',
                          '-tls-cert=/etc/tls/private/tls.crt',
                          '-tls-key=/etc/tls/private/tls.key',
                          '-client-secret-file=/var/run/secrets/kubernetes.io/serviceaccount/token',
                          '-cookie-secret-file=/etc/proxy/secrets/session_secret',
                          '-openshift-ca=/etc/pki/tls/cert.pem',
                          '-openshift-ca=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
                        ]) +
                        container.withPorts([
                          { name: 'https', containerPort: conprof.service.spec.ports[1].port },
                        ]) +
                        container.withVolumeMounts(
                          [
                            volumeMount.new('secret-conprof-tls', '/etc/tls/private'),
                            volumeMount.new('secret-conprof-proxy', '/etc/proxy/secrets'),
                          ]
                        ) +
                        container.mixin.resources.withRequests({
                          cpu: '${CONPROF_PROXY_CPU_REQUEST}',
                          memory: '${CONPROF_PROXY_MEMORY_REQUEST}',
                        }) +
                        container.mixin.resources.withLimits({
                          cpu: '${CONPROF_PROXY_CPU_LIMITS}',
                          memory: '${CONPROF_PROXY_MEMORY_LIMITS}',
                        }),
                      ],

          serviceAccount: 'prometheus-telemeter',
          serviceAccountName: 'prometheus-telemeter',
          volumes+: [
            { name: 'secret-conprof-tls', secret: { secretName: 'conprof-tls' } },
            { name: 'secret-conprof-proxy', secret: { secretName: 'conprof-proxy' } },
          ],
        },
      },
    },
  },
};

{
  'conprof-template': {
    apiVersion: 'v1',
    kind: 'Template',
    metadata: {
      name: 'conprof',
    },
    objects: [
      conprof.configmap {
        metadata+: {
          namespace:: 'hidden',
        },
      },
      conprof.statefulset {
        metadata+: {
          namespace:: 'hidden',
        },
      },
      conprof.service {
        metadata+: {
          namespace:: 'hidden',
        },
      },
    ] + [
      object {
        metadata+: {
          namespace:: 'hidden',
        },
      }
      for object in conprof.roles.items
    ] + [
      object {
        metadata+: {
          namespace:: 'hidden',
        },
      }
      for object in conprof.roleBindings.items
    ],

    parameters: [
      { name: 'NAMESPACE', value: 'telemeter' },
      { name: 'OBSERVATORIUM_LOGS_NAMESPACE', value: 'observatorium-logs' },
      { name: 'IMAGE', value: 'quay.io/conprof/conprof' },
      { name: 'IMAGE_TAG', value: 'master-2020-04-29-73bf4f0' },
      { name: 'CONPROF_REPLICAS', value: '1' },
      { name: 'CONPROF_CPU_REQUEST', value: '1' },
      { name: 'CONPROF_MEMORY_REQUEST', value: '4Gi' },
      { name: 'CONPROF_CPU_LIMITS', value: '4' },
      { name: 'CONPROF_MEMORY_LIMITS', value: '8Gi' },
      { name: 'PROXY_IMAGE', value: 'quay.io/openshift/origin-oauth-proxy' },
      { name: 'PROXY_IMAGE_TAG', value: '4.4.0' },
      { name: 'CONPROF_PROXY_CPU_REQUEST', value: '100m' },
      { name: 'CONPROF_PROXY_MEMORY_REQUEST', value: '100Mi' },
      { name: 'CONPROF_PROXY_CPU_LIMITS', value: '200m' },
      { name: 'CONPROF_PROXY_MEMORY_LIMITS', value: '200Mi' },
    ],
  },
  'conprof-observatorium-logs-rbac-template': {
    apiVersion: 'v1',
    kind: 'Template',
    metadata: {
      name: 'conprof-observatorium-logs-rbac',
    },
    objects: [
      object {
        metadata+: {
          namespace:: 'hidden',
        },
      }
      for object in conprof.roles.items
    ] + [
      object {
        metadata+: {
          namespace:: 'hidden',
        },
      }
      for object in conprof.roleBindings.items
    ],
    parameters: [
      { name: 'NAMESPACE', value: 'observatorium-logs' },
    ],
  },
}
