{
  local clusterRole = {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: {
      name: 'observatorium-logs-edit',
      annotations: {
        'managed.openshift.io/aggregate-to-dedicated-admins': 'cluster',
      },
    },
    rules: [
      {
        apiGroups: ['loki.grafana.com'],
        resources: ['alertingrules', 'recordingrules'],
        verbs: ['create', 'update', 'delete', 'patch', 'get', 'list', 'watch'],
      },
    ],
  },

  apiVersion: 'template.openshift.io/v1',
  kind: 'Template',
  metadata: {
    name: 'observatorium-logs-crds',
  },
  objects: [
    (import 'loki.grafana.com_alertingrules.libsonnet'),
    (import 'loki.grafana.com_recordingrules.libsonnet'),
    clusterRole,
  ],
}
