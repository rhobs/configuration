package rhobs

import (
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/compactor"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/store"
	"github.com/observatorium/observatorium/configuration_go/schemas/thanos/common"
	"github.com/rhobs/configuration/services_go/observatorium"
)

func ClusterConfigs() []observatorium.InstanceConfiguration {
	return []observatorium.InstanceConfiguration{
		{
			Cluster:        "app-sre-stage-01",
			Namespace:      "rhobs",
			Instance:       "rhobs",
			ObjStoreSecret: "telemeter-tenant-s3",
			Tenants:        []observatorium.TenantInstanceConfiguration{},
			PreManifestsHooks: observatorium.PreManifestsHooks{
				ThanosStore: func(store *store.StoreStatefulSet) {
					store.Replicas = 2
					store.Options.LogLevel = common.LogLevelInfo
				},
				Compactor: func(compactor *compactor.CompactorStatefulSet) {
					compactor.Options.LogLevel = common.LogLevelInfo
				},
			},
		},
		{
			Cluster:        "telemeter-prod-01",
			Namespace:      "rhobs",
			Instance:       "rhobs",
			ObjStoreSecret: "telemeter-tenant-s3",
			Tenants:        []observatorium.TenantInstanceConfiguration{},
			PreManifestsHooks: observatorium.PreManifestsHooks{
				ThanosStore: func(store *store.StoreStatefulSet) {
					store.Replicas = 3
				},
			},
		},
	}
}
