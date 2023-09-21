package rhobs

import (
	"github.com/rhobs/configuration/services_go/observatorium"
)

func ClusterConfigs() []observatorium.InstanceConfiguration {
	return []observatorium.InstanceConfiguration{
		{
			Cluster:   "app-sre-stage-01",
			Namespace: "rhobs",
			Instance:  "rhobs",
			Tenants:   []observatorium.TenantInstanceConfiguration{},
		},
		{
			Cluster:   "telemeter-prod-01",
			Namespace: "rhobs",
			Instance:  "rhobs",
			Tenants:   []observatorium.TenantInstanceConfiguration{},
		},
	}
}
