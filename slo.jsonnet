local slo = import 'slo-libsonnet/slo.libsonnet';

local telemeterSLOs = [
  {
    name: 'observatorium-telemeter-read.slo.rules',
    errors: {
      metric: 'haproxy_server_http_responses_total',
      selectors: ['route="observatorium-thanos-querier-cache"'],
      errorBudget: 1.0 - 0.90,
    },
  },
  {
    name: 'observatorium-telemeter-upload.slo.rules',
    errors: {
      metric: 'haproxy_server_http_responses_total',
      selectors: ['route="telemeter-server-upload"'],
      errorBudget: 1.0 - 0.90,
    },
  },
  {
    name: 'observatorium-telemeter-authorize.slo.rules',
    errors: {
      metric: 'haproxy_server_http_responses_total',
      selectors: ['route="telemeter-server-authorize"'],
      errorBudget: 1.0 - 0.90,
    },
  },
];

{
  apiVersion: 'monitoring.coreos.com/v1',
  kind: 'PrometheusRule',
  metadata: {
    name: 'telemeter-slos',
    labels: {
      prometheus: 'app-sre',
      role: 'alert-rules',
    },
  },
  spec: {
    groups: [
      {
        name: s.name,
        rules:
          slo.errorburn(s.errors).recordingrules +
          slo.errorbudget(s.errors).recordingrules,
      }
      for s in telemeterSLOs
    ],
  },
}
