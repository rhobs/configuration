local observatoriumSLOs = import 'observatorium/slos.libsonnet';
local slo = import 'slo-libsonnet/slo.libsonnet';

{
  apiVersion: 'monitoring.coreos.com/v1',
  kind: 'PrometheusRule',
  metadata: {
    name: 'observatorium-slos',
    labels: {
      prometheus: 'app-sre',
      role: 'alert-rules',
    },
  },
  spec: {
    groups: [
      {
        local errors = observatoriumSLOs.observatoriumQuery.errors {
          labels+: ['service="telemeter"'],
        },

        name: 'observatorium-thanos-querier.slo.rules',
        rules:
          slo.errorburn(errors).recordingrules +
          slo.errorbudget(errors).recordingrules,
      },
      {
        local errors = observatoriumSLOs.telemeterServerUpload.errors {
          labels+: ['service="telemeter"'],
        },

        name: 'observatorium-telemeter.slo.rules',
        rules:
          slo.errorburn(errors).recordingrules +
          slo.errorbudget(errors).recordingrules,
      },
    ],
  },
}
