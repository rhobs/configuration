# SOP : OpenShift Telemeter

<!-- TOC depthTo:2 -->

- [SOP : OpenShift Telemeter](#sop--openshift-telemeter)
  - [Verify it's working](#verify-its-working)
  - [AuthorizeClientErrorsHigh](#authorizeclienterrorshigh)
    - [Impact:](#impact)
    - [Summary:](#summary)
    - [Access required:](#access-required)
    - [Steps:](#steps)
  - [TelemeterAuthorizeErrorBudgetBurning](#telemeterauthorizeerrorbudgetburning)
  - [OAuthClientErrorsHigh](#oauthclienterrorshigh)
    - [Impact:](#impact-1)
    - [Summary:](#summary-1)
    - [Access required:](#access-required-1)
    - [Relevant secrets:](#relevant-secrets)
    - [Steps:](#steps-1)
  - [TelemeterDown](#telemeterdown)
    - [Impact:](#impact-2)
    - [Summary:](#summary-2)
    - [Access required:](#access-required-2)
    - [Steps:](#steps-2)
  - [TelemeterUploadErrorBudgetBurning](#telemeteruploaderrorbudgetburning)
  - [UploadHandlerErrorsHigh](#uploadhandlererrorshigh)
    - [Impact:](#impact-3)
    - [Summary:](#summary-3)
    - [Access required:](#access-required-3)
    - [Relevant secrets:](#relevant-secrets-1)
    - [Steps:](#steps-3)
  - [TelemeterCapacity[Medium | High | Critical]](#telemetercapacitymedium--high--critical)
    - [Impact:](#impact-4)
    - [Summary:](#summary-4)
    - [Access required:](#access-required-4)
    - [Steps:](#steps-4)
  - [Escalations](#escalations)

<!-- /TOC -->

---

## Verify it's working

- `telemeter-server` targets are UP in info-gw: https://infogw-data.api.openshift.com/targets#job-telemeter-server
- `telemeter-server` targets are UP in `telemeter-prod-01` prom: https://prometheus.telemeter-prod-01.devshift.net/targets#job-telemeter-server
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

Telemeter is recieving errors at a high rate from Keycloak.

### Access required:

- Console access to the cluster that runs telemeter (Currently `telemeter-prod-01` OSD)
- Edit access to the Telemeter namespaces:
    - telemeter-stage
    - telemeter-production

### Steps:

1. Go to the [Telemeter dashboards](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADJ/telemeter?orgId=1&refresh=1m&from=now-3h&to=now) and check the /authorize errors. Are the error rates elevated?
1. Check if the issues come from us or upstream with this [Prometheus Query](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=3h&g0.expr=sum(rate(client_api_requests_total%7Bclient%3D%22authorize%22%2Cjob%3D%22telemeter-server%22%2Cnamespace%3D%22telemeter-production%22%2Cstatus%3D~%225..%22%7D%5B5m%5D))%20or%20vector(0)%0A%2F%0Asum(rate(client_api_requests_total%7Bclient%3D%22authorize%22%2Cjob%3D%22telemeter-server%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D))&g0.tab=0)
    1. If you see similar error rates here, compared to the Telemeter dashboard, then this is actually a Tollbooth problem. Please contact them for further troubleshooting.
    1. If you don't see any errors or significantly lower error rates, then the problems is most likely within Telemeter.
1. Check the logs for the Telemeter pods. Maybe networking is down?
1. If the problem persists then escalate to the Telemetry team to help in the investigation.

---

## TelemeterAuthorizeErrorBudgetBurning

Please check the [OAuthClientErrorsHigh](#telemeterauthorizeerrorbudgetburning) alert below!
Both alert on the same underlying symptoms.

_Note: Soon this new alert will replace the inferior one below._

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

- Console access to the cluster that runs telemeter (Currently `telemeter-prod-01` OSD)
- Edit access to the Telemeter namespaces:
    - telemeter-stage
    - telemeter-production

### Relevant secrets:

### Steps:

1. Go to the [Telemeter dashboards](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADJ/telemeter?orgId=1&refresh=1m&from=now-3h&to=now) and check the /authorize errors. Are the error rates elevated?
1. Check if the issues come from us or upstream with this [Prometheus Query](https://prometheus.telemeter-prod-01.devshift.net/graph?g0.range_input=3h&g0.expr=sum(rate(client_api_requests_total%7Bclient%3D%22oauth%22%2Cjob%3D%22telemeter-server%22%2Cnamespace%3D%22telemeter-production%22%2Cstatus%3D~%225..%22%7D%5B5m%5D))%20or%20vector(0)%0A%2F%0Asum(rate(client_api_requests_total%7Bclient%3D%22oauth%22%2Cjob%3D%22telemeter-server%22%2Cnamespace%3D%22telemeter-production%22%7D%5B5m%5D))&g0.tab=0)
    1. If you see similar error rates here, compared to the Telemeter dashboard, then this is actually a Tollbooth problem. Please contact them for further troubleshooting.
    1. If you don't see any errors or significantly lower error rates, then the problem is most likely within Telemeter.
1. Check the logs for the Telemeter pods. Maybe networking is down?
1. If the problem persists then escalate with [PagerDuty to the Telemetry](https://redhat.pagerduty.com/teams/PQL1RZA/subteams) team to help in the investigation.

---

## TelemeterDown

### Impact:

If Telemeter is down for too long, then OpenShift clusters are not able to push metrics anymore and we start losing data.
This may result in OCM showing erros and overall business metrics missing datapoints.

### Summary:

Telemeter Server might be down and not serving any requests.

### Access required:

- Console access to the cluster that runs telemeter (Currently `telemeter-prod-01` OSD)
- Edit access to the Telemeter namespaces:
    - telemeter-stage
    - telemeter-production### Severity: Critical

### Steps:


1. Check if this problem is visibile to the outside. Can you see elevated error rates on [the Telemeter dashboard](https://grafana.app-sre.devshift.net/d/Tg-mH0rizaSJDKSADJ/telemeter?orgId=1&refresh=1m&from=now-3h&to=now)?
1. Are there still Telemeter Pods? Are they crash looping? Are they ready? Check the OpenShift console for the `telemeter-production` namespace.
1. Check the [Prometheus target page](https://prometheus.telemeter-prod-01.devshift.net/targets). Are there are still `job="telemeter-server"` available?
    1. Check if Telemeter still answers on the port scraped for metrics (using port-forward to the internal port - while writing this it is`8081`).
    1. Check the logs - anything suspicious?
    1. Check the ServiceMonitors.
1. If the problem persists then escalate with [PagerDuty to the Telemetry](https://redhat.pagerduty.com/teams/PQL1RZA/subteams) team to help in the investigation.

---

## TelemeterUploadErrorBudgetBurning

Please check the [UploadHandlerErrorsHigh](#uploadhandlererrorshigh) alert below!
Both alert on the same underlying symptoms.

_Note: Soon this new alert will replace the inferior one below._

---

## UploadHandlerErrorsHigh

### Impact:

Clusters are not able to push metrics.

### Summary:

Upload errors happen, when metrics data is malformed or validation of metrics fails.
Most likely the metrics payload is broken and thus possibly the telemeter metrics client.

### Access required:

- Console access to the cluster that runs telemeter (Currently `telemeter-prod-01` OSD)
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

- Console access to the cluster that runs telemeter (Currently `telemeter-prod-01` OSD)
- Edit access to the Telemeter namespaces:
    - telemeter-stage
    - telemeter-production### Severity: Critical

### Steps:

- Contact monitoring engineering team for help.
- Inspect Telemeter Prometheus logs and metrics.
- Reduce the whitelisted metrics and labels on telemeter-server so that fewer metrics are accepted and Prometheus can handle the load.

---

## Escalations

Reach out to Observability Team (team-observability-platform@redhat.com), [`#forum-telemetry`](https://slack.com/app_redirect?channel=forum-telemetry) at CoreOS Slack.

TODO: We want a link to app-interface here, but okay to just contacts here for now.
