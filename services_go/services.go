package services

import (
	"github.com/bwplotka/mimic"
	"github.com/rhobs/configuration/services_go/instances/rhobs"
)

// Generate generates the manifests for all observatorium instances.
func Generate(gen *mimic.Generator) {
	rhobsConfigs := rhobs.ClusterConfigs()
	for _, obsCfg := range rhobsConfigs {
		obsCfg.Manifests(gen)
	}
}
