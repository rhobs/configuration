# Purpose

Use this template to remove a tenant from a particular RHOBS instance.

## Context

Below are some typical scenarios where removing a tenant would be necessary:

1. The tenant is no longer using the RHOBS instance and the tenant needs to be removed as part of the decommissioning process.
2. The tenant is moving to a different RHOBS instance and the tenant needs to be removed from the current RHOBS instance.
3. The tenant is overloading the cluster and the tenant needs to be removed from the current RHOBS instance in order to reduce the load on the cluster.

## Prerequisites

1. Access to the Red Hat VPN.
2. Authorization to create an MR in [app-interface](https://gitlab.cee.redhat.com/service/app-interface).
3. Authorization to merge an MR in [app-interface](https://gitlab.cee.redhat.com/service/app-interface).


## How to remove a tenant

1. Browse to the [saas-tenants.yaml](https://gitlab.cee.redhat.com/service/app-interface/-/blob/32c270cfe01c4d1d20826a80a0f3ea9db6dee619/data/services/rhobs/observatorium-mst/cicd/saas-tenants.yaml) file in the app-interface repository.
2. Remove the tenant configuration as defined by [observatorium-api](https://github.com/observatorium/api/blob/8d0fd162a6d909a87e248c2b2d646db2f43f4214/main.go#L199-L244) from the appropriate section of the file.
3. Create an MR in [app-interface](https://gitlab.cee.redhat.com/service/app-interface) to remove the tenant. Once the MR is merged, the tenant will be removed from the RHOBS instance.
4. Verify that the tenant can no longer read or write data to the RHOBS instance.
