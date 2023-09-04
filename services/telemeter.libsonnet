(import 'github.com/openshift/telemeter/jsonnet/telemeter/server/kubernetes.libsonnet') +
{
  local config = self._config,
  _config+:: {
    namespace: 'telemeter',

    telemeterServer+:: {
      image: 'quay.io/app-sre/telemeter:c205c41',
      replicas: 3,
      logLevel: 'warn',
      tokenExpireSeconds: '3600',
      telemeterForwardURL: error 'must provide telemeterForwardURL',
    },

    telemeterServerCanary:: {
      image: 'quay.io/app-sre/telemeter:c205c41',
      replicas: 0,
    },

    memcachedExporter:: {
      resourceRequests: { cpu: '50m', memory: '50Mi' },
      resourceLimits: { cpu: '200m', memory: '200Mi' },
    },
  },

  telemeterServer+:: {
    secret+: {
      data+: {
        client_id: std.base64('test'),
        client_secret: std.base64('ZXhhbXBsZS1hcHAtc2VjcmV0'),
        oidc_issuer: std.base64('http://dex.dex.svc.cluster.local:5556/dex'),
        authorize_url: std.base64('https://api.stage.openshift.com/api/accounts_mgmt/v1/cluster_registrations'),
      },
    },

    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'telemeter-server' then c {
                image: config.telemeterServer.image,
                command+: [
                  '--log-level=' + config.telemeterServer.logLevel,
                  '--token-expire-seconds=' + config.telemeterServer.tokenExpireSeconds,
                  '--limit-bytes=5242880',
                  '--forward-url=' + config.telemeterServer.telemeterForwardURL,
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

    statefulSetCanary: self.statefulSet {
      metadata+: {
        name: super.name + '-canary',
      },
      spec+: {
        replicas: config.telemeterServerCanary.replicas,
        selector+: {
          matchLabels+: {
            track: 'canary',
          },
        },
        template+: {
          metadata+: {
            labels+: {
              track: 'canary',
            },
          },
          spec+: {
            containers: [
              if c.name == 'telemeter-server' then c {
                image: config.telemeterServerCanary.image,
                command+: ['--log-level=debug'],  // Always enable debug logging for canary deployments.
              }
              for c in super.containers
            ],
          },
        },
      },
    },
  },

  memcached+:: {
    statefulSet+: {
      metadata+: {
        labels+: {
          'app.kubernetes.io/component': 'telemeter-cache',
          'app.kubernetes.io/instance': 'telemeter',
          'app.kubernetes.io/name': 'memcached',
          'app.kubernetes.io/part-of': 'telemeter',
        },
      },
      spec+: {
        template+: {
          spec+: {
            containers: [
              super.containers[0],
              super.containers[1] {
                name: 'memcached-exporter',
                resources: {
                  limits: {
                    cpu: config.memcachedExporter.resourceLimits.cpu,
                    memory: config.memcachedExporter.resourceLimits.memory,
                  },
                  requests: {
                    cpu: config.memcachedExporter.resourceRequests.cpu,
                    memory: config.memcachedExporter.resourceRequests.memory,
                  },
                },
              },
            ],
          },
        },
      },
    },
    serviceAccount+: {
      imagePullSecrets+: [{ name: 'quay.io' }],
    },
    serviceMonitor+: {
      metadata+: {
        labels+: {
          prometheus: 'app-sre',
        },
      },
      spec+: {
        jobLabel: 'app.kubernetes.io/component',
        namespaceSelector+: { matchNames: [config.namespace] },
        selector+: {
          matchLabels+: {
            'app.kubernetes.io/name': 'memcached',
          },
        },
      },
    },
  },
}
