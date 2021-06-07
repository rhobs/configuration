# Red Hat Observability Service

This project holds the configuration files for our internal Red Hat Observability Service based on [Observatorium](https://github.com/observatorium/observatorium).

## Installing jsonnet dependencies

To install all dependencies:

```console
# Installs pinned versions from `jsonnetfile.lock.json` file.

jb install
```

To update a dependency:

```console
# Updates `kube-thanos` to master and sets the new hash in `jsonnetfile.lock.json`.
jb update https://github.com/thanos-io/kube-thanos/jsonnet/kube-thanos@main

# Update all dependancies to master and sets the new hashes in `jsonnetfile.lock.json`.
jb update
```

## Grafana dashboards

All dashboards are generated in `resources/observability/grafana` (legacy: `manifests/production/grafana`) with:

```console
make grafana
```

**Staging**: Update the commit hash ref in [`https://gitlab.cee.redhat.com/service/app-interface/blob/master/data/services/observability/cicd/saas/saas-grafana.yaml`](https://gitlab.cee.redhat.com/service/app-interface/blob/master/data/services/observability/cicd/saas/saas-grafana.yaml)

**Production**: Update the commit hash ref in [`https://gitlab.cee.redhat.com/service/app-interface/blob/master/data/services/observability/cicd/saas/saas-grafana.yaml`](https://gitlab.cee.redhat.com/service/app-interface/blob/master/data/services/observability/cicd/saas/saas-grafana.yaml)

## Prometheus Rules

Use `synchronize.sh` to create a MR against `app-interface` to update dashboards.

## Components - Deployments, ServiceMonitors, ConfigMaps etc...

All components manifests are generated in `resources/services` (legacy: `manifests/production/`) with:

```console
make manifests
```

**Staging**: update the commit hash ref in [`https://gitlab.cee.redhat.com/service/app-interface/blob/master/data/services/telemeter/cicd/saas.yaml`](https://gitlab.cee.redhat.com/service/app-interface/blob/master/data/services/telemeter/cicd/saas.yaml)

**Production**: update the commit hash ref in [`https://gitlab.cee.redhat.com/service/app-interface/blob/master/data/services/telemeter/cicd/saas.yaml`](https://gitlab.cee.redhat.com/service/app-interface/blob/master/data/services/telemeter/cicd/saas.yaml)

## CI Jobs

Jobs runs are posted in:

`#sd-app-sre-info` for grafana dashboards

and

`#team-monitoring-info` for everything else.

## Troubleshooting

1. Enable port forwarding for a user - [example](https://gitlab.cee.redhat.com/service/app-interface/-/blob/ee91aac666ee39a273332c59ad4bdf7e0f50eeba/data/teams/telemeter/users/fbranczy.yml#L14)
2. Add a pod name to the allowed list for port forwarding - [example](https://gitlab.cee.redhat.com/service/app-interface/-/blob/ee91aac666ee39a273332c59ad4bdf7e0f50eeba/resources/app-sre/telemeter-production/observatorium-allow-port-forward.role.yaml#L10)
