package observatorium

// import "github.com/rhobs/configuration/services_go/components/thanos/compactor"

import (
	"github.com/bwplotka/mimic"
	"github.com/bwplotka/mimic/encoding"
	"github.com/observatorium/api/rbac"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/compactor"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/store"
)

// TenantInstanceConfiguration is the configuration for a single tenant in an instance of observatorium.
type TenantInstanceConfiguration struct {
	IngestRateLimit  []struct{}
	QueryRateLimit   []struct{}
	IngestHardTenant bool
	Authorizers      map[string]rbac.Authorizer
	// Tenant           *obs_api.tenant
}

// PreManifestsHooks is a collection of hooks that can be used to modify the manifests before they are generated.
// This provides the instance configuration with the ability to customize each component deployed.
type PreManifestsHooks struct {
	ThanosStore func(*store.StoreStatefulSet)
	Compactor   func(*compactor.CompactorStatefulSet)
}

// InstanceConfiguration is the configuration for an instance of observatorium.
type InstanceConfiguration struct {
	Cluster           string
	Instance          string
	Namespace         string
	ObjStoreSecret    string
	Tenants           []TenantInstanceConfiguration
	PreManifestsHooks PreManifestsHooks
}

// Observatorium is an instance of observatorium.
// It contains the configuration for the instance and the ability to generate the manifests for the instance.
type Observatorium struct {
	cfg *InstanceConfiguration
}

// NewObservatorium creates a new instance of observatorium.
func NewObservatorium(cfg *InstanceConfiguration) *Observatorium {
	return &Observatorium{
		cfg: cfg,
	}
}

// Manifests generates the manifests for the instance of observatorium.
func (o *Observatorium) Manifests(generator *mimic.Generator) {
	components := []struct {
		name    string
		encoder encoding.Encoder
	}{
		{"observatorium-metrics-compact", makeCompactor(o.cfg.Namespace, o.cfg.ObjStoreSecret, o.cfg.PreManifestsHooks.Compactor)},
		{"observatorium-metrics-store", makeStore(o.cfg.Namespace, o.cfg.ObjStoreSecret, o.cfg.PreManifestsHooks.ThanosStore)},
	}

	for _, component := range components {
		generator.With(o.cfg.Cluster, o.cfg.Instance).Add(component.name+"-template.yaml", &statusRemoveEncoder{encoder: component.encoder})
	}
}
