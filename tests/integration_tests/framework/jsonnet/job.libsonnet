local defaults = {
  local defaults = self,
  name: error 'must provide job name',
  namespaces: error 'must provide namespaces',
  interval: error 'must provide interval',
  timeout: error 'must provide timeout',
  image: error 'must provide image',
  imageTag: error 'must provide image tag',
  serviceAccountName: error 'must provide service account name',
  labels: {
    'app.kubernetes.io/component': 'test',
    'app.kubernetes.io/instance': 'rhobs-test',
    'app.kubernetes.io/name': defaults.name,
  },
};
function(params) {
  local job = self,
  config:: defaults + params,
  job: {
    apiVersion: 'batch/v1',
    kind: 'Job',
    metadata: {
      labels: job.config.labels,
      name: job.config.name,
    },
    spec: {
      template: {
        metadata: {
          labels: job.config.labels,
        },
        spec: {
          serviceAccountName: job.config.serviceAccountName,
          containers: [
            {
              args: [
                '--namespaces=' + job.config.namespaces,
                '--interval=' + job.config.interval,
                '--timeout=' + job.config.timeout,
              ],
              name: job.config.name,
              image: job.config.image + ':' + job.config.imageTag,
              resources: {},
              volumeMounts: [],
            },
          ],
          initContainers: [],
          restartPolicy: 'OnFailure',
          volumes: [],
        },
      },
      //backoffLimit: 4,
    },
  },
}
