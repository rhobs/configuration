(import 'github.com/openshift/telemeter/jsonnet/telemeter/server/rhelemeter-kubernetes.libsonnet') +
{
  local config = self._config,
  _config+:: {
    namespace: 'rhelemeter',

    rhelemeterServer+:: {
      image: 'quay.io/app-sre/telemeter:82f71d3',
      replicas: 3,
      logLevel: 'warn',
      oidcIssuer: error 'must provide telemeterForwardURL',
      clientID: error 'must provide clientID',
      clientSecret: error 'must provide clientSecret',
      rhelemeterForwardURL: error 'must provide telemeterForwardURL',
      rhelemeterTenantID: error 'must provide rhelemeterTenantID',
      clientInfoPSK: error 'must provide clientInfoPSK',
    },

  },

  rhelemeterServer+:: {

    secret+: {
      data+:: {
      },
    },

    clientInfoSecret+: {
      data+:: {
      },
    },

    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'rhelemeter-server' then c {
                image: config.rhelemeterServer.image,
                command+: [
                  '--log-level=' + config.rhelemeterServer.logLevel,
                  '--limit-bytes=5242880',
                  '--tenant-id=' + config.rhelemeterServer.rhelemeterTenantID,
                  '--forward-url=' + config.rhelemeterServer.rhelemeterForwardURL,
                ],
              }
              for c in super.containers
            ],
          },
        },
      },
    },

    serviceMonitor+: {
      metadata+: {
        labels+: {
          prometheus: 'app-sre',
        },
      },
      spec+: {
        namespaceSelector+: { matchNames: [config.namespace] },
        endpoints: [
          {
            interval: '60s',
            port: 'internal',
            scheme: 'https',
            tlsConfig: {
              insecureSkipVerify: true,
            },
          },
        ],
      },
    },
  },
}
