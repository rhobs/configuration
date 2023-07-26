local g = import 'github.com/thanos-io/thanos/mixin/lib/thanos-grafana-builder/builder.libsonnet';
local template = import 'grafonnet/template.libsonnet';
local config = (import '../config.libsonnet').thanos;

function() {
  local intervalTemplate =
    template.interval(
      'interval',
      '5m,10m,30m,1h,6h,12h,auto',
      label='interval',
      current='5m',
    ),
  local namespaceTemplate =
    template.new(
      name='namespace',
      datasource='$datasource',
      query='label_values(up{job=~"rules-objstore.*"}, namespace)',
      label='namespace',
      allValues='.+',
      current='',
      hide='',
      refresh=2,
      includeAll=false,
      sort=1
    ),
  local jobTemplate =
    template.new(
      name='job',
      datasource='$datasource',
      query='label_values(up{namespace="$namespace", job=~"rules-objstore.*"}, job)',
      label='job',
      allValues='.+',
      current='',
      hide='',
      refresh=2,
      includeAll=true,
      sort=1
    ),
  local dashboard =
    g.dashboard('Rules Objstore Dashboard')
    .addRow(
      g.row('Validations')
      .addPanel(
        g.panel('Successful validations', 'Amount of success rule validations per tenant') +
        g.queryPanel(
          [
            'sum by (tenant) (rate(rules_objstore_validations_total{namespace="$namespace", job=~"$job"}[$interval]))',
          ],
          [
            '{{tenant}}',
          ]
        ) { span:: 0 },
      )
      .addPanel(
        g.panel('Failed validations', 'Amount of failed rule validations per tenant') +
        g.queryPanel(
          [
            'sum by (tenant) (rate(rules_objstore_validations_failed_total{namespace="$namespace", job=~"$job"}[$interval]))',
          ],
          [
            '{{tenant}}',
          ]
        ) { span:: 0 },
      )
    )
    .addRow(
      g.row('Rules and rule groups')
      .addPanel(
        g.panel('Rule groups configured', 'Amount of rule groups configured per tenant') +
        g.queryPanel(
          [
            'sum by (tenant) (rules_objstore_rule_groups_configured{namespace="$namespace", job=~"$job"})',
          ],
          [
            '{{tenant}}',
          ]
        ) { span:: 0 },
      )
      .addPanel(
        g.panel('Rules configured', 'Amount of rules configured per tenant') +
        g.queryPanel(
          [
            'sum by (tenant) (rules_objstore_rules_configured{namespace="$namespace", job=~"$job"})',
          ],
          [
            '{{tenant}}',
          ]
        ) { span:: 0 },
      )
    )
    + {
      templating+: {
        list+: [
          if variable.name == 'datasource'
          then variable { regex: config.dashboard.instance_name_filter }
          else variable
          for variable in super.list
        ] + [namespaceTemplate, jobTemplate, intervalTemplate],
      },
    },

  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    name: 'grafana-dashboard-rules-objstore',
  },
  data: {
    'rhobs-observatorium-rules-objstore.json': std.manifestJsonEx(dashboard, ' '),
  },
}
