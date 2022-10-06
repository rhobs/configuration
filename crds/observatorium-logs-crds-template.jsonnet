{
  apiVersion: 'template.openshift.io/v1',
  kind: 'Template',
  metadata: {
    name: 'observatorium-logs-crds',
  },
  objects: [
    (import 'loki.grafana.com_alertingrules.libsonnet'),
    (import 'loki.grafana.com_recordingrules.libsonnet'),
  ],
}
