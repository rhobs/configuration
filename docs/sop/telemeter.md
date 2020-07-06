# SOP : OpenShift Telemeter

<!-- TOC depthTo:2 -->

- [SOP : OpenShift Telemeter](#sop--openshift-telemeter)
    - [Verify it's working](#verify-its-working)
    - [AuthorizeClientErrorsHigh](#authorizeclienterrorshigh)
    - [OAuthClientErrorsHigh](#oauthclienterrorshigh)
    - [TelemeterDown](#telemeterdown)
    - [UploadHandlerErrorsHigh](#uploadhandlererrorshigh)
    - [Escalations](#escalations)

<!-- /TOC -->

---

## Verify it's working

- `telemeter-server` targets are UP in info-gw: https://infogw-data.api.openshift.com/targets#job-telemeter-server
- `telemeter-server` targets are UP in app-sre prom: https://prometheus.app-sre.devshift.net/targets#job-telemeter-server
- `Upload Handler` is returning 200s: https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADJ/telemeter?orgId=1&from=now-6h&to=now

## AuthorizeClientErrorsHigh

### Impact:

New clusters are not able to fetch an authorization token.
We are lucky if clusters are already authorized.
We issue clusters inside telemeter a JWT token for 12 hours.
All existing clusters will be okay for 12h window since last authorized.

The error is related to clusters which are either:
- New clusters trying to authorize.
- Existing clusters who already have authorized,
but the 12h window for the token has expired

### Summary:

Telemeter is recieving errors at a high rate from Tollbooth

### Access required:

- Console access to the cluster that runs telemeter (Currently app-sre OSD)
- Edit access to the Telemeter namespaces:
    - telemeter-stage
    - telemeter-production

### Steps:

- Contact Tollbooth team, investigate why Tollbooth is failing to authorize cluster IDs.

---

## OAuthClientErrorsHigh

### Impact:

Clusters are not able to fetch a new authorization token or renew it.

### Summary:

Telemeter server itself uses OAuth to authorize against tollbooth.
It uses an access token, issued by RedHat's OAuth server (Keycloak).
Telemeter is receiving error responses when trying to refresh the access token
at a high rate from Keycloak.

### Access required:

- Console access to the cluster that runs telemeter (Currently app-sre OSD)
- Edit access to the Telemeter namespaces:
    - telemeter-stage
    - telemeter-production

### Relevant secrets:

### Steps:

- Contact Keycloak team, investigate why Keycloack is failing to authorize Telemeter server.

---

## TelemeterDown

### Impact:

Clusters are not able to push metrics.

### Summary:

Telemeter Server is down and not serving any requests.

### Access required:

- Console access to the cluster that runs telemeter (Currently app-sre OSD)
- Edit access to the Telemeter namespaces:
    - telemeter-stage
    - telemeter-production### Severity: Critical

### Steps:

- Contact monitoring engineering team to help in the investigation.
- Investigate failure of Telemeter server.
- Check Telemeter server logs.

---

## UploadHandlerErrorsHigh

### Impact:

Clusters are not able to push metrics.

### Summary:

Upload errors happen, when metrics data is malformed or validation of metrics fails.
Most likely the metrics payload is broken and thus possibly the telemeter metrics client.

### Access required:

- Console access to the cluster that runs telemeter (Currently app-sre OSD)
- Edit access to the Telemeter namespaces:
    - telemeter-stage
    - telemeter-production


### Relevant secrets:

### Steps:

- Contact monitoring engineering team to help in the investigation.
- Examine metrics payload by enabling the --verbose setting on telemeter client
on a cluster that is failing to push metrics.
- To enable telemeter client verbosity on a given cluster, execute the following steps:

1. Open the Observatorium [Thanos Overview dashboard](https://grafana.app-sre.devshift.net/d/0cb8830a6e957978796729870f560cda/thanos-overview?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-interval=5m&from=now-3h&to=now) and look for elevated errors in each section. The alert name and each section on the Grafana dashboard correlates to a particular Deployment or StatefulSet.
2. Once you've identified the section, you can drill down into a more specific dashboard in the Observatorium Grafana folder. For example, elevated rates in Receive section of the Overview board should have you referencing the [Thanos Receive dashboard](https://grafana.app-sre.devshift.net/d/916a852b00ccc5ed81056644718fa4fb/thanos-receive?orgId=1&refresh=10s&var-datasource=telemeter-prod-01-prometheus&var-namespace=telemeter-production&var-job=All&var-pod=All&var-interval=5m&from=now-3h&to=now).
3. Using the alert name to extract the Deployment or StatefulSet name on the cluster, you can now begin to debug the containers on the cluster. Check logs to see what's happened. If the telemeter team has engineering available, allow them the time to debug the container to find a root cause. If they are not available, replace the pod. Note that StatefulSets require more time to shutdown and require the necessary stoage quota to be replaced.

---

## TelemeterCapacity[Medium | High | Critical]

### Impact:

Telemeter Prometheus may not be able to handle the total number of active timeseries and may crash.

### Summary:

Telemeter Prometheus is reaching to its limit of active timeseries and will be unable to handle the load. Soon Telemeter Prometheus may crash.

### Access required:

- Console access to the cluster that runs telemeter (Currently app-sre OSD)
- Edit access to the Telemeter namespaces:
    - telemeter-stage
    - telemeter-production### Severity: Critical

### Steps:

- Contact monitoring engineering team for help.
- Inspect Telemeter Prometheus logs and metrics.
- Reduce the whitelisted metrics and labels on telemeter-server so that fewer metrics are accepted and Prometheus can handle the load.

---

## Escalations
We want a link to app-interface here, but okay to just contacts here for now.
