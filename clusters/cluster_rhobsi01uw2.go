package clusters

import (
	observatoriumapi "github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/observatorium/api"
	cfgobservatorium "github.com/rhobs/configuration/configuration/observatorium"
)

const (
	ClusterRHOBSUSWestIntegration ClusterName = "rhobsi01uw2"
)

func init() {
	RegisterCluster(ClusterConfig{
		Name:        ClusterRHOBSUSWestIntegration,
		Environment: EnvironmentIntegration,
		Namespace:   "rhobs-int",
		AMSUrl:      "https://api.openshift.com",
		RBAC:        rhobsi01uw2RBAC(),
		Tenants:     rhobsi01uw2Tenants(),
		Templates:   rhobsi01uw2TemplateMaps(),
		BuildSteps:  rhobsi01uw2BuildSteps(),
	})
}

func rhobsi01uw2Tenants() observatoriumapi.Tenants {
	return observatoriumapi.Tenants{
		Tenants: []observatoriumapi.Tenant{
			{
				Name: "hypershift-integration",
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

func rhobsi01uw2RBAC() cfgobservatorium.ObservatoriumRBAC {
	// TODO: Refactor RBAC so that we can generate the RBAC per cluster here.
	config := cfgobservatorium.GenerateRBAC()
	return *config
}

func rhobsi01uw2BuildSteps() []string {
	return DefaultBuildSteps()
}

// rhobsi01uw2TemplateMaps returns template mappings specific to the rhobsi01uw2 integration cluster
func rhobsi01uw2TemplateMaps() TemplateMaps {
	// Start with integration base template and override only what's different
	return DefaultBaseTemplate().Override()
}
