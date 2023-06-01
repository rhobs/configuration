{
  instanceNamespace(name, metricsNamespace, upNamespace): if name == 'telemeter' then metricsNamespace else upNamespace,
  instance_name_filter: '/^rhobs.*|telemeter-prod-01-prometheus|app-sre-stage-01-prometheus/',
}
