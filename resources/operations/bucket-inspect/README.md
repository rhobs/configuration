# What

This template deploys [Thanos Bucket Inspect](https://thanos.io/tip/components/tools.md/#bucket-insepct)
as a Kubernetes Job or CronJob.

# SOP

Create a Kubernetes Secret that contains the credentials for the target object storage provider, or use the
template provided in this directory for S3 compatible object storage providers.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: thanos-bucket-inspect-config
type: Opaque
stringData:
  from-config.yaml: |
    # see https://thanos.io/tip/thanos/storage.md/
```

Process the template and run the Job

```bash
oc process -f job-template.yaml | oc apply -f -
```

Alternatively, you can run it as a CronJob
```bash
oc process -f cron-job-template.yaml | oc apply -f -
```
