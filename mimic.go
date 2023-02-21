package main

import (
	"github.com/bwplotka/mimic"
	cfgobservatorium "github.com/rhobs/configuration/configuration/observatorium"
)

func main() {
	gen := mimic.New()

	defer gen.Generate()

	cfgobservatorium.GenSLO(gen.With(".tmp2", "rulez", "pyrra"), gen.With(".tmp2", "rulez"))

	cfgobservatorium.GenerateRBAC(gen.With(".tmp", "tenants"))
}
