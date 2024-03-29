function(datasource, namespace) {
  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    name: 'grafana-dashboard-jaeger-service',
  },
  data: {
    'jaeger.json': std.manifestJsonEx(
      {
        annotations: {
          list: [
            {
              builtIn: 1,
              datasource: '-- Grafana --',
              enable: true,
              hide: true,
              iconColor: 'rgba(0, 211, 255, 1)',
              name: 'Annotations & Alerts',
              type: 'dashboard',
            },
          ],
        },
        editable: true,
        gnetId: null,
        graphTooltip: 0,
        id: 9,
        iteration: 1661200932195,
        links: [],
        panels: [
          {
            collapsed: false,
            datasource: null,
            gridPos: {
              h: 1,
              w: 24,
              x: 0,
              y: 0,
            },
            id: 11,
            panels: [],
            repeat: null,
            title: 'Services',
            type: 'row',
          },
          {
            aliasColors: {
              'error': '#E24D42',
              success: '#7EB26D',
            },
            bars: false,
            dashLength: 10,
            dashes: false,
            datasource: '$datasource',
            fieldConfig: {
              defaults: {},
              overrides: [],
            },
            fill: 10,
            fillGradient: 0,
            gridPos: {
              h: 7,
              w: 12,
              x: 0,
              y: 1,
            },
            hiddenSeries: false,
            id: 1,
            legend: {
              avg: false,
              current: false,
              max: false,
              min: false,
              show: true,
              total: false,
              values: false,
            },
            lines: true,
            linewidth: 0,
            links: [],
            nullPointMode: 'null as zero',
            options: {
              alertThreshold: true,
            },
            percentage: false,
            pluginVersion: '7.5.16',
            pointradius: 5,
            points: false,
            renderer: 'flot',
            seriesOverrides: [],
            spaceLength: 10,
            stack: true,
            steppedLine: false,
            targets: [
              {
                exemplar: true,
                expr: 'sum(rate(jaeger_tracer_reporter_spans_total{result=~"dropped|err", namespace="' + namespace + '"}[1m]))',
                format: 'time_series',
                interval: '',
                intervalFactor: 2,
                legendFormat: 'error',
                refId: 'A',
                step: 10,
              },
              {
                exemplar: true,
                expr: 'sum(rate(jaeger_tracer_reporter_spans_total{namespace="' + namespace + '"}[1m])) - sum(rate(jaeger_tracer_reporter_spans_total{result=~"dropped|err", namespace="' + namespace + '"}[1m]))',
                format: 'time_series',
                interval: '',
                intervalFactor: 2,
                legendFormat: 'success',
                refId: 'B',
                step: 10,
              },
            ],
            thresholds: [],
            timeFrom: null,
            timeRegions: [],
            timeShift: null,
            title: 'span creation rate',
            tooltip: {
              shared: true,
              sort: 0,
              value_type: 'individual',
            },
            type: 'graph',
            xaxis: {
              buckets: null,
              mode: 'time',
              name: null,
              show: true,
              values: [],
            },
            yaxes: [
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: 0,
                show: true,
              },
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: null,
                show: false,
              },
            ],
            yaxis: {
              align: false,
              alignLevel: null,
            },
          },
          {
            aliasColors: {},
            bars: false,
            dashLength: 10,
            dashes: false,
            datasource: '$datasource',
            fieldConfig: {
              defaults: {},
              overrides: [],
            },
            fill: 10,
            fillGradient: 0,
            gridPos: {
              h: 7,
              w: 12,
              x: 12,
              y: 1,
            },
            hiddenSeries: false,
            id: 2,
            legend: {
              avg: false,
              current: false,
              max: false,
              min: false,
              show: true,
              total: false,
              values: false,
            },
            lines: true,
            linewidth: 0,
            links: [],
            nullPointMode: 'null as zero',
            options: {
              alertThreshold: true,
            },
            percentage: false,
            pluginVersion: '7.5.16',
            pointradius: 5,
            points: false,
            renderer: 'flot',
            seriesOverrides: [],
            spaceLength: 10,
            stack: true,
            steppedLine: false,
            targets: [
              {
                exemplar: true,
                expr: 'sum(rate(jaeger_tracer_reporter_spans_total{result=~"dropped|err",namespace="' + namespace + '"}[1m])) / sum(rate(jaeger_tracer_reporter_spans_total{namespace="' + namespace + '"}[1m]))',
                format: 'time_series',
                interval: '',
                intervalFactor: 2,
                legendFormat: '{{namespace}}',
                legendLink: null,
                refId: 'A',
                step: 10,
              },
            ],
            thresholds: [],
            timeFrom: null,
            timeRegions: [],
            timeShift: null,
            title: '% spans dropped',
            tooltip: {
              shared: true,
              sort: 0,
              value_type: 'individual',
            },
            type: 'graph',
            xaxis: {
              buckets: null,
              mode: 'time',
              name: null,
              show: true,
              values: [],
            },
            yaxes: [
              {
                format: 'percentunit',
                label: null,
                logBase: 1,
                max: 1,
                min: 0,
                show: true,
              },
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: null,
                show: false,
              },
            ],
            yaxis: {
              align: false,
              alignLevel: null,
            },
          },
          {
            collapsed: false,
            datasource: null,
            gridPos: {
              h: 1,
              w: 24,
              x: 0,
              y: 8,
            },
            id: 12,
            panels: [],
            repeat: null,
            title: 'Agent',
            type: 'row',
          },
          {
            aliasColors: {
              'error': '#E24D42',
              success: '#7EB26D',
            },
            bars: false,
            dashLength: 10,
            dashes: false,
            datasource: '$datasource',
            fieldConfig: {
              defaults: {},
              overrides: [],
            },
            fill: 10,
            fillGradient: 0,
            gridPos: {
              h: 7,
              w: 12,
              x: 0,
              y: 9,
            },
            hiddenSeries: false,
            id: 3,
            legend: {
              avg: false,
              current: false,
              max: false,
              min: false,
              show: true,
              total: false,
              values: false,
            },
            lines: true,
            linewidth: 0,
            links: [],
            nullPointMode: 'null as zero',
            options: {
              alertThreshold: true,
            },
            percentage: false,
            pluginVersion: '7.5.16',
            pointradius: 5,
            points: false,
            renderer: 'flot',
            seriesOverrides: [],
            spaceLength: 10,
            stack: true,
            steppedLine: false,
            targets: [
              {
                exemplar: true,
                expr: 'sum(rate(jaeger_agent_reporter_batches_failures_total{namespace="' + namespace + '"}[1m]))',
                format: 'time_series',
                interval: '',
                intervalFactor: 2,
                legendFormat: 'error',
                refId: 'A',
                step: 10,
              },
              {
                exemplar: true,
                expr: 'sum(rate(jaeger_agent_reporter_batches_submitted_total{namespace="' + namespace + '"}[1m])) - sum(rate(jaeger_agent_reporter_batches_failures_total{namespace="' + namespace + '"}[1m]))',
                format: 'time_series',
                interval: '',
                intervalFactor: 2,
                legendFormat: 'success',
                refId: 'B',
                step: 10,
              },
            ],
            thresholds: [],
            timeFrom: null,
            timeRegions: [],
            timeShift: null,
            title: 'batch ingest rate',
            tooltip: {
              shared: true,
              sort: 0,
              value_type: 'individual',
            },
            type: 'graph',
            xaxis: {
              buckets: null,
              mode: 'time',
              name: null,
              show: true,
              values: [],
            },
            yaxes: [
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: 0,
                show: true,
              },
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: null,
                show: false,
              },
            ],
            yaxis: {
              align: false,
              alignLevel: null,
            },
          },
          {
            aliasColors: {},
            bars: false,
            dashLength: 10,
            dashes: false,
            datasource: '$datasource',
            fieldConfig: {
              defaults: {},
              overrides: [],
            },
            fill: 10,
            fillGradient: 0,
            gridPos: {
              h: 7,
              w: 12,
              x: 12,
              y: 9,
            },
            hiddenSeries: false,
            id: 4,
            legend: {
              avg: false,
              current: false,
              max: false,
              min: false,
              show: true,
              total: false,
              values: false,
            },
            lines: true,
            linewidth: 0,
            links: [],
            nullPointMode: 'null as zero',
            options: {
              alertThreshold: true,
            },
            percentage: false,
            pluginVersion: '7.5.16',
            pointradius: 5,
            points: false,
            renderer: 'flot',
            seriesOverrides: [],
            spaceLength: 10,
            stack: true,
            steppedLine: false,
            targets: [
              {
                exemplar: true,
                expr: 'sum(rate(jaeger_agent_reporter_batches_failures_total{namespace="' + namespace + '"}[1m])) by (cluster) / sum(rate(jaeger_agent_reporter_batches_submitted_total{namespace="' + namespace + '"}[1m])) by (cluster)',
                format: 'time_series',
                interval: '',
                intervalFactor: 2,
                legendFormat: '{{cluster}}',
                legendLink: null,
                refId: 'A',
                step: 10,
              },
            ],
            thresholds: [],
            timeFrom: null,
            timeRegions: [],
            timeShift: null,
            title: '% batches dropped',
            tooltip: {
              shared: true,
              sort: 0,
              value_type: 'individual',
            },
            type: 'graph',
            xaxis: {
              buckets: null,
              mode: 'time',
              name: null,
              show: true,
              values: [],
            },
            yaxes: [
              {
                format: 'percentunit',
                label: null,
                logBase: 1,
                max: 1,
                min: 0,
                show: true,
              },
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: null,
                show: false,
              },
            ],
            yaxis: {
              align: false,
              alignLevel: null,
            },
          },
          {
            collapsed: false,
            datasource: null,
            gridPos: {
              h: 1,
              w: 24,
              x: 0,
              y: 16,
            },
            id: 13,
            panels: [],
            repeat: null,
            title: 'Collector',
            type: 'row',
          },
          {
            aliasColors: {
              'error': '#E24D42',
              success: '#7EB26D',
            },
            bars: false,
            dashLength: 10,
            dashes: false,
            datasource: '$datasource',
            fieldConfig: {
              defaults: {},
              overrides: [],
            },
            fill: 10,
            fillGradient: 0,
            gridPos: {
              h: 7,
              w: 12,
              x: 0,
              y: 17,
            },
            hiddenSeries: false,
            id: 5,
            legend: {
              avg: false,
              current: false,
              max: false,
              min: false,
              show: true,
              total: false,
              values: false,
            },
            lines: true,
            linewidth: 0,
            links: [],
            nullPointMode: 'null as zero',
            options: {
              alertThreshold: true,
            },
            percentage: false,
            pluginVersion: '7.5.16',
            pointradius: 5,
            points: false,
            renderer: 'flot',
            seriesOverrides: [],
            spaceLength: 10,
            stack: true,
            steppedLine: false,
            targets: [
              {
                exemplar: true,
                expr: 'sum(rate(jaeger_collector_spans_dropped_total{namespace="' + namespace + '"}[1m]))',
                format: 'time_series',
                interval: '',
                intervalFactor: 2,
                legendFormat: 'error',
                refId: 'A',
                step: 10,
              },
              {
                exemplar: true,
                expr: 'sum(rate(jaeger_collector_spans_received_total{namespace="' + namespace + '"}[1m])) - sum(rate(jaeger_collector_spans_dropped_total{namespace="' + namespace + '"}[1m]))',
                format: 'time_series',
                interval: '',
                intervalFactor: 2,
                legendFormat: 'success',
                refId: 'B',
                step: 10,
              },
            ],
            thresholds: [],
            timeFrom: null,
            timeRegions: [],
            timeShift: null,
            title: 'span ingest rate',
            tooltip: {
              shared: true,
              sort: 0,
              value_type: 'individual',
            },
            type: 'graph',
            xaxis: {
              buckets: null,
              mode: 'time',
              name: null,
              show: true,
              values: [],
            },
            yaxes: [
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: 0,
                show: true,
              },
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: null,
                show: false,
              },
            ],
            yaxis: {
              align: false,
              alignLevel: null,
            },
          },
          {
            aliasColors: {},
            bars: false,
            dashLength: 10,
            dashes: false,
            datasource: '$datasource',
            fieldConfig: {
              defaults: {},
              overrides: [],
            },
            fill: 10,
            fillGradient: 0,
            gridPos: {
              h: 7,
              w: 12,
              x: 12,
              y: 17,
            },
            hiddenSeries: false,
            id: 6,
            legend: {
              avg: false,
              current: false,
              max: false,
              min: false,
              show: true,
              total: false,
              values: false,
            },
            lines: true,
            linewidth: 0,
            links: [],
            nullPointMode: 'null as zero',
            options: {
              alertThreshold: true,
            },
            percentage: false,
            pluginVersion: '7.5.16',
            pointradius: 5,
            points: false,
            renderer: 'flot',
            seriesOverrides: [],
            spaceLength: 10,
            stack: true,
            steppedLine: false,
            targets: [
              {
                exemplar: true,
                expr: 'sum(rate(jaeger_collector_spans_dropped_total{namespace="' + namespace + '"}[1m])) by (instance) / sum(rate(jaeger_collector_spans_received_total{namespace="' + namespace + '"}[1m])) by (instance)',
                format: 'time_series',
                interval: '',
                intervalFactor: 2,
                legendFormat: '{{instance}}',
                legendLink: null,
                refId: 'A',
                step: 10,
              },
            ],
            thresholds: [],
            timeFrom: null,
            timeRegions: [],
            timeShift: null,
            title: '% spans dropped',
            tooltip: {
              shared: true,
              sort: 0,
              value_type: 'individual',
            },
            type: 'graph',
            xaxis: {
              buckets: null,
              mode: 'time',
              name: null,
              show: true,
              values: [],
            },
            yaxes: [
              {
                format: 'percentunit',
                label: null,
                logBase: 1,
                max: 1,
                min: 0,
                show: true,
              },
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: null,
                show: false,
              },
            ],
            yaxis: {
              align: false,
              alignLevel: null,
            },
          },
          {
            collapsed: false,
            datasource: null,
            gridPos: {
              h: 1,
              w: 24,
              x: 0,
              y: 24,
            },
            id: 14,
            panels: [],
            repeat: null,
            title: 'Collector Queue',
            type: 'row',
          },
          {
            aliasColors: {},
            bars: false,
            dashLength: 10,
            dashes: false,
            datasource: '$datasource',
            fieldConfig: {
              defaults: {},
              overrides: [],
            },
            fill: 10,
            fillGradient: 0,
            gridPos: {
              h: 7,
              w: 12,
              x: 0,
              y: 25,
            },
            hiddenSeries: false,
            id: 7,
            legend: {
              avg: false,
              current: false,
              max: false,
              min: false,
              show: true,
              total: false,
              values: false,
            },
            lines: true,
            linewidth: 0,
            links: [],
            nullPointMode: 'null as zero',
            options: {
              alertThreshold: true,
            },
            percentage: false,
            pluginVersion: '7.5.16',
            pointradius: 5,
            points: false,
            renderer: 'flot',
            seriesOverrides: [],
            spaceLength: 10,
            stack: true,
            steppedLine: false,
            targets: [
              {
                exemplar: true,
                expr: 'jaeger_collector_queue_length{namespace="' + namespace + '"}',
                format: 'time_series',
                interval: '',
                intervalFactor: 2,
                legendFormat: '{{instance}}',
                legendLink: null,
                refId: 'A',
                step: 10,
              },
            ],
            thresholds: [],
            timeFrom: null,
            timeRegions: [],
            timeShift: null,
            title: 'span queue length',
            tooltip: {
              shared: true,
              sort: 0,
              value_type: 'individual',
            },
            type: 'graph',
            xaxis: {
              buckets: null,
              mode: 'time',
              name: null,
              show: true,
              values: [],
            },
            yaxes: [
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: 0,
                show: true,
              },
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: null,
                show: false,
              },
            ],
            yaxis: {
              align: false,
              alignLevel: null,
            },
          },
          {
            aliasColors: {},
            bars: false,
            dashLength: 10,
            dashes: false,
            datasource: '$datasource',
            fieldConfig: {
              defaults: {},
              overrides: [],
            },
            fill: 1,
            fillGradient: 0,
            gridPos: {
              h: 7,
              w: 12,
              x: 12,
              y: 25,
            },
            hiddenSeries: false,
            id: 8,
            legend: {
              avg: false,
              current: false,
              max: false,
              min: false,
              show: true,
              total: false,
              values: false,
            },
            lines: true,
            linewidth: 1,
            links: [],
            nullPointMode: 'null as zero',
            options: {
              alertThreshold: true,
            },
            percentage: false,
            pluginVersion: '7.5.16',
            pointradius: 5,
            points: false,
            renderer: 'flot',
            seriesOverrides: [],
            spaceLength: 10,
            stack: false,
            steppedLine: false,
            targets: [
              {
                exemplar: true,
                expr: 'histogram_quantile(0.95, sum(rate(jaeger_collector_in_queue_latency_bucket{namespace="' + namespace + '"}[1m])) by (le, instance))',
                format: 'time_series',
                interval: '',
                intervalFactor: 2,
                legendFormat: '{{instance}}',
                legendLink: null,
                refId: 'A',
                step: 10,
              },
            ],
            thresholds: [],
            timeFrom: null,
            timeRegions: [],
            timeShift: null,
            title: 'span queue time - 95 percentile',
            tooltip: {
              shared: true,
              sort: 0,
              value_type: 'individual',
            },
            type: 'graph',
            xaxis: {
              buckets: null,
              mode: 'time',
              name: null,
              show: true,
              values: [],
            },
            yaxes: [
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: 0,
                show: true,
              },
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: null,
                show: false,
              },
            ],
            yaxis: {
              align: false,
              alignLevel: null,
            },
          },
          {
            collapsed: false,
            datasource: null,
            gridPos: {
              h: 1,
              w: 24,
              x: 0,
              y: 32,
            },
            id: 15,
            panels: [],
            repeat: null,
            title: 'Query',
            type: 'row',
          },
          {
            aliasColors: {
              'error': '#E24D42',
              success: '#7EB26D',
            },
            bars: false,
            dashLength: 10,
            dashes: false,
            datasource: '$datasource',
            fieldConfig: {
              defaults: {},
              overrides: [],
            },
            fill: 10,
            fillGradient: 0,
            gridPos: {
              h: 7,
              w: 12,
              x: 0,
              y: 33,
            },
            hiddenSeries: false,
            id: 9,
            legend: {
              avg: false,
              current: false,
              max: false,
              min: false,
              show: true,
              total: false,
              values: false,
            },
            lines: true,
            linewidth: 0,
            links: [],
            nullPointMode: 'null as zero',
            options: {
              alertThreshold: true,
            },
            percentage: false,
            pluginVersion: '7.5.16',
            pointradius: 5,
            points: false,
            renderer: 'flot',
            seriesOverrides: [],
            spaceLength: 10,
            stack: true,
            steppedLine: false,
            targets: [
              {
                exemplar: true,
                expr: 'sum(rate(jaeger_query_requests_total{result="err", namespace="' + namespace + '"}[1m]))',
                format: 'time_series',
                interval: '',
                intervalFactor: 2,
                legendFormat: 'error',
                refId: 'A',
                step: 10,
              },
              {
                exemplar: true,
                expr: 'sum(rate(jaeger_query_requests_total{namespace="' + namespace + '"}[1m])) - sum(rate(jaeger_query_requests_total{result="err", namespace="' + namespace + '"}[1m]))',
                format: 'time_series',
                interval: '',
                intervalFactor: 2,
                legendFormat: 'success',
                refId: 'B',
                step: 10,
              },
            ],
            thresholds: [],
            timeFrom: null,
            timeRegions: [],
            timeShift: null,
            title: 'qps',
            tooltip: {
              shared: true,
              sort: 0,
              value_type: 'individual',
            },
            type: 'graph',
            xaxis: {
              buckets: null,
              mode: 'time',
              name: null,
              show: true,
              values: [],
            },
            yaxes: [
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: 0,
                show: true,
              },
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: null,
                show: false,
              },
            ],
            yaxis: {
              align: false,
              alignLevel: null,
            },
          },
          {
            aliasColors: {},
            bars: false,
            dashLength: 10,
            dashes: false,
            datasource: '$datasource',
            fieldConfig: {
              defaults: {},
              overrides: [],
            },
            fill: 10,
            fillGradient: 0,
            gridPos: {
              h: 7,
              w: 12,
              x: 12,
              y: 33,
            },
            hiddenSeries: false,
            id: 10,
            legend: {
              avg: false,
              current: false,
              max: false,
              min: false,
              show: true,
              total: false,
              values: false,
            },
            lines: true,
            linewidth: 0,
            links: [],
            nullPointMode: 'null as zero',
            options: {
              alertThreshold: true,
            },
            percentage: false,
            pluginVersion: '7.5.16',
            pointradius: 5,
            points: false,
            renderer: 'flot',
            seriesOverrides: [],
            spaceLength: 10,
            stack: true,
            steppedLine: false,
            targets: [
              {
                expr: 'histogram_quantile(0.99, sum(rate(jaeger_query_latency_bucket{namespace="' + namespace + '"}[1m])) by (le, instance))',
                format: 'time_series',
                intervalFactor: 2,
                legendFormat: '{{instance}}',
                legendLink: null,
                refId: 'A',
                step: 10,
              },
            ],
            thresholds: [],
            timeFrom: null,
            timeRegions: [],
            timeShift: null,
            title: 'latency - 99 percentile',
            tooltip: {
              shared: true,
              sort: 0,
              value_type: 'individual',
            },
            type: 'graph',
            xaxis: {
              buckets: null,
              mode: 'time',
              name: null,
              show: true,
              values: [],
            },
            yaxes: [
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: 0,
                show: true,
              },
              {
                format: 'short',
                label: null,
                logBase: 1,
                max: null,
                min: null,
                show: false,
              },
            ],
            yaxis: {
              align: false,
              alignLevel: null,
            },
          },
        ],
        refresh: '10s',
        schemaVersion: 27,
        style: 'dark',
        tags: [],
        templating: {
          list: [
            {
              current: {
                selected: false,
                text: 'Prometheus',
                value: 'Prometheus',
              },
              description: null,
              'error': null,
              hide: 0,
              includeAll: false,
              label: null,
              multi: false,
              name: 'datasource',
              options: [],
              query: 'prometheus',
              refresh: 1,
              regex: '',
              skipUrlSync: false,
              type: 'datasource',
            },
          ],
        },
        time: {
          from: 'now-2d',
          to: 'now',
        },
        timepicker: {
          refresh_intervals: [
            '5s',
            '10s',
            '30s',
            '1m',
            '5m',
            '15m',
            '30m',
            '1h',
            '2h',
            '1d',
          ],
          time_options: [
            '5m',
            '15m',
            '1h',
            '6h',
            '12h',
            '24h',
            '2d',
            '7d',
            '30d',
          ],
        },
        timezone: 'utc',
        title: 'Jaeger',
        uid: 'nNAj54ZVk',
        version: 1,
      }, '  ',
    ),
  },
}
