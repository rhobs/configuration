# What

This template deploys [Thanos Bucket Replicate](https://thanos.io/tip/components/tools.md/#bucket-replicate)
as a Kubernetes Job or CronJob.

# SOP

> **_NOTE:_**  Before running this Job, if you wish to track progress via logs, 
you can run the [Thanos Bucket Inspect](../bucket-inspect/README.md#sop)
Job against the source and the CronJob against the destination to make sure that the source and destination
are in sync.
Logs are extra useful if you don't have access to the Prometheus metrics or the Job will complete before a scrape.

Create a Kubernetes Secret that contains the credentials for both the target and destination object storage 
provider or use the template provided in this directory for S3 compatible object storage providers.


```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: thanos-bucket-replicate-source-config
type: Opaque
stringData:
  config.yaml: |
    # see https://thanos.io/tip/thanos/storage.md/
---
apiVersion: v1
kind: Secret
metadata:
  name: thanos-bucket-replicate-destination-config
type: Opaque
stringData:
  config.yaml: |
    # see https://thanos.io/tip/thanos/storage.md/
```

Optionally create the PodMonitor to scrape Prometheus metrics from the Job

```bash
oc process -f monitoring-template.yaml | oc apply -f -
```

Process the template and run the Job

```bash
oc process -f job-template.yaml | oc apply -f -
```


Alternatively, you can run it as a CronJob
```bash
oc process -f cron-job-template.yaml | oc apply -f -
```
