local obs = (import 'obs.jsonnet');

{
  _config+:: {
    // TODO: Move this to the new style of selectors that kube-thanos uses
    thanosReceiveSelector: $.receive.selector,
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
  compact+:: {
    jobPrefix: obs.compact.service.metadata.name,
    selector: 'job="%s"' % self.jobPrefix,
    title: '%(prefix)sCompact' % $.dashboard.prefix,
  },
  query+:: {
    jobPrefix: obs.query.service.metadata.name,
    selector: 'job="%s"' % self.jobPrefix,
    title: '%(prefix)sQuery' % $.dashboard.prefix,
  },
  receive+:: {
    jobPrefix: obs.receivers.default.service.metadata.name,
    selector: 'job=~"%s.*"' % self.jobPrefix,
    title: '%(prefix)sReceive' % $.dashboard.prefix,
  },
  store+:: {
    jobPrefix: 'observatorium-thanos-store',
    selector: 'job=~"%s.*"' % self.jobPrefix,
    title: '%(prefix)sStore' % $.dashboard.prefix,
  },
  rule+:: {
    jobPrefix: obs.rule.service.metadata.name,
    selector: 'job="%s"' % self.jobPrefix,
    title: '%(prefix)sRule' % $.dashboard.prefix,
  },
}
