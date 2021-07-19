local defaults = {
  name: error 'provide a name for the OPA-APS container',
  image: error 'must provide image',
  clientIDKey: 'client-id',
  clientSecretKey: 'client-secret',
  issuerURLKey: 'issuer-url',
  amsURL: error 'must provide ams-url',
  opaPackage: '',
  resourceTypePrefix: '',
  resources: {},
  secretName: error 'must provide secret-name',
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
  local opa = self,
  config:: defaults + params,

  service+: {
    spec+: {
      ports+: [
        {
          name: 'opa-ams-' + name,
          port: opa.config.ports[name],
          targetPort: opa.config.ports[name],
        }
        for name in std.objectFields(opa.config.ports)
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
          image: opa.config.image,
          args: [
            '--web.listen=127.0.0.1:%s' % opa.config.ports.api,
            '--web.internal.listen=0.0.0.0:%s' % opa.config.ports.metrics,
            '--web.healthchecks.url=http://127.0.0.1:%s' % opa.config.ports.api,
            '--log.level=warn',
            '--ams.url=' + opa.config.amsURL,
            '--resource-type-prefix=' + opa.config.resourceTypePrefix,
            '--oidc.client-id=$(CLIENT_ID)',
            '--oidc.client-secret=$(CLIENT_SECRET)',
            '--oidc.issuer-url=$(ISSUER_URL)',
            '--opa.package=' + opa.config.opaPackage,
          ] + (
            if std.objectHas(opa.config, 'memcached') then
              ['--memcached=' + opa.config.memcached]
            else []
          ) + (
            if std.objectHas(opa.config, 'memcachedExpire') then
              ['--memcached.expire=' + opa.config.memcachedExpire]
            else []
          ) + (
            if std.objectHas(opa.config, 'mappings') then
              [
                '--ams.mappings=%s=%s' % [tenant, opa.config.mappings[tenant]]
                for tenant in std.objectFields(opa.config.mappings)
              ]
            else []
          ) + (
            if std.objectHas(opa.config.internal, 'tracing') then
              [] + (
                if std.objectHas(opa.config.internal.tracing, 'endpoint') then
                  [
                    '--internal.tracing.endpoint=' + opa.config.internal.tracing.endpoint,
                  ]
                else []
              ) + (
                if std.objectHas(opa.config.internal.tracing, 'endpointType') then
                  [
                    '--internal.tracing.endpoint-type=' + opa.config.internal.tracing.endpointType,
                  ]
                else []
              ) + (
                if std.objectHas(opa.config.internal.tracing, 'samplingFraction') then
                  [
                    '--internal.tracing.sampling-fraction=' + opa.config.internal.tracing.samplingFraction,
                  ]
                else []
              ) + (
                if std.objectHas(opa.config.internal.tracing, 'serviceName') then
                  [
                    '--internal.tracing.service-name=' + opa.config.internal.tracing.serviceName,
                  ]
                else []
              )
            else []
          ),
          env: [
            {
              name: 'ISSUER_URL',
              valueFrom: {
                secretKeyRef: {
                  name: opa.config.secretName,
                  key: opa.config.issuerURLKey,
                },
              },
            },
            {
              name: 'CLIENT_ID',
              valueFrom: {
                secretKeyRef: {
                  name: opa.config.secretName,
                  key: opa.config.clientIDKey,
                },
              },
            },
            {
              name: 'CLIENT_SECRET',
              valueFrom: {
                secretKeyRef: {
                  name: opa.config.secretName,
                  key: opa.config.clientSecretKey,
                },
              },
            },
          ],
          ports: [
            {
              name: 'opa-ams-' + name,
              containerPort: opa.config.ports[name],
            }
            for name in std.objectFields(opa.config.ports)
          ],
          livenessProbe: {
            failureThreshold: 10,
            periodSeconds: 30,
            httpGet: {
              path: '/live',
              port: opa.config.ports.metrics,
              scheme: 'HTTP',
            },
          },
          readinessProbe: {
            failureThreshold: 12,
            periodSeconds: 5,
            httpGet: {
              path: '/ready',
              port: opa.config.ports.metrics,
              scheme: 'HTTP',
            },
          },
          resources: opa.config.resources,
        }],
      },
    },
  },

  statefulSet+: {
    spec+: spec,
  },

  deployment+: {
    spec+: spec,
  },
}
