package observatorium

import (
	"github.com/bwplotka/mimic"
)

type Observatorium struct {
	Cluster  string
	Instance string // Instance is the name of the observatorium instance
	// MetricsInstances is the list of metrics instances in the observatorium instance
	// These are the different tenants in the observatorium instance (e.g. default, rhel, telemeter)
	MetricsInstances []ObservatoriumMetrics
}

// Manifests generates the manifests for the instance of observatorium.
func (o *Observatorium) Manifests(generator *mimic.Generator) {
	for _, metricsInstance := range o.MetricsInstances {
		for fn, encoder := range metricsInstance.Manifests() {
			generator.With(o.Cluster, o.Instance, metricsInstance.InstanceName).Add(fn, &statusRemoveEncoder{encoder: encoder})
		}
	}
}
