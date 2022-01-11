## Deploying RHOBS for testing

This directory includes extra resources that make it possible to deploy RHOBS in any OpenShift cluster for testing. The objects and dependencies that are normally provided by external infrastructure are replaced by a local version:
- [AppSRE Interface](https://gitlab.cee.redhat.com/service/app-interface/), which provides additional objects like secrets and service accounts is replaced by manifests in this `test` directory
- [Red Hat External SSO](https://sso.redhat.com/auth/realms/redhat-external), which serves as an OIDC provider, is replaced by a local installation of [dex](https://dexidp.io/)
- The object storage, normally provided by S3, is replaced local installation of [minio](https://min.io/)

In addition to replacing external dependcies, this directory also includes files to [override default OpenShift template parameters](https://docs.openshift.com/container-platform/4.9/openshift_images/using-templates.html#templates-cli-generating-list-of-objects_using-templates). These files have filename `<namespace>.test.env` and are namespace-specific. The purpose of this is to override parameters in order to make the deployments suitable for testing, in particular:
- The CPU / memory limits / requests are overriden so that RHOBS can be deployed on smaller clusters as well
- The number of replicas for components is decreased as well in order for the deployment to not be too resources heavy
- Some further object names (e.g. service accounts and images) are replaced to work with local alternatives of the external dependencies.

The parameter files can be edited accordingly to accomodate your specific testing scenario.

### How to
To deploy the RHOBS stack on a cluster, use the `launch.sh` script from within this directory. Run:

```bash
./launch.sh deploy
```

This will create all the necessary namespaces and other resources for you.

To tear down the installation, run:
```bash
./launch.sh teardown
```
This will delete all RHOBS namespaces for you.

### Additional information
Currently, not every RHOBS OpenShift template is being processed and deployed - only the 'core' parts of RHOBS are included within the testing deployment at the moment. This includes `observatorium`, `observatorium-metrics` and `telemeter` namespaces (each based on its respective template).

The test deployment also does not take care of exposing services. This is left up to the user, to expose the services in a fashion suitable for the given test scenario - whether this done by using the `oc expose` command or by port forwarding to a given service / pod via `oc port-forward`.