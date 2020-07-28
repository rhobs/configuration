# observatorium/configuration

This projects holds all the configuration files for our internal Observatorium deployments.

### Syncing upstream changes for the jsonnet dependancies.

```
jb update https://github.com/thanos-io/kube-thanos
```
This will update `kube-thanos` to latest master and set the hash in `jsonnetfile.lock.json`



## Manage Grafana dashboards

All dashboards are generated in `manifests/production/grafana` with:
```
make grafana
```

**Staging**: deploys on every commit master.

**Production**: update the commit hash ref in `https://gitlab.cee.redhat.com/service/app-interface/blob/master/data/services/observability/cicd/saas/saas-grafana.yaml`


## Manage components - Deployments, ServiceMonitors, ConfigMaps etc...

All components manifests are generated in `manifests/production/` with:
```
make manifests
```
**Staging**: deploys on every commit master.

**Production**: update the commit hash ref in `https://gitlab.cee.redhat.com/service/app-interface/blob/master/data/services/telemeter/cicd/saas.yaml`


## CI Jobs
deployment jobs runs are posted in `#sd-app-sre-info` for grafana dashboards and `#team-monitoring-info` for everyrhing else.



