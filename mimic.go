package main

import (
	"github.com/bwplotka/mimic"
	cfgobservatorium "github.com/rhobs/configuration/configuration/observatorium"
)

func main() {
	gen := mimic.New()

	defer gen.Generate()

	cfgobservatorium.GenSLO(gen.With("observability", "prometheusrules", "pyrra"), gen.With("observability", "prometheusrules"))

	cfgobservatorium.GenerateRBAC(gen.With(".tmp", "tenants"))

	// Generate the manifests for all observatorium instances.
	// services.Generate(gen.With("services"))

}
