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
		panic(fmt.Sprintf("param %s not found", param))
	}
	return v
}

const (
	thanosImage        = "quay.io/redhat-user-workloads/rhobs-mco-tenant/rhobs-konflux-thanos"
	thanosVersionStage = "03c9fefbda1b33830a950bd28484fa0a1e039555"
	thanosVersionProd  = "03c9fefbda1b33830a950bd28484fa0a1e039555"

	thanosOperatorImage        = "quay.io/redhat-user-workloads/rhobs-mco-tenant/rhobs-konflux-thanos-operator"
	thanosOperatorVersionStage = "4bbe34d98e25009d7380c17aae35d52964e34261"
	thanosOperatorVersionProd  = "on-pr-ddfbef156f6d7e76f6dfd89a43380a36fba89ffb"
)

const (
	memcachedTag           = "1.5-316"
	memcachedImage         = "registry.redhat.io/rhel8/memcached" + ":" + memcachedTag
	memcachedExporterImage = "quay.io/prometheus/memcached-exporter:v0.15.0"
)

const (
	apiCache          = "API_CACHE"
	memcachedExporter = "MEMCACHED_EXPORTER"

	jaeger = "JAEGER_AGENT"

	observatoriumAPI = "OBSERVATORIUM_API"
	opaAMS           = "OPA_AMS"
)

var logLevels = []string{"debug", "info", "warn", "error"}

// Stage images.
var StageImages = ParamMap[string]{
	"STORE02W":                   thanosImage,
	"STORE2W90D":                 thanosImage,
	"STORE90D+":                  thanosImage,
	"STORE_DEFAULT":              thanosImage,
	"RECEIVE_ROUTER":             thanosImage,
	"RECEIVE_INGESTOR_TELEMETER": thanosImage,
	"RECEIVE_INGESTOR_DEFAULT":   thanosImage,
	"RULER":                      thanosImage,
	"COMPACT_DEFAULT":            thanosImage,
	"COMPACT_TELEMETER":          thanosImage,
	"QUERY":                      thanosImage,
	"QUERY_FRONTEND":             thanosImage,
	jaeger:                       "registry.redhat.io/rhosdt/jaeger-agent-rhel8:1.57.0-10",
	"THANOS_OPERATOR":            fmt.Sprintf("%s:%s", thanosOperatorImage, thanosOperatorVersionStage),
	"KUBE_RBAC_PROXY":            "registry.redhat.io/openshift4/ose-kube-rbac-proxy@sha256:98455d503b797b6b02edcfd37045c8fab0796b95ee5cf4cfe73b221a07e805f0",
	apiCache:                     memcachedImage,
	memcachedExporter:            memcachedExporterImage,
	observatoriumAPI:             "quay.io/redhat-user-workloads/rhobs-mco-tenant/observatorium-api:9aada65247a07782465beb500323a0e18d7e3d05",
	opaAMS:                       "quay.io/redhat-user-workloads/rhobs-mco-tenant/rhobs-konflux-opa-ams:69db2e0545d9e04fd18f2230c1d59ad2766cf65c",
}

// Stage images.
var StageVersions = ParamMap[string]{
	"STORE02W":                   thanosVersionStage,
	"STORE2W90D":                 thanosVersionStage,
	"STORE90D+":                  thanosVersionStage,
	"STORE_DEFAULT":              thanosVersionStage,
	"RECEIVE_ROUTER":             thanosVersionStage,
	"RECEIVE_INGESTOR_TELEMETER": thanosVersionStage,
	"RECEIVE_INGESTOR_DEFAULT":   thanosVersionStage,
	"RULER":                      thanosVersionStage,
	"COMPACT_DEFAULT":            thanosVersionStage,
	"COMPACT_TELEMETER":          thanosVersionStage,
	"QUERY":                      thanosVersionStage,
	"QUERY_FRONTEND":             thanosVersionStage,
	apiCache:                     memcachedTag,
	observatoriumAPI:             "9aada65247a07782465beb500323a0e18d7e3d05",
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
	observatoriumAPI:             logLevels[0],
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
	observatoriumAPI:             2,
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
	observatoriumAPI: corev1.ResourceRequirements{
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("1"),
			corev1.ResourceMemory: resource.MustParse("2Gi"),
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
			Name: "observatorium-mst-thanos-objectstorage",
		},
		Optional: ptr.To(false),
	},
	"TELEMETER": v1alpha1.ObjectStorageConfig{
		Key: "thanos.yaml",
		LocalObjectReference: corev1.LocalObjectReference{
			Name: "thanos-objectstorage",
		},
		Optional: ptr.To(false),
	},
}

// ProductionImages is a map of production images.
var ProductionImages = ParamMap[string]{
	"STORE02W":        thanosImage,
	"STORE2W90D":      thanosImage,
	"STORE90D+":       thanosImage,
	"STORE_DEFAULT":   thanosImage,
	"QUERY":           thanosImage,
	"QUERY_FRONTEND":  thanosImage,
	"THANOS_OPERATOR": fmt.Sprintf("%s:%s", thanosOperatorImage, thanosOperatorVersionProd),
	"KUBE_RBAC_PROXY": "registry.redhat.io/openshift4/ose-kube-rbac-proxy@sha256:98455d503b797b6b02edcfd37045c8fab0796b95ee5cf4cfe73b221a07e805f0",
	apiCache:          memcachedImage,
	memcachedExporter: memcachedExporterImage,
	observatoriumAPI:  "quay.io/redhat-user-workloads/rhobs-mco-tenant/observatorium-api:9aada65247a07782465beb500323a0e18d7e3d05",
	jaeger:            "registry.redhat.io/rhosdt/jaeger-agent-rhel8:1.57.0-10",
}

// ProductionVersions is a map of production versions.
var ProductionVersions = ParamMap[string]{
	"STORE02W":       thanosVersionProd,
	"STORE2W90D":     thanosVersionProd,
	"STORE90D+":      thanosVersionProd,
	"STORE_DEFAULT":  thanosVersionProd,
	"QUERY":          thanosVersionProd,
	"QUERY_FRONTEND": thanosVersionProd,
	apiCache:         memcachedTag,
	observatoriumAPI: "9aada65247a07782465beb500323a0e18d7e3d05",
}

// ProductionLogLevels is a map of production log levels.
var ProductionLogLevels = ParamMap[string]{
	"STORE02W":       logLevels[0],
	"STORE2W90D":     logLevels[0],
	"STORE90D+":      logLevels[0],
	"STORE_DEFAULT":  logLevels[0],
	"QUERY":          logLevels[0],
	"QUERY_FRONTEND": logLevels[0],
	observatoriumAPI: logLevels[0],
}

// ProductionStorageSize is a map of production PV storage sizes.
var ProductionStorageSize = ParamMap[v1alpha1.StorageSize]{
	"STORE02W":      "300Gi",
	"STORE2W90D":    "300Gi",
	"STORE90D+":     "300Gi",
	"STORE_DEFAULT": "300Gi",
}

// ProductionReplicas is a map of production replicas.
var ProductionReplicas = ParamMap[int32]{
	"STORE02W":       2,
	"STORE2W90D":     2,
	"STORE90D+":      1,
	"STORE_DEFAULT":  2,
	"QUERY":          3,
	"QUERY_FRONTEND": 3,
	apiCache:         1,
	observatoriumAPI: 2,
}

// ProductionResourceRequirements is a map of production resource requirements.
var ProductionResourceRequirements = ParamMap[corev1.ResourceRequirements]{
	"STORE02W": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("50m"),
			corev1.ResourceMemory: resource.MustParse("512Mi"),
		},
	},
	"STORE2W90D": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("50m"),
			corev1.ResourceMemory: resource.MustParse("512Mi"),
		},
	},
	"STORE90D+": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("50m"),
			corev1.ResourceMemory: resource.MustParse("512Mi"),
		},
	},
	"STORE_DEFAULT": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("50m"),
			corev1.ResourceMemory: resource.MustParse("512Mi"),
		},
	},
	"QUERY": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("300m"),
			corev1.ResourceMemory: resource.MustParse("1Gi"),
		},
	},
	"QUERY_FRONTEND": corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("100m"),
			corev1.ResourceMemory: resource.MustParse("500Mi"),
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
	observatoriumAPI: corev1.ResourceRequirements{
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("1"),
			corev1.ResourceMemory: resource.MustParse("2Gi"),
		},
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("100m"),
			corev1.ResourceMemory: resource.MustParse("100Mi"),
		},
	},
}

// ProductionObjectStorageBucket is a map of production object storage buckets.
var ProductionObjectStorageBucket = ParamMap[v1alpha1.ObjectStorageConfig]{
	"DEFAULT": v1alpha1.ObjectStorageConfig{
		Key: "thanos.yaml",
		LocalObjectReference: corev1.LocalObjectReference{
			Name: "observatorium-mst-thanos-objectstorage",
		},
		Optional: ptr.To(false),
	},
	"TELEMETER": v1alpha1.ObjectStorageConfig{
		Key: "thanos.yaml",
		LocalObjectReference: corev1.LocalObjectReference{
			Name: "thanos-objectstorage",
		},
		Optional: ptr.To(false),
	},
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

var ProductionMaps = TemplateMaps{
	Images:               ProductionImages,
	Versions:             ProductionVersions,
	LogLevels:            ProductionLogLevels,
	StorageSize:          ProductionStorageSize,
	Replicas:             ProductionReplicas,
	ResourceRequirements: ProductionResourceRequirements,
	ObjectStorageBucket:  ProductionObjectStorageBucket,
}

const (
	localThanosImage   = "quay.io/thanos/thanos"
	localThanosVersion = "v0.37.2"
)

var LocalMaps = TemplateMaps{
	Images:               LocalImages,
	Versions:             LocalVersions,
	LogLevels:            StageLogLevels,
	StorageSize:          LocalStorageSize,
	Replicas:             StageReplicas,
	ResourceRequirements: LocalResourceRequirements,
	ObjectStorageBucket:  StageObjectStorageBucket,
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

// Local images.
var LocalImages = ParamMap[string]{
	"STORE02W":                   localThanosImage,
	"STORE2W90D":                 localThanosImage,
	"STORE90D+":                  localThanosImage,
	"STORE_DEFAULT":              localThanosImage,
	"RECEIVE_ROUTER":             localThanosImage,
	"RECEIVE_INGESTOR_TELEMETER": localThanosImage,
	"RECEIVE_INGESTOR_DEFAULT":   localThanosImage,
	"RULER":                      localThanosImage,
	"COMPACT_DEFAULT":            localThanosImage,
	"COMPACT_TELEMETER":          localThanosImage,
	"QUERY":                      localThanosImage,
	"QUERY_FRONTEND":             localThanosImage,
	jaeger:                       "quay.io/jaegertracing/jaeger-agent:1.57.0",
	"THANOS_OPERATOR":            "quay.io/thanos/thanos-operator:main-2025-02-07-f1e3fa9",
	"KUBE_RBAC_PROXY":            "gcr.io/kubebuilder/kube-rbac-proxy:v0.16.0",
}

// Local images.
var LocalVersions = ParamMap[string]{
	"STORE02W":                   localThanosVersion,
	"STORE2W90D":                 localThanosVersion,
	"STORE90D+":                  localThanosVersion,
	"STORE_DEFAULT":              localThanosVersion,
	"RECEIVE_ROUTER":             localThanosVersion,
	"RECEIVE_INGESTOR_TELEMETER": localThanosVersion,
	"RECEIVE_INGESTOR_DEFAULT":   localThanosVersion,
	"RULER":                      localThanosVersion,
	"COMPACT_DEFAULT":            localThanosVersion,
	"COMPACT_TELEMETER":          localThanosVersion,
	"QUERY":                      localThanosVersion,
	"QUERY_FRONTEND":             localThanosVersion,
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
