package main

import (
	"fmt"

	"github.com/thanos-community/thanos-operator/api/v1alpha1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	"k8s.io/utils/ptr"
)

// ParamMap is a map of parameters to config values.
type ParamMap[T any] map[string]T

// TemplateMaps is a map of parameters to config value maps of different types.
type TemplateMaps struct {
	Images               ParamMap[string]
	Versions             ParamMap[string]
	LogLevels            ParamMap[string]
	StorageSize          ParamMap[v1alpha1.StorageSize]
	Replicas             ParamMap[int32]
	ResourceRequirements ParamMap[corev1.ResourceRequirements]
	ObjectStorageBucket  ParamMap[v1alpha1.ObjectStorageConfig]
}

// TemplateFn is a function that returns a value from a map.
// It panics if the param is not found in the map.
// It returns the value of the param.
func TemplateFn[T any](param string, m ParamMap[T]) T {
	v, ok := m[param]
	if !ok {
		panic(fmt.Sprintf("param %s not found in stage", param))
	}
	return v
}

const (
	CurrentThanosImageStage   = "quay.io/thanos/thanos"
	CurrentThanosVersionStage = "v0.37.2"

	CurrentThanosKonfluxImageStage   = "quay.io/redhat-user-workloads/rhobs-mco-tenant/rhobs-thanos"
	CurrentThanosKonfluxVersionStage = "c7c3ef94c51d518bb6056d3ad416d7b4f39559f3"

	memcachedTag           = "1.5-316"
	memcachedImage         = "registry.redhat.io/rhel8/memcached" + ":" + memcachedTag
	memcachedExporterImage = "quay.io/prometheus/memcached-exporter:v0.15.0"
)

const (
	apiCache          = "API_CACHE"
	memcachedExporter = "MEMCACHED_EXPORTER"
)

var logLevels = []string{"debug", "info", "warn", "error"}

// Stage images.
var StageImages = ParamMap[string]{
	"STORE02W":                   CurrentThanosKonfluxImageStage,
	"STORE2W90D":                 CurrentThanosKonfluxImageStage,
	"STORE90D+":                  CurrentThanosKonfluxImageStage,
	"STORE_DEFAULT":              CurrentThanosKonfluxImageStage,
	"RECEIVE_ROUTER":             CurrentThanosKonfluxImageStage,
	"RECEIVE_INGESTOR_TELEMETER": CurrentThanosKonfluxImageStage,
	"RECEIVE_INGESTOR_DEFAULT":   CurrentThanosKonfluxImageStage,
	"RULER":                      CurrentThanosKonfluxImageStage,
	"COMPACT_DEFAULT":            CurrentThanosKonfluxImageStage,
	"COMPACT_TELEMETER":          CurrentThanosKonfluxImageStage,
	"QUERY":                      CurrentThanosKonfluxImageStage,
	"QUERY_FRONTEND":             CurrentThanosKonfluxImageStage,
	"JAEGER_AGENT":               "registry.redhat.io/rhosdt/jaeger-agent-rhel8:1.57.0-10",
	"THANOS_OPERATOR":            "quay.io/redhat-user-workloads/rhobs-mco-tenant/rhobs-thanos-operator:0f2ef75aef549d02708c7a27202267567599b1b3",
	"KUBE_RBAC_PROXY":            "registry.redhat.io/openshift4/ose-kube-rbac-proxy@sha256:98455d503b797b6b02edcfd37045c8fab0796b95ee5cf4cfe73b221a07e805f0",
	apiCache:                     memcachedImage,
	memcachedExporter:            memcachedExporterImage,
}

// Stage images.
var StageVersions = ParamMap[string]{
	"STORE02W":                   CurrentThanosKonfluxVersionStage,
	"STORE2W90D":                 CurrentThanosKonfluxVersionStage,
	"STORE90D+":                  CurrentThanosKonfluxVersionStage,
	"STORE_DEFAULT":              CurrentThanosKonfluxVersionStage,
	"RECEIVE_ROUTER":             CurrentThanosKonfluxVersionStage,
	"RECEIVE_INGESTOR_TELEMETER": CurrentThanosKonfluxVersionStage,
	"RECEIVE_INGESTOR_DEFAULT":   CurrentThanosKonfluxVersionStage,
	"RULER":                      CurrentThanosKonfluxVersionStage,
	"COMPACT_DEFAULT":            CurrentThanosKonfluxVersionStage,
	"COMPACT_TELEMETER":          CurrentThanosKonfluxVersionStage,
	"QUERY":                      CurrentThanosKonfluxVersionStage,
	"QUERY_FRONTEND":             CurrentThanosKonfluxVersionStage,
	apiCache:                     memcachedTag,
}

// Stage log levels.
var StageLogLevels = ParamMap[string]{
	"STORE02W":                   logLevels[1],
	"STORE2W90D":                 logLevels[1],
	"STORE90D+":                  logLevels[1],
	"STORE_DEFAULT":              logLevels[1],
	"RECEIVE_ROUTER":             logLevels[1],
	"RECEIVE_INGESTOR_TELEMETER": logLevels[1],
	"RECEIVE_INGESTOR_DEFAULT":   logLevels[1],
	"RULER":                      logLevels[1],
	"COMPACT_DEFAULT":            logLevels[1],
	"COMPACT_TELEMETER":          logLevels[1],
	"QUERY":                      logLevels[1],
	"QUERY_FRONTEND":             logLevels[1],
}

// Stage PV storage sizes.
var StageStorageSize = ParamMap[v1alpha1.StorageSize]{
	"STORE02W":          "512Mi",
	"STORE2W90D":        "512Mi",
	"STORE90D+":         "512Mi",
	"STORE_DEFAULT":     "512Mi",
	"RECEIVE_TELEMETER": "3Gi",
	"RECEIVE_DEFAULT":   "3Gi",
	"RULER":             "512Mi",
	"COMPACT_DEFAULT":   "512Mi",
	"COMPACT_TELEMETER": "512Mi",
}

// Stage replicas.
var StageReplicas = ParamMap[int32]{
	"STORE02W":                   3,
	"STORE2W90D":                 3,
	"STORE90D+":                  3,
	"STORE_DEFAULT":              3,
	"RECEIVE_ROUTER":             3,
	"RECEIVE_INGESTOR_TELEMETER": 6,
	"RECEIVE_INGESTOR_DEFAULT":   3,
	"RULER":                      2,
	"QUERY":                      6,
	"QUERY_FRONTEND":             3,
	apiCache:                     1,
}

// Stage resource requirements.
var StageResourceRequirements = ParamMap[corev1.ResourceRequirements]{
	"STORE02W": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("50m"),
			corev1.ResourceMemory: resource.MustParse("512Mi"),
		},
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("250m"),
			corev1.ResourceMemory: resource.MustParse("2Gi"),
		},
	},
	"STORE2W90D": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("50m"),
			corev1.ResourceMemory: resource.MustParse("512Mi"),
		},
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("250m"),
			corev1.ResourceMemory: resource.MustParse("2Gi"),
		},
	},
	"STORE90D+": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("50m"),
			corev1.ResourceMemory: resource.MustParse("512Mi"),
		},
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("250m"),
			corev1.ResourceMemory: resource.MustParse("2Gi"),
		},
	},
	"STORE_DEFAULT": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("50m"),
			corev1.ResourceMemory: resource.MustParse("512Mi"),
		},
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("250m"),
			corev1.ResourceMemory: resource.MustParse("2Gi"),
		},
	},
	"RECEIVE_ROUTER": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("700m"),
			corev1.ResourceMemory: resource.MustParse("2Gi"),
		},
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("2"),
			corev1.ResourceMemory: resource.MustParse("5Gi"),
		},
	},
	"RECEIVE_INGESTOR_TELEMETER": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("700m"),
			corev1.ResourceMemory: resource.MustParse("2Gi"),
		},
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("2"),
			corev1.ResourceMemory: resource.MustParse("5Gi"),
		},
	},
	"RECEIVE_INGESTOR_DEFAULT": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("700m"),
			corev1.ResourceMemory: resource.MustParse("2Gi"),
		},
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("2"),
			corev1.ResourceMemory: resource.MustParse("5Gi"),
		},
	},
	"RULER": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("700m"),
			corev1.ResourceMemory: resource.MustParse("1Gi"),
		},
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("2"),
			corev1.ResourceMemory: resource.MustParse("3Gi"),
		},
	},
	"COMPACT_DEFAULT": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("100m"),
			corev1.ResourceMemory: resource.MustParse("1Gi"),
		},
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("1"),
			corev1.ResourceMemory: resource.MustParse("5Gi"),
		},
	},
	"COMPACT_TELEMETER": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("100m"),
			corev1.ResourceMemory: resource.MustParse("1Gi"),
		},
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("1"),
			corev1.ResourceMemory: resource.MustParse("5Gi"),
		},
	},
	"QUERY": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("300m"),
			corev1.ResourceMemory: resource.MustParse("1Gi"),
		},
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("2"),
			corev1.ResourceMemory: resource.MustParse("5Gi"),
		},
	},
	"QUERY_FRONTEND": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("100m"),
			corev1.ResourceMemory: resource.MustParse("500Mi"),
		},
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("1"),
			corev1.ResourceMemory: resource.MustParse("3Gi"),
		},
	},
	"MANAGER": corev1.ResourceRequirements{
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("1"),
			corev1.ResourceMemory: resource.MustParse("2Gi"),
		},
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("100m"),
			corev1.ResourceMemory: resource.MustParse("512Mi"),
		},
	},
	"KUBE_RBAC_PROXY": corev1.ResourceRequirements{
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("500m"),
			corev1.ResourceMemory: resource.MustParse("128Mi"),
		},
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("5m"),
			corev1.ResourceMemory: resource.MustParse("64Mi"),
		},
	},
	apiCache: corev1.ResourceRequirements{
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("3"),
			corev1.ResourceMemory: resource.MustParse("1844Mi"),
		},
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("500m"),
			corev1.ResourceMemory: resource.MustParse("100Mi"),
		},
	},
	memcachedExporter: corev1.ResourceRequirements{
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("200m"),
			corev1.ResourceMemory: resource.MustParse("200Mi"),
		},
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("100m"),
			corev1.ResourceMemory: resource.MustParse("100Mi"),
		},
	},
}

// Stage object storage bucket.
var StageObjectStorageBucket = ParamMap[v1alpha1.ObjectStorageConfig]{
	"DEFAULT": v1alpha1.ObjectStorageConfig{
		Key: "thanos.yaml",
		LocalObjectReference: corev1.LocalObjectReference{
			Name: "default-objectstorage",
		},
		Optional: ptr.To(false),
	},
	"TELEMETER": v1alpha1.ObjectStorageConfig{
		Key: "thanos.yaml",
		LocalObjectReference: corev1.LocalObjectReference{
			Name: "telemeter-objectstorage",
		},
		Optional: ptr.To(false),
	},
}

// Local images.
var LocalImages = ParamMap[string]{
	"STORE02W":                   CurrentThanosImageStage,
	"STORE2W90D":                 CurrentThanosImageStage,
	"STORE90D+":                  CurrentThanosImageStage,
	"STORE_DEFAULT":              CurrentThanosImageStage,
	"RECEIVE_ROUTER":             CurrentThanosImageStage,
	"RECEIVE_INGESTOR_TELEMETER": CurrentThanosImageStage,
	"RECEIVE_INGESTOR_DEFAULT":   CurrentThanosImageStage,
	"RULER":                      CurrentThanosImageStage,
	"COMPACT_DEFAULT":            CurrentThanosImageStage,
	"COMPACT_TELEMETER":          CurrentThanosImageStage,
	"QUERY":                      CurrentThanosImageStage,
	"QUERY_FRONTEND":             CurrentThanosImageStage,
	"JAEGER_AGENT":               "quay.io/jaegertracing/jaeger-agent:1.57.0",
	"THANOS_OPERATOR":            "quay.io/thanos/thanos-operator:main-2025-02-07-f1e3fa9",
	"KUBE_RBAC_PROXY":            "gcr.io/kubebuilder/kube-rbac-proxy:v0.16.0",
}

// Local images.
var LocalVersions = ParamMap[string]{
	"STORE02W":                   CurrentThanosVersionStage,
	"STORE2W90D":                 CurrentThanosVersionStage,
	"STORE90D+":                  CurrentThanosVersionStage,
	"STORE_DEFAULT":              CurrentThanosVersionStage,
	"RECEIVE_ROUTER":             CurrentThanosVersionStage,
	"RECEIVE_INGESTOR_TELEMETER": CurrentThanosVersionStage,
	"RECEIVE_INGESTOR_DEFAULT":   CurrentThanosVersionStage,
	"RULER":                      CurrentThanosVersionStage,
	"COMPACT_DEFAULT":            CurrentThanosVersionStage,
	"COMPACT_TELEMETER":          CurrentThanosVersionStage,
	"QUERY":                      CurrentThanosVersionStage,
	"QUERY_FRONTEND":             CurrentThanosVersionStage,
}

// Local PV storage sizes.
var LocalStorageSize = ParamMap[v1alpha1.StorageSize]{
	"STORE02W":          "1Gi",
	"STORE2W90D":        "1Gi",
	"STORE90D+":         "1Gi",
	"STORE_DEFAULT":     "1Gi",
	"RECEIVE_TELEMETER": "1Gi",
	"RECEIVE_DEFAULT":   "1Gi",
	"RULER":             "1Gi",
	"COMPACT_DEFAULT":   "1Gi",
	"COMPACT_TELEMETER": "1Gi",
}

// Local resource requirements.
var LocalResourceRequirements = ParamMap[corev1.ResourceRequirements]{
	"STORE02W":                   getLocalResources(),
	"STORE2W90D":                 getLocalResources(),
	"STORE90D+":                  getLocalResources(),
	"STORE_DEFAULT":              getLocalResources(),
	"RECEIVE_ROUTER":             getLocalResources(),
	"RECEIVE_INGESTOR_TELEMETER": getLocalResources(),
	"RECEIVE_INGESTOR_DEFAULT":   getLocalResources(),
	"RULER":                      getLocalResources(),
	"COMPACT_DEFAULT":            getLocalResources(),
	"COMPACT_TELEMETER":          getLocalResources(),
	"QUERY":                      getLocalResources(),
	"QUERY_FRONTEND":             getLocalResources(),
	"MANAGER": corev1.ResourceRequirements{
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("500m"),
			corev1.ResourceMemory: resource.MustParse("128Mi"),
		},
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("10m"),
			corev1.ResourceMemory: resource.MustParse("64Mi"),
		},
	},
	"KUBE_RBAC_PROXY": getLocalResources(),
}

// getLocalResources returns the resource requirements for local development
func getLocalResources() corev1.ResourceRequirements {
	return corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("10m"),
			corev1.ResourceMemory: resource.MustParse("20Mi"),
		},
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("20m"),
			corev1.ResourceMemory: resource.MustParse("50Mi"),
		},
	}
}

var StageMaps = TemplateMaps{
	Images:               StageImages,
	Versions:             StageVersions,
	LogLevels:            StageLogLevels,
	StorageSize:          StageStorageSize,
	Replicas:             StageReplicas,
	ResourceRequirements: StageResourceRequirements,
	ObjectStorageBucket:  StageObjectStorageBucket,
}

var LocalMaps = TemplateMaps{
	Images:               LocalImages,
	Versions:             LocalVersions,
	LogLevels:            StageLogLevels,
	StorageSize:          LocalStorageSize,
	Replicas:             StageReplicas,
	ResourceRequirements: LocalResourceRequirements,
	ObjectStorageBucket:  StageObjectStorageBucket,
}
