## Deploying RHOBS for testing

This directory includes extra resources that make it possible to deploy RHOBS in any OpenShift cluster for testing. The objects and dependencies that are normally provided by external infrastructure are replaced by a local version:
- [AppSRE Interface](https://gitlab.cee.redhat.com/service/app-interface/), which provides additional objects like secrets and service accounts is replaced by manifests in this `test` directory
- [Red Hat External SSO](https://sso.redhat.com/auth/realms/redhat-external), which serves as an OIDC provider, is replaced by a local installation of [dex](https://dexidp.io/)
- The object storage, normally provided by S3, is replaced by a local installation of [minio](https://min.io/)

In addition to replacing external dependencies, this directory also includes files to [override default OpenShift template parameters](https://docs.openshift.com/container-platform/4.9/openshift_images/using-templates.html#templates-cli-generating-list-of-objects_using-templates). These files have filename `<namespace>.test.env` and are namespace-specific. The purpose of this is to override parameters in order to make the deployments suitable for testing, in particular:
- The CPU / memory limits / requests are decreased so that RHOBS can be deployed on smaller clusters as well
- The number of replicas for components is decreased as well in order for the deployment to not be too resources heavy
- Some further object names (e.g. service accounts, images, secrets and storage-class) are replaced to work with local alternatives of the external dependencies
- rhelemeter template that require external certs are replaced by dummy generated ones.

These parameter files can be edited accordingly to accomodate your specific testing scenario.

The `storage-class` can be changed depending upon the platform on which OpenShift cluster is running (aws, gcp, azure etc.)
### How to
To deploy the RHOBS stack on a cluster, use the `launch.sh` script from within this directory: 

```bash
./launch.sh deploy
```

This will create all the necessary namespaces and other resources for you.

To tear down the installation:

```bash
./launch.sh teardown
```

This will delete all namespaces and crd's for you.

### Additional information
Currently, below RHOBS OpenShift templates are being processed and deployed:
- `jaeger`
- `metric-federation-rule`
- `observatorium-logs`
- `observatorium-metrics`
- `observatorium`
- `parca`
- `telemeter`
- `observatorium-tools` 
> :bulb: The launch script will take care of deploying necessary dependencies for `observatorium-tools` namespace like Logging Operator, Loki Operator, etc.

For optimal use it is recommended to use a OpenShift cluster with more resources.

The test deployment also does not take care of exposing services. This is left up to the user, to expose the services in a fashion suitable for the given test scenario - whether this done by using the `oc expose` command or by port forwarding to a given service / pod via `oc port-forward`.