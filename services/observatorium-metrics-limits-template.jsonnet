local config = {
  limits: {
    write: {
      global: {
        max_concurrency: '${MAX_CONCURRENCY}',
        meta_monitoring_url: '${META_MONITORING_URL}',
        meta_monitoring_limit_query: '${QUERY}',
      },
      default: {
        request: {
          size_bytes_limit: '${SIZE_BYTE_LIMIT}',  // unlimited
          series_limit: '${SERIES_LIMIT}',
          samples_limit: '${SAMPLES_LIMIT}',
        },
        head_series_limit: '${HEAD_SERIES_LIMIT}',
      },
      tenants: {
        '${TENANT_ID}': {
          head_series_limit: '${TENANT_HEAD_SERIES_LIMIT}',
        },
      },
    },
  },
};
local removeDoubleQuotes(str, fromArray) = std.foldl(
  function(retStr, from) if from == '${QUERY}' then std.strReplace(retStr, '"' + from + '"', "'" + from + "'") else std.strReplace(retStr, '"' + from + '"', from),
  fromArray,
  str
);
local vars = ['${MAX_CONCURRENCY}', '${SIZE_BYTE_LIMIT}', '${SERIES_LIMIT}', '${SAMPLES_LIMIT}', '${HEAD_SERIES_LIMIT}', '${TENANT_HEAD_SERIES_LIMIT}', '${TENANT_ID}', '${QUERY}'];
{
  apiVersion: 'template.openshift.io/v1',
  kind: 'Template',
  metadata: {
    name: '${CONFIGMAP_NAME}',
    annotations: {
      'qontract.recycle': 'true',
    },
  },
  objects: [
    {
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata+: {
        name: '${CONFIGMAP_NAME}',
        annotations: {
          'qontract.recycle': 'true',
        },
      },
      data: {
        'receive.limits.yaml': removeDoubleQuotes(std.manifestYamlDoc(config.limits), vars),
      },
    },
  ],
  parameters: [
    { name: 'CONFIGMAP_NAME' },
    { name: 'MAX_CONCURRENCY', value: '0' },
    { name: 'META_MONITORING_URL', value: 'http://prometheus-app-sre.openshift-customer-monitoring.svc.cluster.local:9090' },
    { name: 'QUERY', value: 'sum(prometheus_tsdb_head_series{namespace="observatorium-mst-stage"}) by (tenant)' },
    { name: 'SIZE_BYTE_LIMIT', value: '0' },
    { name: 'SERIES_LIMIT', value: '5000' },
    { name: 'SAMPLES_LIMIT', value: '5000' },
    { name: 'HEAD_SERIES_LIMIT', value: '100000' },
    { name: 'TENANT_ID', value: '1b9b6e43-9128-4bbf-bfff-3c120bbe6f11' },
    { name: 'TENANT_HEAD_SERIES_LIMIT', value: '10000000' },
  ],
}
