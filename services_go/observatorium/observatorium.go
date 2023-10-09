package observatorium

import (
	"github.com/bwplotka/mimic"
	"github.com/bwplotka/mimic/encoding"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/compactor"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/store"
)

// TenantInstanceConfiguration is the configuration for a single tenant in an instance of observatorium.
// type TenantInstanceConfiguration struct {
// 	IngestRateLimit  []struct{}
// 	QueryRateLimit   []struct{}
// 	IngestHardTenant bool
// 	Authorizers      map[string]rbac.Authorizer
// 	// Tenant           *obs_api.tenant
// }

type ThanosTenantConfig[T compactor.CompactorStatefulSet | store.StoreStatefulSet] struct {
	Tenant           string
	ObjStoreSecret   string
	PreManifestsHook func(*T)
}

// Observatorium is an instance of observatorium.
// It contains the configuration for the instance and the ability to generate the manifests for the instance.
type Observatorium struct {
	Cluster        string
	Instance       string
	Namespace      string
	ThanosImageTag string
	Stores         []ThanosTenantConfig[store.StoreStatefulSet]
	Compactors     []ThanosTenantConfig[compactor.CompactorStatefulSet]
}

// Manifests generates the manifests for the instance of observatorium.
func (o *Observatorium) Manifests(generator *mimic.Generator) {
	components := map[string]encoding.Encoder{} // filename -> yaml encoder

	for _, storeCfg := range o.Stores {
		components["observatorium-metrics-store-"+storeCfg.Tenant] = makeStore(o.Namespace, o.ThanosImageTag, storeCfg)
	}

	for _, compactorCfg := range o.Compactors {
		components["observatorium-metrics-compact-"+compactorCfg.Tenant] = makeCompactor(o.Namespace, o.ThanosImageTag, compactorCfg)
	}

	for name, encoder := range components {
		generator.With(o.Cluster, o.Instance).Add(name+"-template.yaml", &statusRemoveEncoder{encoder: encoder})
	}
}
