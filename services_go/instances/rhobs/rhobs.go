package rhobs

import (
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/receive"
	"github.com/rhobs/configuration/services_go/observatorium"
)

func ClusterConfigs() []observatorium.Observatorium {
	return []observatorium.Observatorium{
		{
			Cluster:  "app-sre-stage-01",
			Instance: "rhobs",
			MetricsInstances: []observatorium.ObservatoriumMetrics{
				{
					InstanceName:              "default",
					Namespace:                 "rhobs",
					ThanosImageTag:            "v0.32.4",
					ObjStoreSecret:            "default-tenant-s3",
					ReceiveControllerImageTag: "main-2023-09-22-f168dd7",
					ReceiveLimits: receive.ReceiveLimitsConfig{
						WriteLimits: receive.WriteLimitsConfig{
							DefaultLimits: receive.DefaultLimitsConfig{
								RequestLimits: receive.RequestLimitsConfig{
									SamplesLimit: 100000,
								},
							},
						},
					},
				},
				{
					InstanceName:              "rhel",
					Namespace:                 "rhobs",
					ThanosImageTag:            "v0.32.4",
					ObjStoreSecret:            "rhel-tenant-s3",
					ReceiveControllerImageTag: "main-2023-09-22-f168dd7",
				},
				{
					InstanceName:              "telemeter",
					Namespace:                 "rhobs",
					ThanosImageTag:            "v0.32.4",
					ObjStoreSecret:            "telemeter-tenant-s3",
					ReceiveControllerImageTag: "main-2023-09-22-f168dd7",
				},
			},
		},
		{
			Cluster:  "telemeter-prod-01",
			Instance: "rhobs",
			MetricsInstances: []observatorium.ObservatoriumMetrics{
				{
					InstanceName:              "default",
					Namespace:                 "rhobs",
					ThanosImageTag:            "v0.32.4",
					ObjStoreSecret:            "default-tenant-s3",
					ReceiveControllerImageTag: "main-2023-09-22-f168dd7",
				},
				{
					InstanceName:              "rhel",
					Namespace:                 "rhobs",
					ThanosImageTag:            "v0.32.4",
					ObjStoreSecret:            "rhel-tenant-s3",
					ReceiveControllerImageTag: "main-2023-09-22-f168dd7",
				},
				{
					InstanceName:              "telemeter",
					Namespace:                 "rhobs",
					ThanosImageTag:            "v0.32.4",
					ObjStoreSecret:            "telemeter-tenant-s3",
					ReceiveControllerImageTag: "main-2023-09-22-f168dd7",
				},
			},
		},
	}
}
