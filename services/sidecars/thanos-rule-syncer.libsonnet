local defaults = {
  image: error 'must provide image',
  rulesBackendURL: error 'must provide rules backend url',
  thanosRuleURL: 'http://localhost:10902',
  volumeName: error 'must provide volume name',
  fileName: error 'must provide filename',
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

  local mountPath = '/etc/thanos-rule-syncer',

  local spec = {
    template+: {
      spec+: {
        containers+: [{
          name: 'thanos-rule-syncer',
          image: trs.config.image,
          args: [
            '-file=' + mountPath + '/' + trs.config.fileName,
            '-interval=%d' % trs.config.interval,
            '-rules-backend-url=' + trs.config.rulesBackendURL,
            '-thanos-rule-url=' + trs.config.thanosRuleURL,
          ],
          volumeMounts: [{
            name: trs.config.volumeName,
            mountPath: mountPath,
          }],
          resources: trs.config.resources,
        }],
        volumes+: [{
          name: trs.config.volumeName,
          emptyDir: {},
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
