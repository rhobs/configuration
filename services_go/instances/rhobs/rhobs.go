package rhobs

import (
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/compactor"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/store"
	"github.com/rhobs/configuration/services_go/observatorium"
)

func ClusterConfigs() []observatorium.Observatorium {
	return []observatorium.Observatorium{
		{
			Cluster:        "app-sre-stage-01",
			Namespace:      "rhobs",
			Instance:       "rhobs",
			ThanosImageTag: "v0.32.4",
			Stores: []observatorium.ThanosTenantConfig[store.StoreStatefulSet]{
				{
					Tenant:         "default",
					ObjStoreSecret: "default-tenant-s3",
				},
				{
					Tenant:         "rhel",
					ObjStoreSecret: "rhel-tenant-s3",
				},
				{
					Tenant:         "telemeter",
					ObjStoreSecret: "telemeter-tenant-s3",
				},
			},
			Compactors: []observatorium.ThanosTenantConfig[compactor.CompactorStatefulSet]{
				{
					Tenant:         "default",
					ObjStoreSecret: "default-tenant-s3",
				},
				{
					Tenant:         "rhel",
					ObjStoreSecret: "rhel-tenant-s3",
				},
				{
					Tenant:         "telemeter",
					ObjStoreSecret: "telemeter-tenant-s3",
				},
			},
		},
		{
			Cluster:        "telemeter-prod-01",
			Namespace:      "rhobs",
			Instance:       "rhobs",
			ThanosImageTag: "v0.32.4",
			Stores: []observatorium.ThanosTenantConfig[store.StoreStatefulSet]{
				{
					Tenant:         "default",
					ObjStoreSecret: "default-tenant-s3",
				},
				{
					Tenant:         "rhel",
					ObjStoreSecret: "rhel-tenant-s3",
				},
				{
					Tenant:         "telemeter",
					ObjStoreSecret: "telemeter-tenant-s3",
				},
			},
			Compactors: []observatorium.ThanosTenantConfig[compactor.CompactorStatefulSet]{
				{
					Tenant:         "default",
					ObjStoreSecret: "default-tenant-s3",
				},
				{
					Tenant:         "rhel",
					ObjStoreSecret: "rhel-tenant-s3",
				},
				{
					Tenant:         "telemeter",
					ObjStoreSecret: "telemeter-tenant-s3",
				},
			},
		},
	}
}
