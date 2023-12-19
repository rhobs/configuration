package observatorium

import (
	"github.com/bwplotka/mimic"
)

type Observatorium struct {
	Cluster  string
	Instance string // Instance is the name of the observatorium instance
	// MetricsInstances is the list of metrics instances in the observatorium instance
	// These are the different deployment units to which our tenants are mapped (e.g. default, rhel, telemeter)
	MetricsInstances ObservatoriumMetrics
	API              ObservatoriumAPI
}

// Manifests generates the manifests for the instance of observatorium.
func (o *Observatorium) Manifests(generator *mimic.Generator) {
	o.MetricsInstances.Manifests(generator.With(o.Cluster, o.Instance))
	o.API.Manifests(generator.With(o.Cluster, o.Instance))
}
