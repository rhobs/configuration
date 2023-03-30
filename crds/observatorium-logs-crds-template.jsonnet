local ar = (import 'loki.grafana.com_alertingrules.libsonnet');
local rr = (import 'loki.grafana.com_recordingrules.libsonnet');

{
  local clusterRole = {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: {
      name: 'observatorium-logs-edit',
      labels: {
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

  local withServedV1Beta1 = function(crd) crd {
    spec+: {
      conversion:: {},
      versions: [
        v + (if v.name == 'v1beta1' then {
               served: true,
             } else {})
        for v in super.versions
      ],
    },
  },

  apiVersion: 'template.openshift.io/v1',
  kind: 'Template',
  metadata: {
    name: 'observatorium-logs-crds',
  },
  objects: [
    withServedV1Beta1(ar),
    withServedV1Beta1(rr),
    clusterRole,
  ],
}
