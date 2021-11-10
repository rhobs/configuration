function(instance, environment) {
  //TODO input validation
  local titleRow = [
    {

      gridPos: {
        h: 3,
        w: 15,
      },
      id: 44,
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
  local availabilityRow(title, specifiction, errorQuery, totalQuery, target) = [
    {
      collapsed: false,
      panels: [],
      title: title,
      type: 'row',
    },
    {
      gridPos: {
        h: 5,
        w: 5,
        x: 0,
      },
      id: 14,
      options: {
        content: '<center style="font-size: 25px;">' + specifiction + '</center>',
        mode: 'markdown',
      },
      pluginVersion: '8.2.1',
      title: 'SLO',
      type: 'text',
    },
    {
      datasource: 'app-sre-stage-01-prometheus',
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
      id: 23,
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
            %(errorCase)s
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
    },
    {
      datasource: 'app-sre-stage-01-prometheus',
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
      id: 34,
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
    },
  ],
  local latencyRow(title, specification, targetPercentile, targetQuery, bucketQuery, totalQuery) = [
    {
      collapsed: false,

      gridPos: {
        h: 1,
        w: 24,
      },
      id: 4,
      panels: [],
      title: title,
      type: 'row',
    },
    {
      gridPos: {
        h: 5,
        w: 5,
        x: 0,
      },
      id: 15,
      options: {
        content: '<center style="font-size: 25px;">' + specification + '</center>',
        mode: 'markdown',
      },
      pluginVersion: '8.2.1',
      title: 'SLO',
      type: 'text',
    },
    {
      datasource: 'app-sre-stage-01-prometheus',
      fieldConfig: {
        defaults: {
          color: {
            mode: 'thresholds',
          },
          mappings: [],
          max: 5,
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
                value: 50,
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
      id: 29,
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
    },
    {
      datasource: 'app-sre-stage-01-prometheus',
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
      id: 35,
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
    },


  ],

  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    name: 'grafana-dashboard-slo' + instance + '-' + environment,
  },
  data: {
    'slo.json': std.manifestJson({
      panels:
        titleRow +
        availabilityRow(
          'Telemeter Server > Metrics Write > Availability',
          '95% of valid requests return successfully',
          'sum(rate(haproxy_server_http_responses_total{route=~"telemeter-server-upload|telemeter-server-metrics-v1-receive",code="5xx"}[28d]))',
          'sum(rate(haproxy_server_http_responses_total{route=~"telemeter-server-upload|telemeter-server-metrics-v1-receive", code!="4xx"}[28d]))',
          0.95
        ) +
        latencyRow(
          'Telemeter Server > Metrics Write > Latency',
          '90% of valid requests return < 5s',
          0.9,
          'sum(rate(http_request_duration_seconds_bucket{job="telemeter-server",handler=~"upload|receive", code!~"4..", le="5"}[28d]))',
          'rate(http_request_duration_seconds_bucket{job="telemeter-server",code!~"4..",handler=~"upload|receive"}[28d])',
          'sum(rate(http_request_duration_seconds_count{job="telemeter-server",code!~"4..",handler=~"upload|receive"}[28d]))'
        ) +
        availabilityRow(
          'API > Metrics Write > Availability',
          '95% of valid requests return successfully',
          'sum(rate(http_requests_total{job="observatorium-observatorium-api",handler=~"receive", code=~"5.+"}[28d]))',
          'sum(rate(http_requests_total{job="observatorium-observatorium-api",handler=~"receive", code!~"4.+"}[28d]))',
          0.95
        ) +
        [
          {
            collapsed: false,

            gridPos: {
              h: 1,
              w: 24,
            },
            id: 6,
            panels: [],
            title: 'API > Metrics Write > Availability',
            type: 'row',
          },
          {

            gridPos: {
              h: 5,
              w: 5,
            },
            id: 16,
            options: {
              content: '<center style="font-size: 25px;">\n\n95% of valid requests return successfully\n\n</center>\n\n',
              mode: 'markdown',
            },
            pluginVersion: '8.2.1',
            title: 'SLO',
            type: 'text',
          },
          {
            datasource: 'app-sre-stage-01-prometheus',
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
            },
            id: 24,
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
                expr: '1 -\n(\n  sum(rate(http_requests_total{job="observatorium-observatorium-api",handler=~"receive", code=~"5.+"}[28d])) or vector(0)\n  /\n  sum(rate(http_requests_total{job="observatorium-observatorium-api",handler=~"receive", code!~"4.+"}[28d]))\n)',
                interval: '',
                legendFormat: '',
                refId: 'A',
              },
            ],
            title: 'Availability (28d)',
            type: 'stat',
          },
          {
            datasource: 'app-sre-stage-01-prometheus',
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
            },
            id: 36,
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
                expr: 'clamp_min(\n( 1 - \n  (\n     sum(rate(http_requests_total{job="observatorium-observatorium-api",handler=~"receive", code=~"5.+"}[28d])) or vector(0)\n    /\n    sum(rate(http_requests_total{job="observatorium-observatorium-api",handler=~"receive", code!~"4.+"}[28d]))\n  ) - 0.95\n)\n/ \n(1 - 0.95), 0)',
                hide: false,
                interval: '',
                legendFormat: '',
                refId: 'B',
              },
            ],
            title: 'Error Budget (28d)',
            type: 'stat',
          },
          {
            collapsed: false,

            gridPos: {
              h: 1,
              w: 24,
            },
            id: 8,
            panels: [],
            title: 'API > Metrics Write > Latency',
            type: 'row',
          },
          {

            gridPos: {
              h: 5,
              w: 5,
            },
            id: 18,
            options: {
              content: '<center style="font-size: 25px;">\n\n90% of valid requests return < 5s\n\n</center>\n\n',
              mode: 'markdown',
            },
            pluginVersion: '8.2.1',
            title: 'SLO',
            type: 'text',
          },
          {
            datasource: 'app-sre-stage-01-prometheus',
            fieldConfig: {
              defaults: {
                color: {
                  mode: 'thresholds',
                },
                mappings: [],
                max: 5,
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
                      value: 50,
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
            },
            id: 30,
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
                expr: 'histogram_quantile(0.9, sum by (le) (rate(http_request_duration_seconds_bucket{job="observatorium-observatorium-api",code!~"4..",handler=~"receive"}[28d])))',
                hide: false,
                interval: '',
                legendFormat: '',
                refId: 'A',
              },
            ],
            title: '90th Percentile Request Latency (28d)',
            type: 'stat',
          },
          {
            datasource: 'app-sre-stage-01-prometheus',
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
            },
            id: 37,
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
                expr: 'clamp_min(\n(\n  (\n    sum(rate(http_request_duration_seconds_bucket{job="observatorium-observatorium-api",code!~"4..",handler=~"receive", le="5"}[28d]))\n/\nsum(rate(http_request_duration_seconds_count{job="observatorium-observatorium-api",code!~"4..",handler=~"receive"}[28d]))\n  ) - 0.9\n)\n/ \n(1 - 0.9), 0)',
                hide: false,
                interval: '',
                legendFormat: '',
                refId: 'B',
              },
              {
                exemplar: true,
                expr: 'http_request_duration_seconds_bucket{job="observatorium-observatorium-api",code!~"4..",handler=~"receive"',
                hide: true,
                interval: '',
                legendFormat: '',
                refId: 'A',
              },
            ],
            title: 'Error Budget (28d)',
            type: 'stat',
          },
          {
            collapsed: false,

            gridPos: {
              h: 1,
              w: 24,
            },
            id: 10,
            panels: [],
            title: 'API > Metrics Read > Availability',
            type: 'row',
          },
          {

            gridPos: {
              h: 5,
              w: 5,
            },
            id: 17,
            options: {
              content: '<center style="font-size: 25px;">\n\n95% of valid /query requests return successfully\n\n</center>\n\n',
              mode: 'markdown',
            },
            pluginVersion: '8.2.1',
            title: 'SLO',
            type: 'text',
          },
          {
            datasource: 'app-sre-stage-01-prometheus',
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
                      color: '#EAB839',
                      value: 95,
                    },
                    {
                      color: 'green',
                      value: 96,
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
            },
            id: 26,
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
                expr: '1 -\n(\n  sum(rate(http_requests_total{job="observatorium-observatorium-api",handler="query", code=~"5.+"}[28d]))\n  /\n  sum(rate(http_requests_total{job="observatorium-observatorium-api",handler="query", code!~"4.+"}[28d]))\n)',
                interval: '',
                legendFormat: '',
                refId: 'A',
              },
            ],
            title: 'Availability (28d)',
            type: 'stat',
          },
          {
            datasource: 'app-sre-stage-01-prometheus',
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
            },
            id: 38,
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
                expr: 'clamp_min(\n(\n  (\n    1 -\n     sum(rate(http_requests_total{job="observatorium-observatorium-api",handler="query", code=~"5.+"}[28d]))\n    /\n    sum(rate(http_requests_total{job="observatorium-observatorium-api",handler="query", code!~"4.+"}[28d]))\n  ) - 0.95\n)\n/ \n(1 - 0.95), 0)',
                hide: false,
                interval: '',
                legendFormat: '',
                refId: 'B',
              },
            ],
            title: 'Error Budget (28d)',
            type: 'stat',
          },
          {

            gridPos: {
              h: 5,
              w: 5,
            },
            id: 25,
            options: {
              content: '<center style="font-size: 25px;">\n\n95% of valid /query_range requests return successfully\n\n</center>\n\n',
              mode: 'markdown',
            },
            pluginVersion: '8.2.1',
            title: 'SLO',
            type: 'text',
          },
          {
            datasource: 'app-sre-stage-01-prometheus',
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
                      color: '#EAB839',
                      value: 95,
                    },
                    {
                      color: 'green',
                      value: 96,
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
            },
            id: 27,
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
                expr: '1 -\n(\n  sum(rate(http_requests_total{job="observatorium-observatorium-api",handler=~"query_range", code=~"5.+"}[28d]))\n  /\n  sum(rate(http_requests_total{job="observatorium-observatorium-api",handler=~"query_range", code!~"4.+"}[28d]))\n)',
                interval: '',
                legendFormat: '',
                refId: 'A',
              },
            ],
            title: 'Availability (28d)',
            type: 'stat',
          },
          {
            datasource: 'app-sre-stage-01-prometheus',
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
            },
            id: 39,
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
                expr: 'clamp_min(\n(\n  (\n    1 -\n     sum(rate(http_requests_total{job="observatorium-observatorium-api",handler=~"query_range", code=~"5.+"}[28d]))\n    /\n    sum(rate(http_requests_total{job="observatorium-observatorium-api",handler=~"query_range", code!~"4.+"}[28d]))\n  ) - 0.95\n)\n/ \n(1 - 0.95), 0)',
                hide: false,
                interval: '',
                legendFormat: '',
                refId: 'B',
              },
            ],
            title: 'Error Budget (28d)',
            type: 'stat',
          },
          {
            collapsed: false,

            gridPos: {
              h: 1,
              w: 24,
            },
            id: 12,
            panels: [],
            title: 'API > Metrics Read > Latency',
            type: 'row',
          },
          {

            gridPos: {
              h: 5,
              w: 5,
            },
            id: 19,
            options: {
              content: '<center style="font-size: 25px;">\n\n90% of valid requests that process 1M samples return < 2s\n\n</center>\n\n',
              mode: 'markdown',
            },
            pluginVersion: '8.2.1',
            title: 'SLO',
            type: 'text',
          },
          {
            datasource: 'app-sre-stage-01-prometheus',
            fieldConfig: {
              defaults: {
                color: {
                  mode: 'thresholds',
                },
                mappings: [],
                max: 1,
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
                      value: 50,
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
            },
            id: 31,
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
                expr: 'histogram_quantile(0.9, sum by (le) (rate(up_custom_query_duration_seconds_bucket{namespace="observatorium-stage",query="query-path-sli-1M-samples"}[1d])))',
                hide: false,
                interval: '',
                legendFormat: '',
                refId: 'A',
              },
            ],
            title: '90th Percentile Request Latency (1d)',
            type: 'stat',
          },
          {
            datasource: 'app-sre-stage-01-prometheus',
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
            },
            id: 40,
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
                expr: 'clamp_min(\n(\n  (\n    sum(rate(up_custom_query_duration_seconds_bucket{namespace="observatorium-stage",query="query-path-sli-1M-samples",le="2.0113571874999994"}[28d]))\n/\nsum(rate(up_custom_query_duration_seconds_bucket{namespace="observatorium-stage",query="query-path-sli-1M-samples"}[28d]))\n  ) - 0.9\n)\n/ \n(1 - 0.9), 0)',
                hide: false,
                interval: '',
                legendFormat: '',
                refId: 'B',
              },
            ],
            title: 'Error Budget (28d)',
            type: 'stat',
          },
          {

            gridPos: {
              h: 5,
              w: 5,
            },
            id: 20,
            options: {
              content: '<center style="font-size: 25px;">\n\n90% of valid requests that process 10M samples return < 10s\n\n</center>\n\n',
              mode: 'markdown',
            },
            pluginVersion: '8.2.1',
            title: 'SLO',
            type: 'text',
          },
          {
            datasource: 'app-sre-stage-01-prometheus',
            fieldConfig: {
              defaults: {
                color: {
                  mode: 'thresholds',
                },
                mappings: [],
                max: 5,
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
                      value: 50,
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
            },
            id: 32,
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
                expr: 'histogram_quantile(0.9, sum by (le) (rate(up_custom_query_duration_seconds_bucket{namespace="observatorium-stage",query="query-path-sli-10M-samples"}[1d])))',
                hide: false,
                interval: '',
                legendFormat: '',
                refId: 'A',
              },
            ],
            title: '90th Percentile Request Latency (1d)',
            type: 'stat',
          },
          {
            datasource: 'app-sre-stage-01-prometheus',
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
            },
            id: 41,
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
                expr: 'clamp_min(\n(\n  (\n    sum(rate(up_custom_query_duration_seconds_bucket{namespace="observatorium-stage",query="query-path-sli-10M-samples",le="10.761264004567169"}[28d]))\n/\nsum(rate(up_custom_query_duration_seconds_bucket{namespace="observatorium-stage",query="query-path-sli-10M-samples"}[28d]))\n  ) - 0.9\n)\n/ \n(1 - 0.9), 0)',
                hide: false,
                interval: '',
                legendFormat: '',
                refId: 'B',
              },
              {
                exemplar: true,
                expr: 'http_request_duration_seconds_bucket{job="observatorium-observatorium-api",code!~"4..",handler=~"receive"',
                hide: true,
                interval: '',
                legendFormat: '',
                refId: 'A',
              },
            ],
            title: 'Error Budget (28d)',
            type: 'stat',
          },
          {

            gridPos: {
              h: 5,
              w: 5,
            },
            id: 21,
            options: {
              content: '<center style="font-size: 25px;">\n\n90% of valid requests that process 100M samples return < 20s\n\n</center>\n\n',
              mode: 'markdown',
            },
            pluginVersion: '8.2.1',
            title: 'SLO',
            type: 'text',
          },
          {
            datasource: 'app-sre-stage-01-prometheus',
            fieldConfig: {
              defaults: {
                color: {
                  mode: 'thresholds',
                },
                mappings: [],
                max: 10,
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
                      value: 50,
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
            },
            id: 33,
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
                expr: 'histogram_quantile(0.9, sum by (le) (rate(up_custom_query_duration_seconds_bucket{namespace="observatorium-stage",query="query-path-sli-100M-samples"}[1d])))',
                hide: false,
                interval: '',
                legendFormat: '',
                refId: 'A',
              },
            ],
            title: '90th Percentile Request Latency (1d)',
            type: 'stat',
          },
          {
            datasource: 'app-sre-stage-01-prometheus',
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
            },
            id: 42,
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
                expr: 'clamp_min(\n(\n  (\n    sum(rate(up_custom_query_duration_seconds_bucket{namespace="observatorium-stage",query="query-path-sli-100M-samples",le="21.6447457021712"}[28d]))\n/\nsum(rate(up_custom_query_duration_seconds_bucket{namespace="observatorium-stage",query="query-path-sli-100M-samples"}[28d]))\n  ) - 0.9\n)\n/ \n(1 - 0.9), 0)',
                hide: false,
                interval: '',
                legendFormat: '',
                refId: 'B',
              },
            ],
            title: 'Error Budget (28d)',
            type: 'stat',
          },
        ],
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
      title: 'SLOs - Telemeter - Staging',
      uid: 'h-0roLFnz',
      version: 2,
    }),
  },
}
