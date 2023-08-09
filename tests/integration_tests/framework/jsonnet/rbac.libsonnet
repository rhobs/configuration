local defaults = {
  roleName: error 'must provide role name',
  namespace: error 'must provide namespace',
  roleBindingName: error 'must provide rolebinding name',
  serviceAccountName: error 'must provide service account name',

  labels:: {
    'app.kubernetes.io/component': 'observability',
  },

};
function(params) {
  local rbac = self,
  config:: defaults + params,
  serviceAccount: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: rbac.config.serviceAccountName,
      namespace: rbac.config.namespace,
      labels: rbac.config.labels,
    },
  },
  role: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'Role',
    metadata: {
      labels: rbac.config.labels,
      name: rbac.config.roleName,
      namespace: rbac.config.namespace,
    },
    rules: [
      {
        apiGroups: ['', 'apps'],
        resources: ['deployments', 'statefulsets', 'services', 'endpoints', 'pods', 'namespaces', 'pods/log'],
        verbs: ['get', 'list', 'watch'],
      },
    ],
  },
  roleBinding: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'RoleBinding',
    metadata: {
      labels: rbac.config.labels,
      name: rbac.config.roleBindingName,
      namespace: rbac.config.namespace,
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Role',
      name: rbac.role.metadata.name,
    },
    subjects: [
      {
        kind: 'ServiceAccount',
        name: rbac.serviceAccount.metadata.name,
        namespace: rbac.serviceAccount.metadata.namespace,
      },
    ],
  },
}
