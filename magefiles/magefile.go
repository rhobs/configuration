package main

import (
	"os"

	"github.com/go-kit/log"
	"github.com/magefile/mage/mg"
	"github.com/philipgough/mimic"
)

type (
	Stage      mg.Namespace
	Production mg.Namespace
	Local      mg.Namespace
)

const (
	templatePath         = "resources"
	templateServicesPath = "services"
)

// Build Builds the manifests for the stage environment.
func (Stage) Build() {
	mg.SerialDeps(Stage.Alertmanager, Stage.CRDS, Stage.Operator, Stage.OperatorCR, Stage.TelemeterRules, Stage.ServiceMonitors, Stage.Secrets)
}

// Build Builds the manifests for a local environment.
func (Local) Build() {
	mg.SerialDeps(Local.CRDS, Local.Operator, Local.OperatorCR, Local.TelemeterRules, Local.ServiceMonitors, Local.Secrets)
}

func (Stage) generator(component string) *mimic.Generator {
	gen := &mimic.Generator{}
	gen = gen.With(templatePath, templateServicesPath, component, "staging")
	gen.Logger = log.NewLogfmtLogger(log.NewSyncWriter(os.Stdout))
	return gen
}

func (Production) generator(component string) *mimic.Generator {
	gen := &mimic.Generator{}
	gen = gen.With(templatePath, templateServicesPath, component, "production")
	gen.Logger = log.NewLogfmtLogger(log.NewSyncWriter(os.Stdout))
	return gen
}

func (Local) generator(component string) *mimic.Generator {
	gen := &mimic.Generator{}
	gen = gen.With(templatePath, templateServicesPath, component, "local")
	gen.Logger = log.NewLogfmtLogger(log.NewSyncWriter(os.Stdout))
	return gen
}

const (
	stageNamespace = "rhobs-stage"
	prodNamespace  = "rhobs-production"
	localNamespace = "rhobs-local"
)

func (Stage) namespace() string {
	return stageNamespace
}

func (Production) namespace() string {
	return prodNamespace
}

func (Local) namespace() string {
	return localNamespace
}

// Build Builds the manifests for the production environment.
func (Production) Build() {
	mg.Deps(Production.Alertmanager)
}
