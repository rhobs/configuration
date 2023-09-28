package observatorium

// import "github.com/rhobs/configuration/services_go/components/thanos/compactor"

import (
	"bytes"
	"io"
	"regexp"

	"github.com/bwplotka/mimic"
	"github.com/bwplotka/mimic/encoding"
	"github.com/observatorium/api/rbac"
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

// InstanceConfiguration is the configuration for an instance of observatorium.
type InstanceConfiguration struct {
	Cluster             string
	Instance            string
	Namespace           string
	Tenants             []TenantInstanceConfiguration
	ThanosStoreReplicas int32
}

// Observatorium is a representation of an instance of observatorium.
// It contains all the components that make up the instance.
type Observatorium struct {
	Cfg       *InstanceConfiguration
	Compactor k8sutil.ObjectMap
	Store     k8sutil.ObjectMap
}

// NewObservatorium creates a new instance of observatorium.
func NewObservatorium(cfg *InstanceConfiguration) *Observatorium {
	return &Observatorium{
		Cfg:       cfg,
		Compactor: makeCompactor(cfg.Namespace),
		Store:     makeStore(cfg.Namespace, cfg.ThanosStoreReplicas),
	}
}

// Manifests generates the manifests for the instance of observatorium.
func (o *Observatorium) Manifests(generator *mimic.Generator) {
	components := []struct {
		name    string
		objects k8sutil.ObjectMap
	}{
		{"observatorium-metrics-compact", o.Compactor},
		{"observatorium-metrics-store", o.Store},
	}

	for _, component := range components {
		template := openshift.WrapInTemplate("", component.objects, metav1.ObjectMeta{
			Name: component.name,
		}, []templatev1.Parameter{})
		generator.With(o.Cfg.Cluster, o.Cfg.Instance).Add(component.name+"-template.yaml", &customYAML{encoder: encoding.GhodssYAML(template[""])})
	}
}

// customYAML is a YAML encoder wrapper that allows cleaning of the output.
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
	re := regexp.MustCompile(`\s*status:\n\s*availableReplicas: 0\n\s*replicas: 0`)
	ret := re.ReplaceAllString(string(input), "")
	return []byte(ret)
}
