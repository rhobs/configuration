{
  dashboard+:: {
    tags: ['thanos-mixin'],
    namespaceQuery: 'kube_pod_info',
  },
  overview+:: {
    title: '%(prefix)sOverview' % $.dashboard.prefix,
  },
  compactor+:: {
    jobPrefix: 'thanos-compactor',
    selector: 'job="%s"' % self.jobPrefix,
    title: '%(prefix)sCompactor' % $.dashboard.prefix,
  },
  querier+:: {
    jobPrefix: 'thanos-querier',
    selector: 'job="%s"' % self.jobPrefix,
    title: '%(prefix)sQuerier' % $.dashboard.prefix,
  },
  receiver+:: {
    jobPrefix: 'thanos-receive',
    selector: 'job=~"%s.*"' % self.jobPrefix,
    title: '%(prefix)sReceiver' % $.dashboard.prefix,
  },
  store+:: {
    jobPrefix: 'thanos-store',
    selector: 'job="%s"' % self.jobPrefix,
    title: '%(prefix)sStore' % $.dashboard.prefix,

  },
  ruler+:: {
    jobPrefix: 'thanos-ruler',
    selector: 'job="%s"' % self.jobPrefix,
    title: '%(prefix)sRuler' % $.dashboard.prefix,
  },
}
