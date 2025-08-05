package main

import (
	lokiv1 "github.com/grafana/loki/operator/apis/loki/v1"
	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic/encoding"
	"github.com/rhobs/configuration/clusters"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

func (b Build) DefaultLokiStack(config clusters.ClusterConfig) {
	gen := b.generator(config, "loki-operator-default-cr")
	objs := []runtime.Object{
		NewLokiStack(config.Namespace),
	}

	gen.Add("loki-operator-default-cr.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			objs,
			metav1.ObjectMeta{Name: "loki-rhobs"},
			[]templatev1.Parameter{
				{
					Name:  "LOKI_SIZE",
					Value: "1x.medium",
				},
				{
					Name:  "LOKI_STORAGE_SECRET_NAME",
					Value: "loki-default-bucket",
				},
				{
					Name:  "LOKI_STORAGE_CLASS",
					Value: "gp3-csi",
				},
			},
		),
	))

	gen.Generate()
}

func NewLokiStack(namespace string) *lokiv1.LokiStack {
	return &lokiv1.LokiStack{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "loki.grafana.com/v1",
			Kind:       "LokiStack",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "observatorium-lokistack",
			Namespace: namespace,
		},
		Spec: lokiv1.LokiStackSpec{
			ManagementState: lokiv1.ManagementStateManaged,
			Size:            "${LOKI_SIZE}",
			Storage: lokiv1.ObjectStorageSpec{
				Schemas: []lokiv1.ObjectStorageSchema{
					{
						EffectiveDate: "2025-06-06",
						Version:       lokiv1.ObjectStorageSchemaV13,
					},
				},
				Secret: lokiv1.ObjectStorageSecretSpec{
					Name: "${LOKI_STORAGE_SECRET_NAME}",
					Type: "s3",
				},
			},
			StorageClassName: "${LOKI_STORAGE_CLASS}",
		},
	}
}
