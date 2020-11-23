local defaults = {
  local defaults = self,
  name: error 'provide a name for the oauth proxy',
  image: error 'must provide image',
  upstream: error 'must provide upstream',
  tlsSecretName: defaults.name + '-tls',
  sessionSecretName: error 'must provide sessionSecretName',
  sessionSecret: error 'must provide proxySessionSecret',
  serviceAccountName: error 'must provide serviceAccountName',
  resources: {},
  ports: {
    https: 8443,
  },
};

function(params) {
  local oap = self,
  config:: defaults + params,

  service+: {
    metadata+: {
      annotations+: {
        'service.alpha.openshift.io/serving-cert-secret-name': oap.config.tlsSecretName,
      },
    },
    spec+: {
      ports+: [
        { name: 'https', port: oap.config.ports.https, targetPort: oap.config.ports.https },
      ],
    },
  },

  proxySecret: {
    apiVersion: 'v1',
    kind: 'Secret',
    metadata+: {
      name: oap.config.name + '-proxy',
    },
    type: 'Opaque',
    data: {
      session_secret: '',
    },
  },

  // Spec is shared for both Deployment and StatefulSet
  local spec = {
    template+: {
      spec+: {
        serviceAccountName: oap.config.serviceAccountName,
        containers+: [{
          name: 'oauth-proxy',
          image: oap.config.image,
          args: [
            '-provider=openshift',
            '-https-address=:' + oap.config.ports.https,
            '-http-address=',
            '-email-domain=*',
            '-upstream=' + oap.config.upstream,
            '-openshift-service-account=' + oap.config.serviceAccountName,
            '-openshift-sar={"resource": "namespaces", "verb": "get", "name": "${NAMESPACE}", "namespace": "${NAMESPACE}"}',
            '-openshift-delegate-urls={"/": {"resource": "namespaces", "verb": "get", "name": "${NAMESPACE}", "namespace": "${NAMESPACE}"}}',
            '-tls-cert=/etc/tls/private/tls.crt',
            '-tls-key=/etc/tls/private/tls.key',
            '-client-secret-file=/var/run/secrets/kubernetes.io/serviceaccount/token',
            '-cookie-secret-file=/etc/proxy/secrets/session_secret',
            '-openshift-ca=/etc/pki/tls/cert.pem',
            '-openshift-ca=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
          ],
          ports: [
            { name: name, containerPort: oap.config.ports[name] }
            for name in std.objectFields(oap.config.ports)
          ],
          volumeMounts: [
            { name: oap.config.tlsSecretName, mountPath: '/etc/tls/private', readOnly: false },
            { name: oap.config.sessionSecretName, mountPath: '/etc/proxy/secrets', readOnly: false },

          ],
          resources: oap.config.resources,
        }],
        volumes: [
          { name: oap.config.tlsSecretName, secret: { secretName: oap.config.tlsSecretName } },
          { name: oap.config.sessionSecretName, secret: { secretName: oap.config.sessionSecretName } },
        ],
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
