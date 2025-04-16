package main

import (
	"github.com/bwplotka/mimic"
	cfgobservatorium "github.com/rhobs/configuration/configuration/observatorium"
	services "github.com/rhobs/configuration/services_go"
)

func main() {
	gen := mimic.New()

	defer gen.Generate()

	cfgobservatorium.GenSLO(gen.With("observability", "prometheusrules", "pyrra"), gen.With("observability", "prometheusrules"))

	cfgobservatorium.GenerateRBACFile(gen.With(".tmp", "tenants"))

	// Generate the manifests for all observatorium instances.
	services.Generate(gen.With("services"))

}
