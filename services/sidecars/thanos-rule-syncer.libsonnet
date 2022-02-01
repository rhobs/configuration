local defaults = {
  image: error 'must provide image',
  rulesBackendURL: error 'must provide rules backend url',
  thanosRuleURL: 'http://localhost:10902',
  file: error 'must provide rules file',
  interval: 60,
  resources: {
    requests: { cpu: '32m', memory: '64Mi' },
    limits: { cpu: '128m', memory: '128Mi' },
  },
};

function(params) {
  local trs = self,
  config:: defaults + params,

  assert std.isNumber(trs.config.interval) && trs.config.interval > 0 : 'interval has to be number > 0',

  local spec = {
    template+: {
      spec+: {
        containers+: [{
          name: 'thanos-rule-syncer',
          image: trs.config.image,
          args: [
            '-file=' + trs.config.file,
            '-interval=%d' % trs.config.interval,
            '-rules-backend-url=' + trs.config.rulesBackendURL,
            '-thanos-rule-url=' + trs.config.thanosRuleURL,
          ],
          resources: trs.config.resources,
        }],
        serviceAccountName: '${SERVICE_ACCOUNT_NAME}',
      },
    },
  },

  spec+: spec,

  statefulSet+: {
    spec+: spec,
  },

  deployment+: {
    spec+: spec,
  },
}
