# observatorium/configuration

This projects holds all the configuration files for our internal Observatorium deployments.

## Installing jsonnet dependencies.

To install all dependencies:
```
jb install
#installs pinned versions from `jsonnetfile.lock.json` file.
```

To update a dependency:
```
jb update https://github.com/thanos-io/kube-thanos
#updates `kube-thanos` to master and sets the new hash in `jsonnetfile.lock.json`.

jb update
#updates all dependancies to master and sets the new hashes in `jsonnetfile.lock.json`.
```

## Grafana dashboards

All dashboards are generated in `manifests/production/grafana` with:
```
make grafana
```

When adding or removing dashboards also need to edit:
https://gitlab.cee.redhat.com/service/app-sre-observability/-/blob/master/openshift/grafana.template.yaml
> this step will be automated soon https://issues.redhat.com/browse/APPSRE-2285

**Staging**: deploys on every commit master.

**Production**: update the commit hash ref in `https://gitlab.cee.redhat.com/service/app-interface/blob/master/data/services/observability/cicd/saas/saas-grafana.yaml`


## Components - Deployments, ServiceMonitors, ConfigMaps etc...

All components manifests are generated in `manifests/production/` with:
```
make manifests
```
**Staging**: deploys on every commit master.

**Production**: update the commit hash ref in `https://gitlab.cee.redhat.com/service/app-interface/blob/master/data/services/telemeter/cicd/saas.yaml`


## CI Jobs
Jobs runs are posted in:<br/>
`#sd-app-sre-info` for grafana dashboards <br/>
and <br/>
`#team-monitoring-info` for everyrhing else.



