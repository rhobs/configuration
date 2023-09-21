package services

import (
	"github.com/bwplotka/mimic"
	"github.com/rhobs/configuration/services_go/instances/rhobs"
	"github.com/rhobs/configuration/services_go/observatorium"
)

func Generate(gen *mimic.Generator) {
	rhobsConfigs := rhobs.ClusterConfigs()
	for _, cfg := range rhobsConfigs {
		observatorium := observatorium.NewObservatorium(&cfg)
		observatorium.Manifests(gen)
	}
}
