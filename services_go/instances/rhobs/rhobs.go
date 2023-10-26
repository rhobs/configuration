package rhobs

import (
	"sort"

	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/receive"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/store"
	"github.com/rhobs/configuration/services_go/observatorium"
)

const (
	metaMonitoringURL        = "http://prometheus-app-sre.openshift-customer-monitoring.svc.cluster.local:9090"
	metamonitoringLimitQuery = `sum(prometheus_tsdb_head_series{namespace="rhobs"}) by (tenant)`
)

type InstanceName string

const (
	DefaultInstanceName   InstanceName = "default"
	RhelInstanceName      InstanceName = "rhel"
	TelemeterInstanceName InstanceName = "telemeter"
)

var tenantsMapping = map[InstanceName]map[string]string{
	DefaultInstanceName: {
		"rhobs":           "0fc2b00e-201b-4c17-b9f2-19d91adc4fd2",
		"osd":             "770c1124-6ae8-4324-a9d4-9ce08590094b",
		"rhacs":           "1b9b6e43-9128-4bbf-bfff-3c120bbe6f11",
		"cnvqe":           "9ca26972-4328-4fe3-92db-31302013d03f",
		"psiocp":          "37b8fd3f-56ff-4b64-8272-917c9b0d1623",
		"rhods":           "8ace13a2-1c72-4559-b43d-ab43e32a255a",
		"odfms":           "99c885bc-2d64-4c4d-b55e-8bf30d98c657",
		"reference-addon": "d17ea8ce-d4c6-42ef-b259-7d10c9227e93",
		"dptp":            "AC879303-C60F-4D0D-A6D5-A485CFD638B8",
		"appsre":          "3833951d-bede-4a53-85e5-f73f4913973f",
		"rhtap":           "0031e8d6-e50a-47ea-aecb-c7e0bd84b3f1",
	},
	RhelInstanceName: {
		"rhel": "72e6f641-b2e2-47eb-bbc2-fee3c8fbda26",
	},
	TelemeterInstanceName: {
		"telemeter": "FB870BF3-9F3A-44FF-9BF7-D7A047A52F43",
	},
}

func ClusterConfigs() []observatorium.Observatorium {
	return []observatorium.Observatorium{
		stageConfig(),
		prodConfig(),
	}
}

func stageConfig() observatorium.Observatorium {
	tenants := map[string]observatorium.Tenants{
		"rhacs": {
			ReceiveLimits: &receive.WriteLimitConfig{
				HeadSeriesLimit: 10000000, // 10M
			},
		},
		"rhtap": {
			ReceiveLimits: &receive.WriteLimitConfig{
				HeadSeriesLimit: 200000, // 200k
			},
		},
		"rhel": {
			ReceiveLimits: &receive.WriteLimitConfig{
				RequestLimits: receive.RequestLimitsConfig{
					SeriesLimit: 10,
				},
			},
		},
	}

	return observatorium.Observatorium{
		Cluster:  "app-sre-stage-01",
		Instance: "rhobs",
		MetricsInstances: observatorium.ObservatoriumMetrics{
			Namespace:                 "rhobs",
			ThanosImageTag:            "v0.32.4",
			ReceiveControllerImageTag: "main-2023-09-22-f168dd7",
			ReceiveLimitsGlobal: receive.GlobalLimitsConfig{
				MetaMonitoringURL:        metaMonitoringURL,
				MetaMonitoringLimitQuery: metamonitoringLimitQuery,
			},
			ReceiveLimitsDefault: receive.DefaultLimitsConfig{
				RequestLimits: receive.RequestLimitsConfig{
					SeriesLimit:    5000,
					SamplesLimit:   5000,
					SizeBytesLimit: 0,
				},
				HeadSeriesLimit: 100000, // 100k
			},
			Instances: []*observatorium.ObservatoriumMetricsInstance{
				{
					InstanceName:   string(DefaultInstanceName),
					ObjStoreSecret: "default-tenant-s3",
					Tenants:        buildTenants(tenants, DefaultInstanceName),
					ReceiveIngestorPreManifestsHook: func(ingestor *receive.Ingestor) {
						ingestor.VolumeSize = "5Gi"
					},
					StorePreManifestsHook: func(store *store.StoreStatefulSet) {
						store.VolumeSize = "5Gi"
					},
				},
				{
					InstanceName:   string(RhelInstanceName),
					ObjStoreSecret: "rhelemeter-tenant-s3",
					Tenants:        buildTenants(tenants, RhelInstanceName),
					ReceiveIngestorPreManifestsHook: func(ingestor *receive.Ingestor) {
						ingestor.VolumeSize = "5Gi"
					},
					StorePreManifestsHook: func(store *store.StoreStatefulSet) {
						store.VolumeSize = "5Gi"
					},
				},
				{
					InstanceName:   string(TelemeterInstanceName),
					ObjStoreSecret: "telemeter-tenant-s3",
					Tenants:        buildTenants(tenants, TelemeterInstanceName),
					ReceiveIngestorPreManifestsHook: func(ingestor *receive.Ingestor) {
						ingestor.VolumeSize = "5Gi"
					},
					StorePreManifestsHook: func(store *store.StoreStatefulSet) {
						store.VolumeSize = "5Gi"
					},
				},
			},
		},
	}
}

func prodConfig() observatorium.Observatorium {
	tenants := map[string]observatorium.Tenants{
		"rhacs": {
			ReceiveLimits: &receive.WriteLimitConfig{
				HeadSeriesLimit: 10000000, // 10M
			},
		},
		"rhtap": {
			ReceiveLimits: &receive.WriteLimitConfig{
				HeadSeriesLimit: 200000, // 200k
			},
		},
		"rhel": {
			ReceiveLimits: &receive.WriteLimitConfig{
				RequestLimits: receive.RequestLimitsConfig{
					SeriesLimit: 10,
				},
			},
		},
	}

	return observatorium.Observatorium{
		Cluster:  "telemeter-prod-01",
		Instance: "rhobs",
		MetricsInstances: observatorium.ObservatoriumMetrics{
			Namespace:                 "rhobs",
			ThanosImageTag:            "v0.32.4",
			ReceiveControllerImageTag: "main-2023-09-22-f168dd7",
			ReceiveLimitsGlobal: receive.GlobalLimitsConfig{
				MetaMonitoringURL:        metaMonitoringURL,
				MetaMonitoringLimitQuery: metamonitoringLimitQuery,
			},
			Instances: []*observatorium.ObservatoriumMetricsInstance{
				{
					InstanceName:   string(DefaultInstanceName),
					ObjStoreSecret: "default-tenant-s3",
					Tenants:        buildTenants(tenants, DefaultInstanceName),
					ReceiveIngestorPreManifestsHook: func(ingestor *receive.Ingestor) {
						ingestor.VolumeSize = "5Gi"
					},
					StorePreManifestsHook: func(store *store.StoreStatefulSet) {
						store.VolumeSize = "5Gi"
					},
				},
				{
					InstanceName:   string(RhelInstanceName),
					ObjStoreSecret: "rhelemeter-tenant-s3",
					Tenants:        buildTenants(tenants, RhelInstanceName),
					ReceiveIngestorPreManifestsHook: func(ingestor *receive.Ingestor) {
						ingestor.VolumeSize = "5Gi"
					},
					StorePreManifestsHook: func(store *store.StoreStatefulSet) {
						store.VolumeSize = "5Gi"
					},
				},
				{
					InstanceName:   string(TelemeterInstanceName),
					ObjStoreSecret: "telemeter-tenant-s3",
					Tenants:        buildTenants(tenants, TelemeterInstanceName),
					ReceiveIngestorPreManifestsHook: func(ingestor *receive.Ingestor) {
						ingestor.VolumeSize = "5Gi"
					},
					StorePreManifestsHook: func(store *store.StoreStatefulSet) {
						store.VolumeSize = "5Gi"
					},
				},
			},
		},
	}
}

func sortTenants(tenants []observatorium.Tenants) {
	sort.Slice(tenants, func(i, j int) bool {
		return tenants[i].Name < tenants[j].Name
	})
}

func buildTenants(tenants map[string]observatorium.Tenants, instance InstanceName) []observatorium.Tenants {
	ret := []observatorium.Tenants{}
	for name, id := range tenantsMapping[instance] {
		newTenant := observatorium.Tenants{
			Name: name,
			ID:   id,
		}

		if tenant, ok := tenants[name]; ok {
			newTenant.ReceiveLimits = tenant.ReceiveLimits
		}

		ret = append(ret, newTenant)
	}
	// sort to avoid unnecessary diffs
	sortTenants(ret)

	return ret
}
