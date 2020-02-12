local obs = (import 'configuration/environments/openshift/obs.jsonnet');

{
  _config+:: {
    thanosReceiveControllerJobPrefix: obs.thanosReceiveController.service.metadata.name,
    thanosReceiveControllerSelector: 'job="%s"' % self.thanosReceiveControllerJobPrefix,
  },

  dashboard+:: {
    tags: ['thanos-mixin'],
    namespaceQuery: 'kube_pod_info',
  },
  overview+:: {
    title: '%(prefix)sOverview' % $.dashboard.prefix,
  },
  compactor+:: {
    jobPrefix: obs.compact.service.metadata.name,
    selector: 'job="%s"' % self.jobPrefix,
    title: '%(prefix)sCompactor' % $.dashboard.prefix,
  },
  querier+:: {
    jobPrefix: obs.query.service.metadata.name,
    selector: 'job="%s"' % self.jobPrefix,
    title: '%(prefix)sQuerier' % $.dashboard.prefix,
  },
  receiver+:: {
    jobPrefix: obs.receivers.default.service.metadata.name,
    selector: 'job=~"%s.*"' % self.jobPrefix,
    title: '%(prefix)sReceiver' % $.dashboard.prefix,
  },
  store+:: {
    jobPrefix: obs.store.service.metadata.name,
    selector: 'job="%s"' % self.jobPrefix,
    title: '%(prefix)sStore' % $.dashboard.prefix,

  },
  ruler+:: {
    jobPrefix: obs.rule.service.metadata.name,
    selector: 'job="%s"' % self.jobPrefix,
    title: '%(prefix)sRuler' % $.dashboard.prefix,
  },
}
