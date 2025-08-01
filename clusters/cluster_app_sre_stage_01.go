package clusters

import (
	observatoriumapi "github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/observatorium/api"
	cfgobservatorium "github.com/rhobs/configuration/configuration/observatorium"
)

const (
	ClusterAppSREStage01 ClusterName = "app-sre-stage-01"
)

func init() {
	RegisterCluster(ClusterConfig{
		Name:        ClusterAppSREStage01,
		Environment: EnvironmentStaging,
		Namespace:   "rhobs-stage",
		AMSUrl:      "https://api.openshift.com",
		Tenants:     appSreStage01Tenants(),
		RBAC:        appSreStage01RBAC(),
		Templates:   appSreStage01TemplateMaps(),
		BuildSteps:  DefaultBuildSteps(),
	})
}

func appSreStage01Tenants() observatoriumapi.Tenants {
	return observatoriumapi.Tenants{
		Tenants: []observatoriumapi.Tenant{
			{
				Name: "hypershift",
				ID:   "EFD08939-FE1D-41A1-A28A-BE9A9BC68003",
				OIDC: &observatoriumapi.TenantOIDC{
					ClientID:      "${CLIENT_ID}",
					ClientSecret:  "${CLIENT_SECRET}",
					IssuerURL:     "https://sso.redhat.com/auth/realms/redhat-external",
					RedirectURL:   "https://observatorium-mst.api.stage.openshift.com/oidc/odfms/callback",
					UsernameClaim: "preferred_username",
				},
			},
		},
	}
}

func appSreStage01RBAC() cfgobservatorium.ObservatoriumRBAC {
	// TODO: Refactor RBAC so that we can generate the RBAC per cluster here.
	config := cfgobservatorium.GenerateRBAC()
	return *config
}

// appSreStage01TemplateMaps returns template mappings specific to the app-sre-stage-01 staging cluster
func appSreStage01TemplateMaps() TemplateMaps {
	return DefaultBaseTemplate()
}
