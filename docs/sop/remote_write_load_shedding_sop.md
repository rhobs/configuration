# Purpose

This document can be used to methodically step through issues with Prometheus remote write into a RHOBS instance.

## Context

Due to the nature of Prometheus remote writes retry capabilities, it is possible for an internal failure to
quickly cascade into a larger failure of the whole system which can be difficult to overcome. The steps below
detail, from least pervasive to most pervasive, how to mitigate these issues.

For RHOBS, at a high level, the traffic in the form of a remote write request flows through the following components in order:
1. Prometheus.
2. OpenShift Routers (HAProxy).
3. Observatorium API.
4. Gubernator (rate limiting service).
5. Thanos Receive (remote write receiver).

## Prerequisites

1. Access to the Red Hat VPN.
2. Authorization to create an MR in [app-interface](https://gitlab.cee.redhat.com/service/app-interface).
3. Authorization to merge an MR in [app-interface](https://gitlab.cee.redhat.com/service/app-interface).
4. Access to Grafana.

## Related Alerts

The following alerts can be related to remote write issues:

1. [ThanosReceiveHttpRequestErrorRateHigh](https://github.com/rhobs/configuration/blob/main/docs/sop/observatorium.md#thanosreceivehttprequesterrorratehigh)
2. [APIMetricsWriteAvailabilityErrorBudgetBurning](https://github.com/rhobs/configuration/blob/main/docs/sop/observatorium.md#APIMetricsWriteAvailabilityErrorBudgetBurning)

## Incident Mitigation

Starting with Thanos Receive, the following steps can be taken to mitigate an incident:

* Ensure Thanos Receive is running and healthy.
  * Ensure the hashring is not being OOM killed.
    * If there are OOM events, check if traffic into the hashring has increased.
    * If there is an unexpected increase in traffic, rate limit accordingly on observatorium-api for the tenant.
    * If there is an expected increase in traffic, scale up the hashring with additional replicas.
  * Ensure the hashring is not being CPU throttled.
    * Check with the following promql expression: `rate(container_cpu_cfs_throttled_seconds_total{namespace=~"observatorium.*|rhobs", container="thanos-receive"}[5m])`
    * If there are CPU throttling events, check if traffic into the hashring has increased.
    * If there is an unexpected increase in traffic, rate limit accordingly on observatorium-api for the tenant.
    * If there is an expected increase in traffic, adjust the CPU limits accordingly in the StatefulSet spec.

Assuming Thanos Receive is healthy, the next step is to check API layer:

* Ensure observatorium-api and rate limiting is running and healthy.
    * Ensure the proxy is not being OOM killed.
        * If there are OOM events, check if traffic into the proxy has increased.
        * If there is an unexpected increase in traffic, rate limit accordingly.
        * If there is an expected increase in traffic, scale up the hashring.
    * Ensure the hashring is not being CPU throttled.
        * Check with the following promql expression: `rate(container_cpu_cfs_throttled_seconds_total{namespace=~"observatorium.*|rhobs", container=~"gubernator|observatorium-api"}[5m])`
        * If there are CPU throttling events, check if traffic into the remote write has increased.
        * If there is an unexpected increase in traffic, rate limit accordingly.
        * If there is an expected increase in traffic, adjust the CPU limits accordingly.

## Rate Limiting

Rate limiting is configured per tenant per path in   [saas-tenants.yaml](https://gitlab.cee.redhat.com/service/app-interface/-/blob/32c270cfe01c4d1d20826a80a0f3ea9db6dee619/data/services/rhobs/observatorium-mst/cicd/saas-tenants.yaml)
file in the app-interface repository.

The following example shows an example rate limiting configuration for the `rhobs` tenant on the metrics ingestion path:

```yaml
rateLimits:
  - endpoint: /api/metrics/v1/rhobs/api/v1/receive
    limit: 2700
    window: 45s
```

Limits and the window can be adjusted accordingly during an incident.

Additional control over the backoff can be configured like so:

```yaml
rateLimits:
  - endpoint: /api/metrics/v1/rhobs/api/v1/receive
    limit: 2700
    window: 45s
    retryAfterMin: 30s
    retryAfterMax: 600s
```
These additional fields set the Retry-After header in the response to the client. The client will then backoff
accordingly, doubling the backoff time on each retry until the max is reached.


## Router Layer

If an incident has spread to the network edge and the HAProxy routers are being affected, there are a number of annotations
that can be added which may help the issue related to timeouts, concurrency and load. Annotations
should be added after assessment of the issue and their values set accordingly.

Visit the OpenShift router documentation [here](https://docs.openshift.com/container-platform/latest/networking/routes/route-configuration.html#nw-route-specific-annotations_route-configuration).

A Route may serve more than one tenant, and we would want to preserve behaviour for the non-problematic tenants
and maintain service. In such cases, an additional Route could be created allowing for the problematic tenant to be
matched and the annotations applied to that Route only.

For example, given the following Route:

```
kind: Route
apiVersion: route.openshift.io/v1
metadata:
  name: remote-write
  namespace: observatorium-testing
spec:
  host: remote-write.my-domain.com
  to:
    kind: Service
    name: observatorium-observatorium-api
    weight: 100
  port:
    targetPort: public
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  wildcardPolicy: None
 ``` 

and an incident caused by the `rhobs` tenant, we can create a Route that matches directly and
sets the concurrent connections to 1000:

```
kind: Route
apiVersion: route.openshift.io/v1
metadata:
  name: remote-write-rhobs
  namespace: observatorium-testing
  annotations:
    haproxy.router.openshift.io/rate-limit-connections: "true"
    haproxy.router.openshift.io/rate-limit-connections.concurrent-tcp: "1000"
spec:
  host: remote-write.my-domain.com
  path: /api/metrics/v1/rhobs/api/v1/receive  
  to:
    kind: Service
    name: observatorium-observatorium-api
    weight: 100
  port:
    targetPort: public
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  wildcardPolicy: None
```
