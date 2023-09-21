package observatorium

// import "github.com/rhobs/configuration/services_go/components/thanos/compactor"

import (
	"github.com/bwplotka/mimic"
	"github.com/bwplotka/mimic/encoding"
	"github.com/observatorium/api/rbac"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/compactor"
	"github.com/observatorium/observatorium/configuration_go/k8sutil"
	"github.com/observatorium/observatorium/configuration_go/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	monv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const (
	thanosImage         = "quay.io/thanos/thanos"
	thanosImageTag      = "v0.32.3"
	monitoringNamespace = "openshift-monitoring"
)

type TenantInstanceConfiguration struct {
	IngestRateLimit  []struct{}
	QueryRateLimit   []struct{}
	IngestHardTenant bool
	Authorizers      map[string]rbac.Authorizer
	// Tenant           *obs_api.tenant
}

type InstanceConfiguration struct {
	Cluster   string
	Instance  string
	Namespace string
	Tenants   []TenantInstanceConfiguration
}

type Observatorium struct {
	Cfg       *InstanceConfiguration
	Compactor *compactor.CompactorStatefulSet
}

func NewObservatorium(cfg *InstanceConfiguration) *Observatorium {

	return &Observatorium{
		Cfg:       cfg,
		Compactor: makeCompactor(cfg.Namespace),
	}
}

func (o *Observatorium) Manifests(generator *mimic.Generator) {
	compactorManifests := o.Compactor.Manifests()
	postProcessManifests(compactorManifests)

	commonTemplateMeta := metav1.ObjectMeta{
		Name: "observatorium-metrics-compact",
	}
	compactorTemplate := openshift.WrapInTemplate("", compactorManifests, commonTemplateMeta, []templatev1.Parameter{})
	generator.With(o.Cfg.Cluster, o.Cfg.Instance).Add("observatorium-metrics-compact-template.yaml", encoding.GhodssYAML(compactorTemplate[""]))

}

func postProcessManifests(manifests k8sutil.ObjectMap) {
	for _, manifest := range manifests {
		if serviceMonitor, ok := manifest.(*monv1.ServiceMonitor); ok {
			serviceMonitor.Spec.NamespaceSelector.MatchNames = []string{monitoringNamespace}
		}
	}
}
