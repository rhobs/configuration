package observatorium

// import "github.com/rhobs/configuration/services_go/components/thanos/compactor"

import (
	"github.com/bwplotka/mimic"
	"github.com/bwplotka/mimic/encoding"
	"github.com/observatorium/api/rbac"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/compactor"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/store"
	"github.com/observatorium/observatorium/configuration_go/k8sutil"
	"github.com/observatorium/observatorium/configuration_go/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
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

// type ComponentsConfig struct {

type InstanceConfiguration struct {
	Cluster   string
	Instance  string
	Namespace string
	Tenants   []TenantInstanceConfiguration
	// Components
}

type PostProcessFunc func(obj runtime.Object)

type Observatorium struct {
	Cfg              *InstanceConfiguration
	Compactor        *compactor.CompactorStatefulSet
	Store            *store.StoreStatefulSet
	PostProcessFuncs []PostProcessFunc
}

func NewObservatorium(cfg *InstanceConfiguration) *Observatorium {
	postProcessFuncs := []PostProcessFunc{updateServiceMonitorNamespace}
	storeComponent, postProcess := makeStore(cfg.Namespace)
	postProcessFuncs = append(postProcessFuncs, postProcess...)
	compactorComponent, postProcess := makeCompactor(cfg.Namespace)
	postProcessFuncs = append(postProcessFuncs, postProcess...)

	return &Observatorium{
		Cfg:              cfg,
		Compactor:        compactorComponent,
		Store:            storeComponent,
		PostProcessFuncs: postProcessFuncs,
	}
}

func (o *Observatorium) Manifests(generator *mimic.Generator) {
	components := []struct {
		name    string
		objects k8sutil.ObjectMap
	}{
		{"observatorium-metrics-compact", o.Compactor.Manifests()},
		{"observatorium-metrics-store", o.Store.Manifests()},
	}

	for _, component := range components {
		o.postProcess(component.objects)
		template := openshift.WrapInTemplate("", component.objects, metav1.ObjectMeta{
			Name: component.name,
		}, []templatev1.Parameter{})
		generator.With(o.Cfg.Cluster, o.Cfg.Instance).Add(component.name+"-template.yaml", encoding.GhodssYAML(template[""]))
	}
}

func (o *Observatorium) postProcess(manifests k8sutil.ObjectMap) {
	for _, manifest := range manifests {
		for _, postProcessFunc := range o.PostProcessFuncs {
			postProcessFunc(manifest)
		}
	}
}
