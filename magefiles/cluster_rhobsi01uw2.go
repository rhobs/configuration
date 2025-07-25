package main

const (
	ClusterRHOBSUSWestIntegration ClusterName = "rhobsi01uw2"
)

func init() {
	RegisterCluster(ClusterConfig{
		Name:        ClusterRHOBSUSWestIntegration,
		Environment: EnvironmentIntegration,
		Namespace:   "rhobs-int",
		AMSUrl:      "https://api.openshift.com",
		Templates:   rhobsi01uw2TemplateMaps(),
		BuildSteps:  DefaultBuildSteps(),
	})
}

// rhobsi01uw2TemplateMaps returns template mappings specific to the rhobsi01uw2 integration cluster
func rhobsi01uw2TemplateMaps() TemplateMaps {
	// Start with integration base template and override only what's different
	return DefaultBaseTemplate()
}
