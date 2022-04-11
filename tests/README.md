## Deploying RHOBS for testing

This directory includes extra resources that make it possible to deploy RHOBS in any OpenShift cluster for testing. The objects and dependencies that are normally provided by external infrastructure are replaced by a local version:
- [AppSRE Interface](https://gitlab.cee.redhat.com/service/app-interface/), which provides additional objects like secrets and service accounts is replaced by manifests in this `test` directory
- [Red Hat External SSO](https://sso.redhat.com/auth/realms/redhat-external), which serves as an OIDC provider, is replaced by a local installation of [dex](https://dexidp.io/)
- The object storage, normally provided by S3, is replaced by a local installation of [minio](https://min.io/)

The deployment is self-contained in single namespace provided as parameter to `launch.sh deploy` script.

In addition to replacing external dependencies, the `launch.sh` script also includes parameters to [override default OpenShift template parameters](https://docs.openshift.com/container-platform/4.9/openshift_images/using-templates.html#templates-cli-generating-list-of-objects_using-templates). The purpose of this is to override parameters in order to make the deployments suitable for testing, in particular:
- The CPU / memory limits / requests are decreased so that RHOBS can be deployed on smaller clusters as well
- The number of replicas for components is decreased as well in order for the deployment to not be too resources heavy
- Some further object names (e.g. service accounts and images) are replaced to work with local alternatives of the external dependencies
- Namespace name changes so all can be deployed in one namespace.

The parameter files can be edited accordingly to accommodate your specific testing scenario.

### Requirements.

* OpenShift cluster available.
* [oc](https://docs.openshift.com/container-platform/4.7/cli_reference/openshift_cli/getting-started-cli.html) CLI installed.

### How to

To deploy the RHOBS stack on a cluster, use the `launch.sh` script from within this directory. Run:

```bash
./launch.sh deploy <your testing namespace>
```

This will create all the necessary namespaces and other resources for you.

To tear down the installation, run:

```bash
./launch.sh teardown <your testing namespace>
```

This will delete all RHOBS resources for you.

### NOTE: Minio, Dex Templates

Some templates like `minio-template.yaml` and `dex-template.yaml` are generated in `make manifests` process. Any manual edition to this will be removed after that command.

### Additional information.

Currently, not every RHOBS OpenShift template is being processed and deployed - only the 'core' parts of RHOBS are included within the testing deployment at the moment. This includes `observatorium`, `observatorium-metrics` and `telemeter` namespaces (each based on its respective template).

The test deployment also does not take care of exposing services. This is left up to the user, to expose the services in a fashion suitable for the given test scenario - whether this done by using the `oc expose` command or by port forwarding to a given service / pod via `oc port-forward`.