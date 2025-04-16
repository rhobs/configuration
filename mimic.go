package main

import (
	"github.com/bwplotka/mimic"
	cfgobservatorium "github.com/rhobs/configuration/configuration/observatorium"
)

func main() {
	gen := mimic.New()

	defer gen.Generate()

	cfgobservatorium.GenSLO(gen.With("observability", "prometheusrules", "pyrra"), gen.With("observability", "prometheusrules"))

	cfgobservatorium.GenerateRBACFile(gen.With(".tmp", "tenants"))

}
