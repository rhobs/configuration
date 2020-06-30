local list = import 'telemeter/lib/list.libsonnet';

(import 'kube-telemeter.libsonnet') +
{
  telemeterServer+:: {
    serviceMonitor+: {
        metadata+: {
          labels+: {
            prometheus: 'app-sre',
          },
        },
        spec+: {
          namespaceSelector+: { matchNames: ['${NAMESPACE}'] },
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
    
    statefulSet+: {
      spec+: {
        replicas: '${{REPLICAS}}',

        template+: {
          spec+: {
            containers: [
              if c.name == 'telemeter-server' then c {
                image: '${IMAGE}:${IMAGE_TAG}',
                command: [
                  if std.startsWith(c, '--forward-url=') then '--forward-url=${TELEMETER_FORWARD_URL}' else c
                  for c in super.command
                ],
              }
              for c in super.containers
            ],
          },
        },
      },
    },

    statefulSetCanary: self.statefulSet {
      metadata+: {
        name: super.name + '-canary',
      },
      spec+: {
        replicas: '${{REPLICAS_CANARY}}',
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
                image: '${IMAGE_CANARY}:${IMAGE_CANARY_TAG}',
                command+: ['--log-level=debug'],  // Always enable debug logging for canary deployments
              }
              for c in super.containers
            ],
          },
        },
      },
    },

  },
} + {
  local ts = super.telemeterServer,
  local m = super.memcached,
  local tsList = list.asList('telemeter', ts, [])
                 + list.withNamespace($._config)
                 + list.withResourceRequestsAndLimits('telemeter-server', $._config.telemeterServer.resourceRequests, $._config.telemeterServer.resourceLimits),
  local mList = list.asList('memcached', m, [
                  {
                    name: 'MEMCACHED_IMAGE',
                    value: m.images.memcached,
                  },
                  {
                    name: 'MEMCACHED_IMAGE_TAG',
                    value: m.tags.memcached,
                  },
                  {
                    name: 'MEMCACHED_EXPORTER_IMAGE',
                    value: m.images.exporter,
                  },
                  {
                    name: 'MEMCACHED_EXPORTER_IMAGE_TAG',
                    value: m.tags.exporter,
                  },
                ])
                + list.withResourceRequestsAndLimits('memcached', $.memcached.resourceRequests, $.memcached.resourceLimits)
                + list.withResourceRequestsAndLimits('memcached-exporter', { cpu: '50m', memory: '50Mi' }, { cpu: '200m', memory: '200Mi' })
                + list.withNamespace($._config),

  telemeterServer+:: {
    list: list.asList('telemeter', {}, []) + {
      objects:
        tsList.objects +
        mList.objects,

      parameters:
        tsList.parameters +
        mList.parameters,
    },
  },

  _config+:: {
    telemeterServer+: {
      whitelist+: (import 'metrics.json'),
      elideLabels+: [
        'prometheus_replica',
      ],
    },
  },
  memcached+:: {
    images:: {
      memcached: '${MEMCACHED_IMAGE}',
      exporter: '${MEMCACHED_EXPORTER_IMAGE}',
    },
    tags:: {
      memcached: '${MEMCACHED_IMAGE_TAG}',
      exporter: '${MEMCACHED_EXPORTER_IMAGE_TAG}',
    },
  },
  apiVersion: 'v1',
  kind: 'Template',
  metadata: {
    name: 'observatorium-telemeter',
  },
  objects: $.telemeterServer.list.objects,
  parameters: $.telemeterServer.list.parameters,
}
