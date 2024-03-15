local job = import 'job.libsonnet';
local rbac = import 'rbac.libsonnet';
local testdeployment = import 'test-deployment.libsonnet';

local rbacConfig = {
  roleName: 'rhobs-test',
  namespace: '${NAMESPACE}',
  roleBindingName: 'rhobs-test',
  serviceAccountName: '${SERVICE_ACCOUNT_NAME}',

  namespaces: {
    default: '${NAMESPACE}',
    observatorium: '${OBSERVATORIUM_NAMESPACE}',
    observatoriumMetrics: '${OBSERVATORIUM_METRICS_NAMESPACE}',
    minio: '${MINIO_NAMESPACE}',
    dex: '${DEX_NAMESPACE}',
    telemeter: '${TELEMETER_NAMESPACE}',
  },
};
local jobConfig = {
  name: '${JOB_NAME}',
  namespaces: '${JOB_NAMESPACES}',
  interval: '${JOB_INTERVAL}',
  timeout: '${JOB_TIMEOUT}',
  image: '${JOB_IMAGE}',
  imageTag: '${JOB_IMAGE_TAG}',
  serviceAccountName: rbacConfig.serviceAccountName,
};
local testConfig = {
  namespace: '${PROM_NAMESPACE}',
  configMapName: '${PROM_CONFIG_MAP}',
  replicas: '${PROM_REPLICAS}',
  image: '${PROM_IMAGE}',
  serviceName: '${PROM_SERVICE_NAME}',
};
local r = rbac(rbacConfig);
local j = job(jobConfig);
local d = testdeployment(testConfig);
local role = r.role {
  rules: [{
    apiGroups: ['', 'apps'],
    resources: ['services', 'endpoints', 'pods', 'deployments', 'statefulsets', 'pods/log'],
    verbs: ['get', 'list', 'watch'],

  }],
};
local roleBinding = r.roleBinding {
  subjects: [{
    kind: 'ServiceAccount',
    name: rbacConfig.serviceAccountName,
    namespace: rbacConfig.namespaces.default,
  }],
};
local deployment = d.deployment {
  spec: {
    replicas: testConfig.replicas,
    selector: {
      matchLabels: {
        app: 'prometheus-example-app',
      },
    },
    template: {
      metadata: {
        labels: {
          app: 'prometheus-example-app',
        },
      },
      spec: {
        containers: [
          {
            name: 'prometheus-example-app',
            image: '${PROM_IMAGE}',
            args: ['--config.file=/etc/prometheus/prometheus.yaml'],
            ports: [
              {
                name: 'http',
                containerPort: 9090,
              },
            ],
            volumeMounts+: [
              {
                name: 'config',
                mountPath: '/etc/prometheus',
              },
            ],


          },
        ],
        volume: [
          {
            name: 'config',
            configMap: {
              name: '${PROM_CONFIG_MAP}',
            },
          },
        ],
      },
    },
  },
};
{
  'rhobs-rbac-template': {
    apiVersion: 'template.openshift.io/v1',
    kind: 'Template',
    metadata: {
      name: 'rhobs-test-rbac',
    },
    objects: [
      r.serviceAccount {
        metadata+: { name: '${SERVICE_ACCOUNT_NAME}' },
      },
      role {
        metadata+: { namespace: '${NAMESPACE}' },
      },
      roleBinding {
        metadata+: { namespace: '${NAMESPACE}' },
      },
      role {
        metadata+: { namespace: '${OBSERVATORIUM_NAMESPACE}' },
      },
      roleBinding {
        metadata+: { namespace: '${OBSERVATORIUM_NAMESPACE}' },
      },
      role {
        metadata+: { namespace: '${OBSERVATORIUM_METRICS_NAMESPACE}' },
      },
      roleBinding {
        metadata+: { namespace: '${OBSERVATORIUM_METRICS_NAMESPACE}' },
      },
      role {
        metadata+: { namespace: '${MINIO_NAMESPACE}' },
      },
      roleBinding {
        metadata+: { namespace: '${MINIO_NAMESPACE}' },
      },
      role {
        metadata+: { namespace: '${DEX_NAMESPACE}' },
      },
      roleBinding {
        metadata+: { namespace: '${DEX_NAMESPACE}' },
      },
      role {
        metadata+: { namespace: '${TELEMETER_NAMESPACE}' },
      },
      roleBinding {
        metadata+: { namespace: '${TELEMETER_NAMESPACE}' },
      },

    ],
    parameters: [
      { name: 'NAMESPACE', value: 'observatorium' },
      { name: 'OBSERVATORIUM_NAMESPACE', value: 'observatorium' },
      { name: 'OBSERVATORIUM_METRICS_NAMESPACE', value: 'observatorium-metrics' },
      { name: 'MINIO_NAMESPACE', value: 'minio' },
      { name: 'DEX_NAMESPACE', value: 'dex' },
      { name: 'TELEMETER_NAMESPACE', value: 'telemeter' },
      { name: 'SERVICE_ACCOUNT_NAME', value: 'rhobs-test-job' },
    ],
  },
  'rhobs-test-job-template': {
    apiVersion: 'template.openshift.io/v1',
    kind: 'Template',
    metadata: {
      name: 'rhobs-test-job',
    },
    objects: [
      j.job,
    ],
    parameters: [
      { name: 'JOB_NAMESPACES', value: 'observatorium,observatorium-metrics,observatorium-logs,minio,dex,telemeter' },
      { name: 'JOB_NAME', value: 'rhobs-test-job' },
      { name: 'JOB_INTERVAL', value: '10s' },
      { name: 'JOB_TIMEOUT', value: '1m' },
      { name: 'JOB_IMAGE', value: 'quay.io/app-sre/rhobs-test' },
      { name: 'JOB_IMAGE_TAG', value: 'latest' },
      { name: 'SERVICE_ACCOUNT_NAME', value: 'rhobs-test-job' },
    ],
  },
  'test-deployment-template': {
    apiVersion: 'template.openshift.io/v1',
    kind: 'Template',
    metadata: {
      name: 'test-deployment',
    },
    objects: [
      d.namespace {
        metadata+: { name: '${PROM_NAMESPACE}' },
      },
      d.configMap {
        metadata+: { name: '${PROM_CONFIG_MAP}', namespace: '${PROM_NAMESPACE}' },
      },
      d.deployment {},
      d.service {
        metadata+: { name: '${PROM_SERVICE_NAME}' },
      },
    ],
    parameters: [
      { name: 'PROM_NAMESPACE', value: 'prometheus-example' },
      { name: 'PROM_CONFIG_MAP', value: 'prometheus-example-app-config' },
      { name: 'PROM_IMAGE', value: 'prom/prometheus' },
      { name: 'PROM_REPLICAS', value: '4' },
      { name: 'PROM_SERVICE_NAME', value: 'prometheus-example' },
    ],
  },
  'test-deployment-faulty-template': {
    apiVersion: 'template.openshift.io/v1',
    kind: 'Template',
    metadata: {
      name: 'test-deployment',
    },
    objects: [
      d.namespace {
        metadata+: { name: '${PROM_NAMESPACE}' },
      },
      d.configMap {
        metadata+: { name: '${PROM_CONFIG_MAP}', namespace: '${PROM_NAMESPACE}' },
      },
      deployment {},
      d.service {
        metadata+: { name: '${PROM_SERVICE_NAME}' },
      },
    ],
    parameters: [
      { name: 'PROM_NAMESPACE', value: 'prometheus-example' },
      { name: 'PROM_CONFIG_MAP', value: 'prometheus-example-app-config' },
      { name: 'PROM_IMAGE', value: 'prom/prometheus' },
      { name: 'PROM_REPLICAS', value: '4' },
      { name: 'PROM_SERVICE_NAME', value: 'prometheus-example' },
    ],
  },
}
