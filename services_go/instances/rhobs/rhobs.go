package rhobs

import (
	"encoding/json"
	"fmt"
	"sort"
	"time"

	"github.com/google/go-jsonnet"
	observatoriumapi "github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/observatorium/api"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/receive"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/ruler"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/store"
	"github.com/observatorium/observatorium/configuration_go/k8sutil"
	templatev1 "github.com/openshift/api/template/v1"
	cfgobservatorium "github.com/rhobs/configuration/configuration/observatorium"
	"github.com/rhobs/configuration/services_go/observatorium"
	"gopkg.in/yaml.v3"
	corev1 "k8s.io/api/core/v1"
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

type tenantName string

const (
	rhobsTenantName          tenantName = "rhobs"
	osdTenantName            tenantName = "osd"
	rhacsTenantName          tenantName = "rhacs"
	cnvqeTenantName          tenantName = "cnvqe"
	psiocpTenantName         tenantName = "psiocp"
	rhodsTenantName          tenantName = "rhods"
	odfmsTenantName          tenantName = "odfms"
	referenceAddonTenantName tenantName = "reference-addon"
	dptpTenantName           tenantName = "dptp"
	appsreTenantName         tenantName = "appsre"
	rhtapTenantName          tenantName = "rhtap"
	telemeterTenantName      tenantName = "telemeter"
	rhelTenantName           tenantName = "rhel"
)

var tenantsMapping = map[InstanceName]map[tenantName]string{
	DefaultInstanceName: {
		rhobsTenantName:          "0fc2b00e-201b-4c17-b9f2-19d91adc4fd2",
		osdTenantName:            "770c1124-6ae8-4324-a9d4-9ce08590094b",
		rhacsTenantName:          "1b9b6e43-9128-4bbf-bfff-3c120bbe6f11",
		cnvqeTenantName:          "9ca26972-4328-4fe3-92db-31302013d03f",
		psiocpTenantName:         "37b8fd3f-56ff-4b64-8272-917c9b0d1623",
		rhodsTenantName:          "8ace13a2-1c72-4559-b43d-ab43e32a255a",
		odfmsTenantName:          "99c885bc-2d64-4c4d-b55e-8bf30d98c657",
		referenceAddonTenantName: "d17ea8ce-d4c6-42ef-b259-7d10c9227e93",
		dptpTenantName:           "AC879303-C60F-4D0D-A6D5-A485CFD638B8",
		appsreTenantName:         "3833951d-bede-4a53-85e5-f73f4913973f",
		rhtapTenantName:          "0031e8d6-e50a-47ea-aecb-c7e0bd84b3f1",
	},
	RhelInstanceName: {
		rhelTenantName: "72e6f641-b2e2-47eb-bbc2-fee3c8fbda26",
	},
	TelemeterInstanceName: {
		telemeterTenantName: "FB870BF3-9F3A-44FF-9BF7-D7A047A52F43",
	},
}

type TenantConfig struct {
	ReceiveLimits    *receive.WriteLimitConfig
	ObsApiOIDC       *observatoriumapi.TenantOIDC
	ObsApiOPA        *observatoriumapi.TenantOPA
	ObsApiRateLimits []observatoriumapi.TenantRateLimits
}

func ClusterConfigs() []observatorium.Observatorium {
	return []observatorium.Observatorium{
		stageConfig(),
		prodConfig(),
	}
}

func stageConfig() observatorium.Observatorium {
	rhobsOidc := makeIODC(rhobsTenantName, "stage")
	rhobsOidc.GroupClaim = "email"
	tenants := map[tenantName]TenantConfig{
		rhacsTenantName: {
			ReceiveLimits: &receive.WriteLimitConfig{
				HeadSeriesLimit: 10000000, // 10M
			},
			ObsApiOIDC: makeIODC(rhacsTenantName, "stage"),
		},
		rhtapTenantName: {
			ReceiveLimits: &receive.WriteLimitConfig{
				HeadSeriesLimit: 200000, // 200k
			},
			ObsApiOIDC: makeIODC(rhtapTenantName, "stage"),
		},
		rhelTenantName: {
			ReceiveLimits: &receive.WriteLimitConfig{
				RequestLimits: receive.RequestLimitsConfig{
					SeriesLimit: 10,
				},
			},
			ObsApiOIDC: makeIODC(rhelTenantName, "stage"),
			ObsApiRateLimits: []observatoriumapi.TenantRateLimits{
				{
					Endpoint: "/api/metrics/v1/rhel/api/v1/receive",
					Limit:    10000,
					Window:   time.Duration(30 * time.Second),
				},
			},
		},
		rhobsTenantName: {
			ObsApiOIDC: rhobsOidc,
		},
		osdTenantName: {
			ObsApiOIDC: makeIODC(osdTenantName, "stage"),
			ObsApiOPA: &observatoriumapi.TenantOPA{
				URL: "http://127.0.0.1:8082/v1/data/observatorium/allow",
			},
			ObsApiRateLimits: []observatoriumapi.TenantRateLimits{
				{
					Endpoint: "/api/metrics/v1/.+/api/v1/receive",
					Limit:    10000,
					Window:   time.Duration(30 * time.Second),
				},
			},
		},
		cnvqeTenantName: {
			ObsApiOIDC: makeIODC(cnvqeTenantName, "stage"),
		},
		psiocpTenantName: {
			ObsApiOIDC: makeIODC(psiocpTenantName, "stage"),
		},
		rhodsTenantName: {
			ObsApiOIDC: makeIODC(rhodsTenantName, "stage"),
		},
		odfmsTenantName: {
			ObsApiOIDC: makeIODC(odfmsTenantName, "stage"),
		},
		referenceAddonTenantName: {
			ObsApiOIDC: makeIODC(referenceAddonTenantName, "stage"),
		},
		dptpTenantName: {
			ObsApiOIDC: makeIODC(dptpTenantName, "stage"),
		},
		appsreTenantName: {
			ObsApiOIDC: makeIODC(appsreTenantName, "stage"),
		},
		telemeterTenantName: {
			ObsApiOIDC: makeIODC(telemeterTenantName, "stage"),
		},
	}

	jsonRbac, err := json.Marshal(cfgobservatorium.GenerateRBAC())
	if err != nil {
		panic(err)
	}
	rbacConfig := jsonToYaml(string(jsonRbac))

	return observatorium.Observatorium{
		Cluster:  "app-sre-stage-01",
		Instance: "rhobs",
		API: observatorium.ObservatoriumAPI{
			Namespace:                    "rhobs",
			RBAC:                         rbacConfig,
			AmsUrl:                       "https://api.stage.openshift.com",
			UpQueriesTenant:              tenantsMapping[DefaultInstanceName][rhobsTenantName],
			ObsCtlReloaderManagedTenants: []string{string(rhobsTenantName), string(osdTenantName), string(appsreTenantName), string(rhtapTenantName)},
			Tenants:                      makeObsTenants(tenants),
			RuleObjStoreSecret:           "rhobs-rules-objstore-stage-s3",
			TemplateParams: []templatev1.Parameter{
				{Name: "TENANT_OIDC_CLIENT_ID"},
				{Name: "TENANT_OIDC_CLIENT_SECRET"},
			},
		},
		MetricsInstances: observatorium.ObservatoriumMetrics{
			Namespace:                 "rhobs",
			ThanosImageTag:            "v0.32.5",
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
					Tenants:        buildMetricTenants(tenants, DefaultInstanceName),
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
					Tenants:        buildMetricTenants(tenants, RhelInstanceName),
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
					Tenants:        buildMetricTenants(tenants, TelemeterInstanceName),
					ReceiveIngestorPreManifestsHook: func(ingestor *receive.Ingestor) {
						ingestor.VolumeSize = "5Gi"
					},
					StorePreManifestsHook: func(store *store.StoreStatefulSet) {
						store.VolumeSize = "5Gi"
					},
					RulerOpts: func(opts *ruler.RulerOptions) {
						opts.RuleFile = append(opts.RuleFile, ruler.RuleFileOption{
							FileName:      "observatorium.yaml",
							ConfigMapName: "observatorium-rules",
							ParentDir:     "telemeter-rules",
						})
					},
					RulerPreManifestsHook: func(rulerSs *ruler.RulerStatefulSet) {
						rulerSs.ConfigMaps["observatorium-rules"] = map[string]string{
							"observatorium.yaml": getTelemeterRules(),
						}
						rulerSs.Sidecars = append(rulerSs.Sidecars, &k8sutil.Container{
							Name:     "configmap-reloader",
							Image:    "quay.io/openshift/origin-configmap-reloader",
							ImageTag: "4.5.0",
							Args: []string{
								"-volume-dir=/etc/thanos-rule-syncer",
								"-webhook-url=http://localhost:10902/-/reload",
							},
							Resources: k8sutil.NewResourcesRequirements("100m", "200m", "100Mi", "200Mi"),
							VolumeMounts: []corev1.VolumeMount{
								{
									Name:      "observatorium-rules",
									MountPath: "/etc/thanos/rules/observatorium-rules",
								},
							},
						})
					},
				},
			},
		},
	}
}

func prodConfig() observatorium.Observatorium {
	tenants := map[tenantName]TenantConfig{
		rhacsTenantName: {
			ReceiveLimits: &receive.WriteLimitConfig{
				HeadSeriesLimit: 10000000, // 10M
			},
		},
		rhtapTenantName: {
			ReceiveLimits: &receive.WriteLimitConfig{
				HeadSeriesLimit: 200000, // 200k
			},
		},
		rhelTenantName: {
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
					Tenants:        buildMetricTenants(tenants, DefaultInstanceName),
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
					Tenants:        buildMetricTenants(tenants, RhelInstanceName),
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
					Tenants:        buildMetricTenants(tenants, TelemeterInstanceName),
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

func buildMetricTenants(tenants map[tenantName]TenantConfig, instance InstanceName) []observatorium.Tenants {
	ret := []observatorium.Tenants{}
	for name, id := range tenantsMapping[instance] {
		newTenant := observatorium.Tenants{
			Name: string(name),
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

func makeIODC(tenant tenantName, env string) *observatoriumapi.TenantOIDC {
	return &observatoriumapi.TenantOIDC{
		ClientID:      "${TENANT_OIDC_CLIENT_ID}",
		ClientSecret:  "${TENANT_OIDC_CLIENT_SECRET}",
		IssuerURL:     "https://sso.redhat.com/auth/realms/redhat-external",
		RedirectURL:   fmt.Sprintf("https://observatorium-mst.api.%s.openshift.com/oidc/%s/callback", env, tenant),
		UsernameClaim: "preferred_username",
	}
}

func makeObsTenants(tenants map[tenantName]TenantConfig) []observatoriumapi.Tenant {
	ret := []observatoriumapi.Tenant{}
	for name, tenant := range tenants {
		newTenant := observatoriumapi.Tenant{
			Name:       string(name),
			ID:         tenantsMapping[DefaultInstanceName][name],
			OIDC:       tenant.ObsApiOIDC,
			OPA:        tenant.ObsApiOPA,
			RateLimits: tenant.ObsApiRateLimits,
		}

		ret = append(ret, newTenant)
	}
	// sort to avoid unnecessary diffs
	sort.Slice(ret, func(i, j int) bool {
		return ret[i].Name < ret[j].Name
	})

	return ret
}

func getTelemeterRules() string {
	vm := jsonnet.MakeVM()
	vm.Importer(&jsonnet.FileImporter{
		JPaths: []string{"./vendor_jsonnet"},
	})

	snippet := fmt.Sprintf(`
	local telemeterRules = (import 'github.com/openshift/telemeter/jsonnet/telemeter/rules.libsonnet');
	{
		groups: std.map(function(group) {
			name: 'telemeter-' + group.name,
			interval: group.interval,
			rules: std.map(function(rule) rule {
			labels+: {
				tenant_id: '%s',
			},
			}, group.rules),
		}, telemeterRules.prometheus.recordingrules.groups),
	}`, tenantsMapping[TelemeterInstanceName][telemeterTenantName])

	// Evaluate the Jsonnet content
	jsonStr, err := vm.EvaluateAnonymousSnippet("telemeter-rules", snippet)
	if err != nil {
		panic(fmt.Sprintf("Failed to evaluate Jsonnet content: %v\n", err))
	}

	return jsonToYaml(jsonStr)
}

func jsonToYaml(jsonStr string) string {
	// Unmarshal the jsonStr into a map
	var data map[string]interface{}
	if err := json.Unmarshal([]byte(jsonStr), &data); err != nil {
		panic(fmt.Sprintf("Failed to unmarshal Jsonnet content: %v\n", err))
	}

	// Marshal the map into YAML
	yamlBytes, err := yaml.Marshal(data)
	if err != nil {
		panic(fmt.Sprintf("Failed to marshal Jsonnet content: %v\n", err))
	}

	return string(yamlBytes)
}
