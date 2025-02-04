package main

import (
	"fmt"
	"net/http"
	"os"

	"github.com/go-kit/log"
	"github.com/magefile/mage/mg"
	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic"
	"github.com/philipgough/mimic/encoding"

	v1 "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/yaml"
)

type (
	Stage      mg.Namespace
	Production mg.Namespace
)

const (
	templatePath         = "resources"
	templateServicesPath = "services"
)

// CRDS Generates the CRDs for the Thanos operator.
// This is synced from the latest upstream main at:
// https://github.com/thanos-community/thanos-operator/tree/main/config/crd/bases
func (s Stage) CRDS() error {
	const (
		templateDir = "crds"
		base        = "https://raw.githubusercontent.com/thanos-community/thanos-operator/refs/heads/main/config/crd/bases/monitoring.thanos.io_"
	)
	gen := s.generator(templateDir)

	const (
		compact   = "thanoscompacts.yaml"
		queries   = "thanosqueries.yaml"
		receivers = "thanosreceives.yaml"
		rulers    = "thanosrulers.yaml"
		stores    = "thanosstores.yaml"
	)

	var objs []runtime.Object
	for _, component := range []string{compact, queries, receivers, rulers, stores} {
		manifest := base + component
		resp, err := http.Get(manifest)
		if err != nil {
			return fmt.Errorf("failed to fetch %s: %w", manifest, err)
		}

		if resp.StatusCode != http.StatusOK {
			return fmt.Errorf("failed to fetch %s: %s", manifest, resp.Status)
		}

		var obj v1.CustomResourceDefinition
		decoder := yaml.NewYAMLOrJSONDecoder(resp.Body, 100000)
		err = decoder.Decode(&obj)
		if err != nil {
			return fmt.Errorf("failed to decode %s: %w", manifest, err)
		}

		objs = append(objs, &obj)
		resp.Body.Close()
	}

	template := openshift.WrapInTemplate(objs, metav1.ObjectMeta{Name: "thanos-operator-crds"}, []templatev1.Parameter{})
	encoder := encoding.GhodssYAML(template)
	gen.Add("thanos-operator-crds.yaml", encoder)
	gen.Generate()
	return nil
}

// Build Builds the manifests for the stage environment.
func (Stage) Build() {
	mg.Deps(Stage.Alertmanager)
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

const (
	stageNamespace = "rhobs-stage"
	prodNamespace  = "rhobs-production"
)

func (Stage) namespace() string {
	return stageNamespace
}

func (Production) namespace() string {
	return prodNamespace
}

// Build Builds the manifests for the production environment.
func (Production) Build() {
	mg.Deps(Production.Alertmanager)
}
