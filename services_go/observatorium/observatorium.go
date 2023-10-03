package observatorium

// import "github.com/rhobs/configuration/services_go/components/thanos/compactor"

import (
	"bytes"
	"io"
	"regexp"

	"github.com/bwplotka/mimic"
	"github.com/bwplotka/mimic/encoding"
	"github.com/observatorium/api/rbac"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/compactor"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/store"
	"github.com/observatorium/observatorium/configuration_go/k8sutil"
	"github.com/observatorium/observatorium/configuration_go/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
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
		objects k8sutil.ObjectMap
		params  []templatev1.Parameter
	}{
		{"observatorium-metrics-compact", makeCompactor(o.cfg.Namespace, o.cfg.ObjStoreSecret, o.cfg.PreManifestsHooks.Compactor), []templatev1.Parameter{
			{
				Name:     "OAUTH_PROXY_COOKIE_SECRET",
				Generate: "expression",
				From:     "[a-zA-Z0-9]{40}",
			},
		}},
		{"observatorium-metrics-store", makeStore(o.cfg.Namespace, o.cfg.ObjStoreSecret, o.cfg.PreManifestsHooks.ThanosStore), []templatev1.Parameter{}},
	}

	for _, component := range components {
		template := openshift.WrapInTemplate("", component.objects, metav1.ObjectMeta{
			Name: component.name,
		}, component.params)
		generator.With(o.cfg.Cluster, o.cfg.Instance).Add(component.name+"-template.yaml", &customYAML{encoder: encoding.GhodssYAML(template[""])})
	}
}

// customYAML is a YAML encoder wrapper that allows cleaning of the output.
// Wihtout this, the manifests would contain a status section that is not needed.
type customYAML struct {
	encoder encoding.Encoder
	reader  io.Reader
}

func (c *customYAML) Read(p []byte) (n int, err error) {
	if c.reader == nil {
		ret, err := io.ReadAll(c.encoder)
		if err != nil {
			panic(err)
		}

		c.reader = bytes.NewBuffer(c.clean(ret))
	}

	return c.reader.Read(p)
}

func (c *customYAML) EncodeComment(lines string) []byte {
	return c.encoder.EncodeComment(lines)
}

func (c *customYAML) clean(input []byte) []byte {
	// Remove status section from manifests
	re := []*regexp.Regexp{
		regexp.MustCompile(`\s*status:\n\s*availableReplicas: 0\n\s*replicas: 0`),
		regexp.MustCompile(`\s*status:\n\s*currentHealthy: 0\n\s*desiredHealthy: 0\n\s*disruptionsAllowed: 0\n\s*expectedPods: 0`),
	}

	ret := input

	for _, r := range re {
		ret = r.ReplaceAll(ret, []byte{})
	}

	return []byte(ret)
}
