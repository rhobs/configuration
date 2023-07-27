local defaults = {
  namespace: error 'must provide namespace',
  configMapName: error 'must provide config map name',
  replicas: error 'must provide replicas',
  image: error 'must provide image',
  data:: {
    'prometheus.yml': "global:\n  scrape_interval:     15s\n  evaluation_interval: 15s\nscrape_configs:\n  - job_name: 'prometheus'\n    scrape_interval: 5s\n    static_configs:\n      - targets: ['localhost:9090']\n",
  },
  serviceName: error 'must provide service name',
  labels:: {
    app: 'prometheus-example-app',
  },
};
function(params) {
  local prom = self,
  config:: defaults + params,
  namespace: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: prom.config.namespace,
    },
  },
  configMap: {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: prom.config.configMapName,
      namespace: prom.config.namespace,
    },
    data: prom.config.data,
  },
  deployment: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      name: 'prometheus-example-app',
      labels: prom.config.labels,
      namespace: prom.config.namespace,
    },
    spec: {
      replicas: prom.config.replicas,
      selector: {
        matchLabels: {
          app: 'prometheus-example-app',
        },
      },
      template: {
        metadata: {
          labels: {
            app: 'prometheus-example-app',
          },
        },
        spec: {
          containers: [
            {
              name: 'prometheus-example-app',
              image: prom.config.image,
              args: [
                '--config.file=/etc/prometheus/prometheus.yml',
              ],
              ports: [
                {
                  name: 'http',
                  containerPort: 9090,
                },
              ],
              volumeMounts: [
                {
                  name: 'config',
                  mountPath: '/etc/prometheus',
                },
              ],
            },
          ],
          volumes: [
            {
              name: 'config',
              configMap: {
                name: prom.config.configMapName,
              },
            },
          ],
        },
      },
    },
  },
  service: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: prom.config.serviceName,
      labels: prom.config.labels,
      namespace: prom.config.namespace,
    },
    spec: {
      type: 'ClusterIP',
      ports: [
        {
          protocol: 'TCP',
          port: 9090,
          targetPort: 9090,
          name: 'http',


        },
      ],
      selector: {
        app: 'prometheus-example-app',
      },
    },
  },
}
