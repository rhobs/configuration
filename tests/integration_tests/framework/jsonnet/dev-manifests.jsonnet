local job = import 'job.libsonnet';
local rbac = import 'rbac.libsonnet';
local testdeployment = import 'test-deployment.libsonnet';

local rbacConfig = {
  roleName: 'rhobs-test',
  namespace: 'prometheus-example',
  roleBindingName: 'rhobs-test',
  serviceAccountName: 'rhobs-test-job',
};
local jobConfig = {
  name: 'rhobs-test-job',
  namespaces: 'prometheus-example',
  interval: '5s',
  timeout: '60s',
  image: 'localhost:5001/rhobs-test',
  imageTag: 'latest',
  serviceAccountName: rbacConfig.serviceAccountName,
};
local testConfig = {
  namespace: 'prometheus-example',
  configMapName: 'prometheus-example-app-config',
  replicas: 4,
  image: 'prom/prometheus',
  serviceName: 'prometheus-example',
};
local r = rbac(rbacConfig);
local roleBinding = r.roleBinding {
  subjects: [{
    kind: 'ServiceAccount',
    name: rbacConfig.serviceAccountName,
    namespace: 'default',
  }],
};
local j = job(jobConfig);
local d = testdeployment(testConfig);
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
            image: testConfig.image,
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
        volumes: [
          {
            name: 'config',
            configMap: {
              name: testConfig.configMapName,
            },
          },
        ],
      },
    },
  },
};

{
  'test-rbac': {
    apiVersion: 'v1',
    kind: 'List',
    items: [
      r.serviceAccount {
        metadata+: { namespace: 'default' },
      },
      r.role {
        metadata+: { namespace: 'default' },
      },
      roleBinding {
        metadata+: { namespace: 'default' },
      },
      r.role {},
      roleBinding {},
    ],
  },
  'test-job': {
    apiVersion: 'v1',
    kind: 'List',
    items: [
      j.job {},
    ],
  },
  'test-deployment': {
    apiVersion: 'v1',
    kind: 'List',
    items: [
      d.namespace {},
      d.configMap {},
      d.deployment {},
      d.service {
        metadata+: { name: testConfig.serviceName },
      },
    ],
  },
  'test-deployment-faulty': {
    apiVersion: 'v1',
    kind: 'List',
    items: [
      d.namespace {},
      d.configMap {},
      deployment {},
      d.service {
        metadata+: { name: testConfig.serviceName },
      },
    ],
  },

}
// { [name]: r[name] for name in std.objectFields(r) if r[name] != null }+
// { [name]: j[name] for name in std.objectFields(j) if j[name] != null }+
// {for name in std.}
