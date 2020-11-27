local defaults = {
  name: error 'provide a name for the oauth proxy',
  image: error 'must provide image',
  clientIDKey: 'client-id',
  clientSecretKey: error 'must provide client-secret',
  issuerURLKey: error 'must provide issuer-url',
  amsURL: error 'must provide ams-url',
  memcached: error 'must provide memcached address',
  memcachedExpire: error 'must provide memcached-expire',
  opaPackage: error 'must provide opa-package',
  resourceTypePrefix: error 'must provide resourse-type-prefix',
  resources: {},
  ports: {
    api: 8082,
    metrics: 8083,
  },
  mappings: {
    // A map from Observatorium tenant names to AMS organization IDs, e.g.:
    // tenant: 'organizationID',
  },
};

function(params) {
  local oap = self,
  config:: defaults + params,

  service+: {
    spec+: {
      ports+: [
        {
          name: 'opa-ams-' + name,
          port: oap.config.ports[name],
          targetPort: oap.config.ports[name],
        }
        for name in std.objectFields(oap.config.ports)
      ],
    },
  },

  serviceMonitor+: {
    spec+: {
      endpoints+: [
        { port: 'opa-ams-metrics' },
      ],
    },
  },

  // Spec is shared for both Deployment and StatefulSet
  local spec = {
    template+: {
      spec+: {
        containers+: [{
          name: 'opa-ams',
          image: oap.config.image,
          args: [
            '--web.listen=127.0.0.1:%s' % oap.config.ports.api,
            '--web.internal.listen=0.0.0.0:%s' % oap.config.ports.metrics,
            '--web.healthchecks.url=http://127.0.0.1:%s' % oap.config.ports.api,
            '--log.level=warn',
            '--ams.url=' + oap.config.amsURL,
            '--resource-type-prefix=' + oap.config.resourceTypePrefix,
            '--oidc.client-id=$(CLIENT_ID)',
            '--oidc.client-secret=$(CLIENT_SECRET)',
            '--oidc.issuer-url=$(ISSUER_URL)',
            '--opa.package=' + oap.config.opaPackage,
          ] + (
            if std.objectHas(oap.config, 'memcached') then
              ['--memcached=' + oap.config.memcached]
            else []
          ) + (
            if std.objectHas(oap.config, 'memcachedExpire') then
              ['--memcached.expire=' + oap.config.memcachedExpire]
            else []
          ) + (
            if std.objectHas(oap.config, 'mappings') then
              [
                '--ams.mappings=%s=%s' % [tenant, oap.config.mappings[tenant]]
                for tenant in std.objectFields(oap.config.mappings)
              ]
            else []
          ),
          env: [
            {
              name: 'ISSUER_URL',
              valueFrom: {
                secretKeyRef: {
                  name: oap.config.secretName,
                  key: oap.config.issuerURLKey,
                },
              },
            },
            {
              name: 'CLIENT_ID',
              valueFrom: {
                secretKeyRef: {
                  name: oap.config.secretName,
                  key: oap.config.clientIDKey,
                },
              },
            },
            {
              name: 'CLIENT_SECRET',
              valueFrom: {
                secretKeyRef: {
                  name: oap.config.secretName,
                  key: oap.config.clientSecretKey,
                },
              },
            },
          ],
          ports: [
            {
              name: 'opa-ams-' + name,
              containerPort: oap.config.ports[name],
            }
            for name in std.objectFields(oap.config.ports)
          ],
          livenessProbe: {
            failureThreshold: 10,
            periodSeconds: 30,
            httpGet: {
              path: '/live',
              port: oap.config.ports.metrics,
              scheme: 'HTTP',
            },
          },
          readinessProbe: {
            failureThreshold: 12,
            periodSeconds: 5,
            httpGet: {
              path: '/ready',
              port: oap.config.ports.metrics,
              scheme: 'HTTP',
            },
          },
          resources: oap.config.resources,
        }],
      },
    },
  },

  statefulSet+: {
    spec+: spec {},
  },

  deployment+: {
    spec+: spec,
  },
}
