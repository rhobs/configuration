local utils = import '../utils.jsonnet';

function(instanceName, environment, dashboardName) {
  // Validate our inputs.
  assert std.member(['telemeter', 'mst'], instanceName),
  assert std.member(['production', 'stage', 'rhobsp02ue1'], environment),

  local instanceConfig = {
    telemeter: {
      production: {
        datasource: 'telemeter-prod-01-prometheus',
        upNamespace: 'observatorium-production',
        apiJob: 'observatorium-observatorium-api',
        metricsNamespace: 'observatorium-metrics-production',
      },
      stage: {
        datasource: 'app-sre-stage-01-prometheus',
        upNamespace: 'observatorium-stage',
        apiJob: 'observatorium-observatorium-api',
        metricsNamespace: 'observatorium-metrics-stage',
      },
    },
    mst: {
      production: {
        datasource: 'telemeter-prod-01-prometheus',
        upNamespace: 'observatorium-mst-production',
        apiJob: 'observatorium-observatorium-mst-api',
        metricsNamespace: 'observatorium-metrics-production',
      },
      rhobsp02ue1: {
        datasource: 'rhobsp02ue1-prometheus',
        upNamespace: 'observatorium-mst-production',
        apiJob: 'observatorium-observatorium-mst-api',
        metricsNamespace: 'observatorium-metrics-production',
      },
      stage: {
        datasource: 'app-sre-stage-01-prometheus',
        upNamespace: 'observatorium-mst-stage',
        apiJob: 'observatorium-observatorium-mst-api',
        metricsNamespace: 'observatorium-metrics-stage',
      },
    },
  },
  local instance = instanceConfig[instanceName][environment],
  // This is part of a dirty hack because I can't figure out how to do an auto-incrementing counter in Jsonnet.
  // Each grafana dashboard that requests data needs a unique ID, we use the panels per row + a unqiue index per panel
  // to generate a continuous stream of integers from 0...
  local panelsPerRow = 2,
  local titlePanel = [
    {
      gridPos: {
        h: 3,
        w: 15,
      },
      options: {
        content: 'This dashboard displays the SLOs as defined in the [RHOBS Service Level Objectives](https://docs.google.com/document/d/1wJjcpgg-r8rlnOtRiqWGv0zwr1MB6WwkQED1XDWXVQs/edit) document.',
        mode: 'markdown',
      },
      pluginVersion: '8.2.1',
      title: 'Description',
      transparent: true,
      type: 'text',
    },
  ],
  local titleRow(title) = [
    {
      collapsed: false,
      panels: [],
      title: title,
      type: 'row',
    },
  ],
  local availabilityRow(specifiction, target, errorQuery, totalQuery, rowIndex) = [
    {
      gridPos: {
        h: 5,
        w: 5,
        x: 0,
      },
      options: {
        content: '<center style="font-size: 25px;">' + specifiction + '</center>',
        mode: 'markdown',
      },
      pluginVersion: '8.2.1',
      title: 'SLO',
      type: 'text',
    },
    {
      datasource: instance.datasource,
      fieldConfig: {
        defaults: {
          color: {
            mode: 'thresholds',
          },
          decimals: 2,
          mappings: [],
          max: 1,
          min: 0,
          thresholds: {
            mode: 'percentage',
            steps: [
              {
                color: 'red',
                value: null,
              },
              {
                color: 'orange',
                value: 95,
              },
              {
                color: 'green',
                value: 97.5,
              },
            ],
          },
          unit: 'percentunit',
        },
        overrides: [],
      },
      gridPos: {
        h: 5,
        w: 5,
        x: 5,
      },
      options: {
        colorMode: 'value',
        graphMode: 'area',
        justifyMode: 'auto',
        orientation: 'auto',
        reduceOptions: {
          calcs: [
            'lastNotNull',
          ],
          fields: '',
          values: false,
        },
        text: {},
        textMode: 'auto',
      },
      pluginVersion: '8.2.1',
      targets: [
        {
          exemplar: true,
          expr: |||
            1-
            (%(errorCase)s or vector(0))
            /
            %(totalCase)s
          ||| % { errorCase: errorQuery, totalCase: totalQuery },
          interval: '',
          legendFormat: '',
          instant: true,
          range: false,
          refId: 'A',
        },
      ],
      title: 'Availability (7d)',
      type: 'stat',
      id: (rowIndex * panelsPerRow),
    },
    {
      datasource: instance.datasource,
      fieldConfig: {
        defaults: {
          color: {
            mode: 'thresholds',
          },
          decimals: 2,
          mappings: [],
          max: 1,
          min: 0,
          thresholds: {
            mode: 'percentage',
            steps: [
              {
                color: 'red',
                value: null,
              },
              {
                color: 'orange',
                value: 33,
              },
              {
                color: 'green',
                value: 66,
              },
            ],
          },
          unit: 'percentunit',
        },
        overrides: [],
      },
      gridPos: {
        h: 5,
        w: 5,
        x: 10,
      },
      options: {
        colorMode: 'value',
        graphMode: 'area',
        justifyMode: 'auto',
        orientation: 'auto',
        reduceOptions: {
          calcs: [
            'lastNotNull',
          ],
          fields: '',
          values: false,
        },
        text: {},
        textMode: 'auto',
      },
      pluginVersion: '8.2.1',
      targets: [
        {
          exemplar: true,
          expr: |||
            clamp_min(
            ( 1 -
                (
                    (%(errorCase)s or vector(0))
                    /
                    %(totalCase)s
                ) - %(target)s
            )
            /
            (1 - %(target)s), 0)
          ||| % { errorCase: errorQuery, totalCase: totalQuery, target: target },
          hide: false,
          interval: '',
          legendFormat: '',
          refId: 'B',
        },
      ],
      title: 'Error Budget (7d)',
      type: 'stat',
      id: (rowIndex * panelsPerRow) + 1,
    },
  ],
  local latencyRow(specification, targetPercentile, targetSeconds, targetQuery, bucketQuery, totalQuery, rowIndex) = [
    {
      gridPos: {
        h: 5,
        w: 5,
        x: 0,
      },
      options: {
        content: '<center style="font-size: 25px;">' + specification + '</center>',
        mode: 'markdown',
      },
      pluginVersion: '8.2.1',
      title: 'SLO',
      type: 'text',
    },
    {
      datasource: instance.datasource,
      fieldConfig: {
        defaults: {
          color: {
            mode: 'thresholds',
          },
          mappings: [],
          max: targetSeconds,
          min: 0,
          thresholds: {
            mode: 'percentage',
            steps: [
              {
                color: 'green',
                value: null,
              },
              {
                color: 'orange',
                value: 80,
              },
              {
                color: 'red',
                value: 100,
              },
            ],
          },
          unit: 's',
        },
        overrides: [],
      },
      gridPos: {
        h: 5,
        w: 5,
        x: 5,
      },
      options: {
        colorMode: 'value',
        graphMode: 'area',
        justifyMode: 'auto',
        orientation: 'auto',
        reduceOptions: {
          calcs: [
            'lastNotNull',
          ],
          fields: '',
          values: false,
        },
        text: {},
        textMode: 'auto',
      },
      pluginVersion: '8.2.1',
      targets: [
        {
          exemplar: true,
          expr: |||
            histogram_quantile( %(targetPercentile)s, sum by (le) ( %(bucketQuery)s ))
          ||| % { targetPercentile: targetPercentile, bucketQuery: bucketQuery },
          hide: false,
          interval: '',
          legendFormat: '',
          instant: true,
          range: false,
          refId: 'A',
        },
      ],
      title: '90th Percentile Request Latency (7d)',
      type: 'stat',
      id: (rowIndex * panelsPerRow),
    },
    {
      datasource: instance.datasource,
      fieldConfig: {
        defaults: {
          color: {
            mode: 'thresholds',
          },
          decimals: 2,
          mappings: [],
          max: 1,
          min: 0,
          thresholds: {
            mode: 'percentage',
            steps: [
              {
                color: 'red',
                value: null,
              },
              {
                color: 'orange',
                value: 33,
              },
              {
                color: 'green',
                value: 66,
              },
            ],
          },
          unit: 'percentunit',
        },
        overrides: [],
      },
      gridPos: {
        h: 5,
        w: 5,
        x: 10,
      },
      options: {
        colorMode: 'value',
        graphMode: 'area',
        justifyMode: 'auto',
        orientation: 'auto',
        reduceOptions: {
          calcs: [
            'lastNotNull',
          ],
          fields: '',
          values: false,
        },
        text: {},
        textMode: 'auto',
      },
      pluginVersion: '8.2.1',
      targets: [
        {
          exemplar: true,
          expr: |||
            clamp_min(
                (
                    (
                        %(targetQuery)s
                        /
                        %(totalQuery)s
                    ) - %(targetPercentile)s
                )
                /
                (1 - %(targetPercentile)s), 0)
          ||| % { targetQuery: targetQuery, totalQuery: totalQuery, targetPercentile: targetPercentile },
          hide: false,
          interval: '',
          legendFormat: '',
          refId: 'B',
        },
      ],
      title: 'Error Budget (7d)',
      type: 'stat',
      id: (rowIndex * panelsPerRow) + 1,
    },
  ],

  local telemeterPanels =
    titleRow('Telemeter Server > Metrics Write > Availability') +
    availabilityRow(
      '99.5% of valid requests return successfully',
      0.995,
      'sum(rate(haproxy_server_http_responses_total{route=~"telemeter-server-upload|telemeter-server-metrics-v1-receive",code="5xx"}[7d]))',
      'sum(rate(haproxy_server_http_responses_total{route=~"telemeter-server-upload|telemeter-server-metrics-v1-receive",code!="4xx"}[7d]))',
      0
    ) +
    titleRow('Telemeter Server > Metrics Write > Latency') +
    latencyRow(
      '90% of valid requests return < 5s',
      0.9,
      5,
      'sum(rate(http_request_duration_seconds_bucket{job="telemeter-server",handler=~"upload|receive",code!~"4..",le="5"}[7d]))',
      'rate(http_request_duration_seconds_bucket{job="telemeter-server",code!~"4..",handler=~"upload|receive"}[7d])',
      'sum(rate(http_request_duration_seconds_count{job="telemeter-server",code!~"4..",handler=~"upload|receive"}[7d]))',
      1
    ),
  local apiPanels =
    titleRow('API > Metrics Write > Availability') +
    availabilityRow(
      '99.5% of valid requests return successfully',
      0.995,
      'sum(rate(http_requests_total{job="%s",group="metricsv1",handler=~"receive",code=~"5.+"}[7d]))' % instance.apiJob,
      'sum(rate(http_requests_total{job="%s",group="metricsv1",handler=~"receive",code!~"4.+"}[7d]))' % instance.apiJob,
      2
    ) +
    titleRow('API > Metrics Write > Latency') +
    latencyRow(
      '90% of valid requests return < 5s',
      0.9,
      5,
      'sum(rate(http_request_duration_seconds_bucket{job="%s",code!~"4..",group="metricsv1",handler=~"receive",le="5"}[7d]))' % instance.apiJob,
      'rate(http_request_duration_seconds_bucket{job="%s",code!~"4..",group="metricsv1",handler=~"receive"}[7d])' % instance.apiJob,
      'sum(rate(http_request_duration_seconds_count{job="%s",code!~"4..",group="metricsv1",handler=~"receive"}[7d]))' % instance.apiJob,
      3
    ) +
    titleRow('API > Metrics Read > Ad Hoc > Availability') +
    availabilityRow(
      '99.5% of valid /query requests return successfully',
      0.995,
      'sum(rate(http_requests_total{job="%s",group="metricsv1",handler="query",code=~"5.+"}[7d]))' % instance.apiJob,
      'sum(rate(http_requests_total{job="%s",group="metricsv1",handler="query",code!~"4.+"}[7d]))' % instance.apiJob,
      4
    ) +
    availabilityRow(
      '99.5% of valid /query_range requests return successfully',
      0.995,
      'sum(rate(http_requests_total{job="%s",group="metricsv1",handler=~"query_range",code=~"5.+"}[7d]))' % instance.apiJob,
      'sum(rate(http_requests_total{job="%s",group="metricsv1",handler=~"query_range",code!~"4.+"}[7d]))' % instance.apiJob,
      5
    ) +
    titleRow('API > Metrics Read > Ad Hoc > Latency') +
    latencyRow(
      '90% of valid requests that process 1M samples return < 10s',
      0.9,
      10,
      'sum(rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="query-path-sli-1M-samples",le="10"}[7d]))' % instance.upNamespace,
      'rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="query-path-sli-1M-samples"}[1d])' % instance.upNamespace,
      'sum(rate(up_custom_query_duration_seconds_count{namespace="%s",query="query-path-sli-1M-samples"}[7d]))' % instance.upNamespace,
      6
    ) +
    latencyRow(
      '90% of valid requests that process 10M samples return < 30s',
      0.9,
      30,
      'sum(rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="query-path-sli-10M-samples",le="30"}[7d]))' % instance.upNamespace,
      'rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="query-path-sli-10M-samples"}[1d])' % instance.upNamespace,
      'sum(rate(up_custom_query_duration_seconds_count{namespace="%s",query="query-path-sli-10M-samples"}[7d]))' % instance.upNamespace,
      7
    ) +
    latencyRow(
      '90% of valid requests that process 100M samples return < 120s',
      0.9,
      120,
      'sum(rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="query-path-sli-100M-samples",le="120"}[7d]))' % instance.upNamespace,
      'rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="query-path-sli-100M-samples"}[1d])' % instance.upNamespace,
      'sum(rate(up_custom_query_duration_seconds_count{namespace="%s",query="query-path-sli-100M-samples"}[7d]))' % instance.upNamespace,
      8
    ) +
    titleRow('API > Metrics Read > Rule > Availability') +
    availabilityRow(
      '99.5% of valid /query requests return successfully',
      0.995,
      'sum(rate(http_requests_total{job="observatorium-ruler-query",handler="query",code=~"5.+"}[7d]))',
      'sum(rate(http_requests_total{job="observatorium-ruler-query",handler="query",code!~"4.+"}[7d]))',
      4
    ) +
    titleRow('API > Metrics Read > Rule > Latency') +
    latencyRow(
      '90% of valid requests that process 1M samples return < 10s',
      0.9,
      10,
      'sum(rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="rule-query-path-sli-1M-samples",le="10"}[7d]))' % instance.upNamespace,
      'rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="rule-query-path-sli-1M-samples"}[1d])' % instance.upNamespace,
      'sum(rate(up_custom_query_duration_seconds_count{namespace="%s",query="rule-query-path-sli-1M-samples"}[7d]))' % instance.upNamespace,
      6
    ) +
    latencyRow(
      '90% of valid requests that process 10M samples return < 30s',
      0.9,
      30,
      'sum(rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="rule-query-path-sli-10M-samples",le="30"}[7d]))' % instance.upNamespace,
      'rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="rule-query-path-sli-10M-samples"}[1d])' % instance.upNamespace,
      'sum(rate(up_custom_query_duration_seconds_count{namespace="%s",query="rule-query-path-sli-10M-samples"}[7d]))' % instance.upNamespace,
      7
    ) +
    latencyRow(
      '90% of valid requests that process 100M samples return < 120s',
      0.9,
      120,
      'sum(rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="rule-query-path-sli-100M-samples",le="120"}[7d]))' % instance.upNamespace,
      'rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="rule-query-path-sli-100M-samples"}[1d])' % instance.upNamespace,
      'sum(rate(up_custom_query_duration_seconds_count{namespace="%s",query="rule-query-path-sli-100M-samples"}[7d]))' % instance.upNamespace,
      8
    ) +
    titleRow('API > Rules Write (/rules/raw) > Availability') +
    availabilityRow(
      '99% of valid write requests return successfully',
      0.99,
      'sum(rate(http_requests_total{job="%s",group="metricsv1",handler=~"rules-raw",code=~"5.+",method=~"PUT"}[7d]))' % instance.apiJob,
      'sum(rate(http_requests_total{job="%s",group="metricsv1",handler=~"rules-raw",code!~"4.+",method=~"PUT"}[7d]))' % instance.apiJob,
      9
    ) +
    titleRow('API > Rules Sync > Availability') +
    availabilityRow(
      '99% of rules are successfully synced to Thanos Ruler',
      0.99,
      'sum(rate(client_api_requests_total{client="reload",container="thanos-rule-syncer",namespace="%s",code=~"5.+"}[7d]))' % utils.instanceNamespace(instanceName, instance.metricsNamespace, instance.upNamespace),
      'sum(rate(client_api_requests_total{client="reload",container="thanos-rule-syncer",namespace="%s",code!~"4.+"}[7d]))' % utils.instanceNamespace(instanceName, instance.metricsNamespace, instance.upNamespace),
      10
    ) +
    titleRow('API > Rules Read (/rules) > Availability') +
    availabilityRow(
      '90% of valid requests return successfully',
      0.9,
      'sum(rate(http_requests_total{job="%s",group="metricsv1",handler=~"rules",code=~"5.+"}[7d]))' % instance.apiJob,
      'sum(rate(http_requests_total{job="%s",group="metricsv1",handler=~"rules",code!~"4.+"}[7d]))' % instance.apiJob,
      11
    ) +
    titleRow('API > Rules Read (/rules/raw) > Availability') +
    availabilityRow(
      '90% of valid requests return successfully',
      0.9,
      'sum(rate(http_requests_total{job="%s",group="metricsv1",handler=~"rules-raw",code=~"5.+"}[7d]))' % instance.apiJob,
      'sum(rate(http_requests_total{job="%s",group="metricsv1",handler=~"rules-raw",code!~"4.+"}[7d]))' % instance.apiJob,
      12
    ) +
    titleRow('API > Alerting > Availability') +
    availabilityRow(
      '99% of alerts are successfully delivered to Alertmanager',
      0.99,
      'sum(rate(thanos_alert_sender_alerts_dropped_total{container="thanos-rule",namespace="%s"}[7d]))' % utils.instanceNamespace(instanceName, instance.metricsNamespace, instance.upNamespace),
      'sum(rate(thanos_alert_sender_alerts_sent_total{container="thanos-rule",namespace="%s"}[7d]))' % utils.instanceNamespace(instanceName, instance.metricsNamespace, instance.upNamespace),
      13
    ) +
    availabilityRow(
      '99% of alerts are successfully delivered to upstream targets',
      0.99,
      'sum(rate(alertmanager_notifications_failed_total{service="observatorium-alertmanager",namespace="%s"}[7d]))' % utils.instanceNamespace(instanceName, instance.metricsNamespace, instance.upNamespace),
      'sum(rate(alertmanager_notifications_total{service="observatorium-alertmanager",namespace="%s"}[7d]))' % utils.instanceNamespace(instanceName, instance.metricsNamespace, instance.upNamespace),
      14
    ),
  local apiLogsPanels =
    titleRow('API > Logs Write > Availability') +
    availabilityRow(
      '99% of valid requests return successfully',
      0.99,
      'sum(rate(http_requests_total{job="%s",group="logsv1",handler=~"push",code=~"5.+"}[7d]))' % instance.apiJob,
      'sum(rate(http_requests_total{job="%s",group="logsv1",handler=~"push",code!~"4.+"}[7d]))' % instance.apiJob,
      2
    ) +
    titleRow('API > Logs Write > Latency') +
    latencyRow(
      '90% of valid requests return < 5s',
      0.9,
      5,
      'sum(rate(http_request_duration_seconds_bucket{job="%s",code!~"4..",group="logsv1",handler=~"push",le="5"}[7d]))' % instance.apiJob,
      'rate(http_request_duration_seconds_bucket{job="%s",code!~"4..",group="logsv1",handler=~"push"}[7d])' % instance.apiJob,
      'sum(rate(http_request_duration_seconds_count{job="%s",code!~"4..",group="logsv1",handler=~"push"}[7d]))' % instance.apiJob,
      3
    ) +
    titleRow('API > Logs Read > Availability') +
    availabilityRow(
      '99% of valid /query requests return successfully',
      0.99,
      'sum(rate(http_requests_total{job="%s",group="logsv1",handler="query",code=~"5.+"}[7d]))' % instance.apiJob,
      'sum(rate(http_requests_total{job="%s",group="logsv1",handler="query",code!~"4.+"}[7d]))' % instance.apiJob,
      4
    ) +
    availabilityRow(
      '99% of valid /query_range requests return successfully',
      0.99,
      'sum(rate(http_requests_total{job="%s",group="logsv1",handler=~"query_range",code=~"5.+"}[7d]))' % instance.apiJob,
      'sum(rate(http_requests_total{job="%s",group="logsv1",handler=~"query_range",code!~"4.+"}[7d]))' % instance.apiJob,
      5
    ),

  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    name: 'grafana-dashboard-slo-' + instanceName + '-' + environment,
  },
  data: {
    'slo.json': std.manifestJson({
      // Only add telemeter-server panels if we're generating SLOs for the telemeter instance.
      // Only add API Logs panels if we're generating SLOs for the mst instance.
      panels: titlePanel +
              (if instanceName == 'telemeter' then telemeterPanels else []) +
              apiPanels +
              (if instanceName == 'mst' then apiLogsPanels else []),
      refresh: false,
      schemaVersion: 31,
      style: 'dark',
      tags: [],
      templating: {
        list: [],
      },
      time: {
        from: 'now-6h',
        to: 'now',
      },
      timepicker: {},
      timezone: '',
      title: dashboardName,
      uid: std.md5(dashboardName),
      version: 2,
    }),
  },
}
