# ROSA HCP Billing Metrics
There are a set of ROSA metrics that are federated from OBO into `telemeter-staging`, `telemeter-int` and `telemeter-prod`. These metrics are used for Subwatch billing of ROSA clusters via telemetry.   

The remote-write config can be found [here](https://gitlab.cee.redhat.com/service/osd-fleet-manager/-/blob/main/config/resources/managed-cluster-monitoring-stack.yaml). *Do not modify* without express approval from the ROSA team in the #sd-rosa-hcp channel.