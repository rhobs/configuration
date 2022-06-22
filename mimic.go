package main

import (
	"github.com/bwplotka/mimic"
	cfgobservatorium "github.com/rhobs/configuration/configuration/observatorium"
)

func main() {
	gen := mimic.New()

	defer gen.Generate()

	cfgobservatorium.GenerateRBAC(gen.With("tenants"))
	cfgobservatorium.GenerateTenantSecret(gen.With("tenants"))
}
