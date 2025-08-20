# Red Hat Observability Service

This project holds the configuration files for our internal Red Hat Observability Service based on [Observatorium](https://github.com/observatorium/observatorium).

See our [website](https://rhobs-handbook.netlify.app/) for more information about RHOBS.

## Requirements

* Go 1.17+

### macOS

* findutils (for GNU xargs)
* gnu-sed

Both can be installed using Homebrew: `brew install gnu-sed findutils`. Afterwards, update the `SED` and `XARGS` variables in the Makefile to use `gsed` and `gxargs` or replace them in your environment.

## Usage

This repository contains [Jsonnet](https://jsonnet.org/) configuration that allows generating Kubernetes objects that compose RHOBS service and its observability.

### RHOBS service

The jsonnet files for RHOBS service can be found in [services](./services) directory. In order to compose *RHOBS Service* we import many Jsonnet libraries from different open source repositories including [kube-thanos](https://github.com/thanos-io/kube-thanos) for Thanos components, [Observatorium](https://github.com/observatorium/observatorium) for Observatorium, Minio, Memcached, Gubernator, Dex components, [thanos-receive-controller](https://github.com/observatorium/thanos-receive-controller) for Thanos receive controller component, [parca](https://github.com/parca-dev/parca) for Parca component, [observatorium api](https://github.com/observatorium/api) for API component, [observatorium up](https://github.com/observatorium/up) for up component,  [rules-objstore](https://github.com/observatorium/rules-objstore) for rules-objstore component.

Currently, RHOBS components are rendered as [OpenShift Templates](https://docs.openshift.com/container-platform/latest/openshift_images/using-templates.html) that allows parameters. This is how we deploy to multiple clusters, sharing the same configuration core, but having different details like resources or names.

> This is why there might be a gap between vanilla [Observatorium](https://github.com/observatorium/observatorium) and RHOBS. We have plans to resolve this gap in the future.

Running `make manifests` generates all required files into [resources/services](./resources/services) directory.

### Unified Templates

Some services use unified, environment-agnostic templates that can be deployed across all environments using template parameters. For example, the synthetics-api service provides a single template that works for all environments:

```bash
# Generate unified synthetics-api template
mage unified:syntheticsApi

# Generate all unified templates
mage unified:all

# List available unified templates
mage unified:list

# Deploy to different environments using parameters
oc process -f resources/services/synthetics-api-template.yaml \
  -p NAMESPACE=rhobs-stage \
  -p IMAGE_TAG=latest | oc apply -f -

oc process -f resources/services/synthetics-api-template.yaml \
  -p NAMESPACE=rhobs-production \
  -p IMAGE_TAG=v1.0.0 | oc apply -f -
```

This approach reduces template duplication and ensures consistency across environments while maintaining deployment flexibility.

### Observability

Similarly, in order to have observability (alerts, recording rules, dashboards) for our service we import mixins from various projects and compose all together in [observability](./observability) directory.

Running `make prometheusrules grafana` generates all required files into [resources/observability](./resources/observability) directory.

### Updating Dependencies

Up-to-date list of jsonnet dependencies can be found in [jsonnetfile.json](./jsonnetfile.json). Fetching all deps is done through `make vendor_jsonnet` utility.

To update a dependency, normally the process would be:

```console
make vendor_jsonnet # This installs dependencies like `jb` thanks to Bingo project.
JB=`ls $(go env GOPATH)/bin/jb-* -t | head -1`

# Updates `kube-thanos` to master and sets the new hash in `jsonnetfile.lock.json`.
$JB update https://github.com/thanos-io/kube-thanos/jsonnet/kube-thanos@main

# Update all dependancies to master and sets the new hashes in `jsonnetfile.lock.json`.
$JB update
```

## Testing cluster

The purpose of [RHOBS testing cluster](https://console-openshift-console.apps.rhobs-testing.qqzf.p1.openshiftapps.com/dashboards) is to
experiment before changes are rolled out to staging and production environments. The objects in the cluster are managed by app-interface, however the testing cluster uses a different set of namespaces - `observatorium{-logs,-metrics,-traces}-testing`.

Changes can be applied to the cluster manually, however they will be overridden by app-interface during the next deployment cycle.

### Refresh token

The refresh token can be obtained via [token-refresher](https://github.com/observatorium/token-refresher).

```bash
./token-refresher --url=https://observatorium.apps.rhobs-testing.qqzf.p1.openshiftapps.com  --oidc.client-id=observatorium-rhobs-testing  --oidc.client-secret=<token> --log.level=debug --oidc.issuer-url=https://sso.redhat.com/auth/realms/redhat-external --oidc.audience=observatorium-telemeter-testing --file /tmp/token
cat /tmp/token
```

## App Interface

Our deployments our managed by our Red Hat AppSRE team.

### Updating Dashboards

**Staging**: Once the PR containing the dashboard changes is merged to `main` it goes directly to stage environment - because the `telemeter-dashboards` resourceTemplate refers the `main` branch [here](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/services/rhobs/telemeter/cicd/saas.yaml).

**Production**: Update the commit hash ref in [the saas file](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/data/services/rhobs/telemeter/cicd/saas.yaml) in the `telemeterDashboards` resourceTemplate, for production environment.

### Prometheus Rules and Alerts

Use `synchronize.sh` to create a MR against `app-interface` to update dashboards.

### Components - Deployments, ServiceMonitors, ConfigMaps etc...

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
