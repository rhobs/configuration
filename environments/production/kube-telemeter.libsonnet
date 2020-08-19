(import 'telemeter/server/kubernetes.libsonnet') +
{
  _config+:: {
    namespace: 'observatorium',
  },

  telemeterServer+:: {
    local image = 'quay.io/app-sre/telemeter:c205c41',

    statefulSet+: {
      spec+: {
        replicas: 3,
        template+: {
          spec+: {
            containers: [
              super.containers[0] {
                image: image,
                command+: [
                  '--token-expire-seconds=${{TELEMETER_SERVER_TOKEN_EXPIRE_SECONDS}}',
                  '--limit-bytes=5242880',
                  '--forward-url=http://%s.%s.svc:%d/api/metrics/v1/api/v1/receive' % [
                    'thanos-receive',
                    $._config.namespace,
                    19291,
                  ],
                ],
              },
            ],
          },
        },
      },
    },
  },
  memcached+:: {
    replicas:: 1,

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
              },
            ],
          },
        },
      },
    },

    serviceMonitor+: {
      spec+: {
        jobLabel: 'app.kubernetes.io/component',
        selector+: {
          matchLabels+: {
            'app.kubernetes.io/component': 'telemeter-cache',
            'app.kubernetes.io/instance': 'telemeter',
            'app.kubernetes.io/name': 'memcached',
            'app.kubernetes.io/part-of': 'telemeter',
          },
        },
      },
    },
  },
}
