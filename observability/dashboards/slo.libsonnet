function(instanceName, environment, dashboardName) {
  // Validate our inputs.
  assert std.member(['telemeter', 'mst'], instanceName),
  assert std.member(['production', 'stage'], environment),

  local instanceConfig = {
    telemeter: {
      production: {
        datasource: 'telemeter-prod-01-prometheus',
        upNamespace: 'observatorium-production',
        apiJob: 'observatorium-observatorium-api',
      },
      stage: {
        datasource: 'app-sre-stage-01-prometheus',
        upNamespace: 'observatorium-stage',
        apiJob: 'observatorium-observatorium-api',
      },
    },
    mst: {
      production: {
        datasource: 'telemeter-prod-01-prometheus',
        upNamespace: 'observatorium-mst-production',
        apiJob: 'observatorium-observatorium-mst-api',
      },
      stage: {
        datasource: 'app-sre-stage-01-prometheus',
        upNamespace: 'observatorium-mst-stage',
        apiJob: 'observatorium-observatorium-mst-api',
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
          refId: 'A',
        },
      ],
      title: 'Availability (28d)',
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
                    %(errorCase)s or vector(0)
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
      title: 'Error Budget (28d)',
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
          refId: 'A',
        },
      ],
      title: '90th Percentile Request Latency (28d)',
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
      title: 'Error Budget (28d)',
      type: 'stat',
      id: (rowIndex * panelsPerRow) + 1,
    },
  ],

  local telemeterPanels =
    titleRow('Telemeter Server > Metrics Write > Availability') +
    availabilityRow(
      '95% of valid requests return successfully',
      0.95,
      'sum(rate(haproxy_server_http_responses_total{route=~"telemeter-server-upload|telemeter-server-metrics-v1-receive",code="5xx"}[28d]))',
      'sum(rate(haproxy_server_http_responses_total{route=~"telemeter-server-upload|telemeter-server-metrics-v1-receive", code!="4xx"}[28d]))',
      0
    ) +
    titleRow('Telemeter Server > Metrics Write > Latency') +
    latencyRow(
      '90% of valid requests return < 5s',
      0.9,
      5,
      'sum(rate(http_request_duration_seconds_bucket{job="telemeter-server",handler=~"upload|receive", code!~"4..", le="5"}[28d]))',
      'rate(http_request_duration_seconds_bucket{job="telemeter-server",code!~"4..",handler=~"upload|receive"}[28d])',
      'sum(rate(http_request_duration_seconds_count{job="telemeter-server",code!~"4..",handler=~"upload|receive"}[28d]))',
      1
    ),
  local apiPanels =
    titleRow('API > Metrics Write > Availability') +
    availabilityRow(
      '95% of valid requests return successfully',
      0.95,
      'sum(rate(http_requests_total{job="%s",handler=~"receive", code=~"5.+"}[28d]))' % instance.apiJob,
      'sum(rate(http_requests_total{job="%s",handler=~"receive", code!~"4.+"}[28d]))' % instance.apiJob,
      2
    ) +
    titleRow('API > Metrics Write > Latency') +
    latencyRow(
      '90% of valid requests return < 5s',
      0.9,
      5,
      'sum(rate(http_request_duration_seconds_bucket{job="%s",code!~"4..",handler=~"receive", le="5"}[28d]))' % instance.apiJob,
      'rate(http_request_duration_seconds_bucket{job="%s",code!~"4..",handler=~"receive"}[28d])' % instance.apiJob,
      'sum(rate(http_request_duration_seconds_count{job="%s",code!~"4..",handler=~"receive"}[28d]))' % instance.apiJob,
      3
    ) +
    titleRow('API > Metrics Read > Availability') +
    availabilityRow(
      '95% of valid /query requests return successfully',
      0.95,
      'sum(rate(http_requests_total{job="%s",handler="query", code=~"5.+"}[28d]))' % instance.apiJob,
      'sum(rate(http_requests_total{job="%s",handler="query", code!~"4.+"}[28d]))' % instance.apiJob,
      4
    ) +
    availabilityRow(
      '95% of valid /query_range requests return successfully',
      0.95,
      'sum(rate(http_requests_total{job="%s",handler=~"query_range", code=~"5.+"}[28d]))' % instance.apiJob,
      'sum(rate(http_requests_total{job="%s",handler=~"query_range", code!~"4.+"}[28d]))' % instance.apiJob,
      5
    ) +
    titleRow('API > Metrics Read > Latency') +
    latencyRow(
      '90% of valid requests that process 1M samples return < 2s',
      0.9,
      2,
      'sum(rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="query-path-sli-1M-samples",le="2.0113571874999994"}[28d]))' % instance.upNamespace,
      'rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="query-path-sli-1M-samples"}[1d])' % instance.upNamespace,
      'sum(rate(up_custom_query_duration_seconds_count{namespace="%s",query="query-path-sli-1M-samples"}[28d]))' % instance.upNamespace,
      6
    ) +
    latencyRow(
      '90% of valid requests that process 10M samples return < 10s',
      0.9,
      10,
      'sum(rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="query-path-sli-10M-samples",le="10.761264004567169"}[28d]))' % instance.upNamespace,
      'rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="query-path-sli-10M-samples"}[1d])' % instance.upNamespace,
      'sum(rate(up_custom_query_duration_seconds_count{namespace="%s",query="query-path-sli-10M-samples"}[28d]))' % instance.upNamespace,
      7
    ) +
    latencyRow(
      '90% of valid requests that process 100M samples return < 20s',
      0.9,
      20,
      'sum(rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="query-path-sli-100M-samples",le="21.6447457021712"}[28d]))' % instance.upNamespace,
      'rate(up_custom_query_duration_seconds_bucket{namespace="%s",query="query-path-sli-100M-samples"}[1d])' % instance.upNamespace,
      'sum(rate(up_custom_query_duration_seconds_count{namespace="%s",query="query-path-sli-100M-samples"}[28d]))' % instance.upNamespace,
      8
    ),

  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    name: 'grafana-dashboard-slo-' + instanceName + '-' + environment,
  },
  data: {
    'slo.json': std.manifestJson({
      // Only add telemeter-server panels if we're generating SLOs for the telemeter instance.
      panels: titlePanel + (if instanceName == 'telemeter' then telemeterPanels else []) + apiPanels,
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
