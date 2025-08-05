package main

import (
	"fmt"

	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic"
	"github.com/philipgough/mimic/encoding"
	"github.com/rhobs/configuration/clusters"
	"github.com/rhobs/configuration/internal/submodule"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const (
	lokiRef = "ab233daeab6b9808a6c216c75cc5db449486f87e"
)

// LokiOperatorCRDS Generates the CRDs for the Loki operator.
// This is synced from the ref lokiRef at https://gitlab.cee.redhat.com/openshift-logging/konflux-log-storage
func (b Build) LokiOperatorCRDS(config clusters.ClusterConfig) error {
	gen := b.generator(config, "loki-operator-crds")
	return lokiCRD(gen, clusters.ProductionMaps)
}

func lokiCRD(gen *mimic.Generator, templates clusters.TemplateMaps) error {
	repoURL := "https://gitlab.cee.redhat.com/openshift-logging/konflux-log-storage"
	submodulePath := "loki-operator"
	yamlPATH := "operator/config/crd/bases"

	// Use the Info struct and Parse method from fetch.go
	info := submodule.Info{
		Commit:        lokiRef,
		SubmodulePath: submodulePath,
		URL:           repoURL,
		PathToYAMLS:   yamlPATH,
	}

	objs, err := info.FetchYAMLs()
	if err != nil {
		return fmt.Errorf("Error fetching YAML files: %v\n", err)
	}

	fmt.Printf("Successfully fetched %d CRD objects\n", len(objs))

	gen.Add("crds.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			objs,
			metav1.ObjectMeta{Name: "loki-operator-crds"},
			[]templatev1.Parameter{},
		),
	))
	gen.Generate()
	return nil
}
