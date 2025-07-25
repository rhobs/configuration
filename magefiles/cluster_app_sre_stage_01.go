package main

const (
	ClusterAppSREStage01 ClusterName = "app-sre-stage-01"
)

func init() {
	RegisterCluster(ClusterConfig{
		Name:        ClusterAppSREStage01,
		Environment: EnvironmentStaging,
		Namespace:   "rhobs-stage",
		AMSUrl:      "https://api.openshift.com",
		Templates:   appSreStage01TemplateMaps(),
		BuildSteps:  DefaultBuildSteps(),
	})
}

// appSreStage01TemplateMaps returns template mappings specific to the app-sre-stage-01 staging cluster
func appSreStage01TemplateMaps() TemplateMaps {
	return DefaultBaseTemplate()
}
