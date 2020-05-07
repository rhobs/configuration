# observatorium/configuration

This projects holds all the configuration files for our internal Observatorium deployments.

Files in the `manifest` folder are deployed to staging automatically and
for production bump the commit hash in the [`saas-telemeter`](https://gitlab.cee.redhat.com/service/saas-telemeter/merge_requests/173/diffs) repo.

Updates to files in the `resource` folder need be manually coppied over to the [`app-interface`](https://gitlab.cee.redhat.com/service/app-interface/merge_requests/3907/diffs) repo.

## Updating the openshift manifests and the files in the resource folder.
```
make   --always-make
```



### Syncing upstream changes for the jsonnet dependancies.
```
jb install https://ur/org/repo@commitHash
```
Example:
```
jb install https://github.com/observatorium/configuration@d1516bace8da3386af5d8a2e6effed21e37984ea
```


