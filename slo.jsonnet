local slo = import 'slo-libsonnet/slo.libsonnet';

local telemeterSLOs = {
  telemeterRead:: {
    errors: {
      metric: 'haproxy_server_http_responses_total',
      selectors: ['route="observatorium-thanos-querier-cache"'],
      errorBudget: 1.0 - 0.90,
    },
  },
  telemeterWrite:: {
    errors: {
      metric: 'haproxy_server_http_responses_total',
      selectors: ['route="telemeter-server"'],
      errorBudget: 1.0 - 0.90,
    },
  },
};

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
        name: 'observatorium-thanos-querier.slo.rules',
        rules:
          slo.errorburn(telemeterSLOs.telemeterRead.errors).recordingrules +
          slo.errorbudget(telemeterSLOs.telemeterRead.errors).recordingrules,
      },
      {
        name: 'observatorium-telemeter.slo.rules',
        rules:
          slo.errorburn(telemeterSLOs.telemeterWrite.errors).recordingrules +
          slo.errorbudget(telemeterSLOs.telemeterWrite.errors).recordingrules,
      },
    ],
  },
}
