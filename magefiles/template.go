package main

import (
	"fmt"

	"github.com/thanos-community/thanos-operator/api/v1alpha1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/utils/ptr"
)

type ParamMap[T any] map[string]T

// Stage images.
var StageImages = ParamMap[string]{
	"STORE02W":                   "quay.io/thanos/thanos:v0.37.2",
	"STORE2W90D":                 "quay.io/thanos/thanos:v0.37.2",
	"STORE90D+":                  "quay.io/thanos/thanos:v0.37.2",
	"STORE_DEFAULT":              "quay.io/thanos/thanos:v0.37.2",
	"RECEIVE_ROUTER":             "quay.io/thanos/thanos:v0.37.2",
	"RECEIVE_INGESTOR_TELEMETER": "quay.io/thanos/thanos:v0.37.2",
	"RECEIVE_INGESTOR_DEFAULT":   "quay.io/thanos/thanos:v0.37.2",
	"RULER":                      "quay.io/thanos/thanos:v0.37.2",
	"COMPACT_DEFAULT":            "quay.io/thanos/thanos:v0.37.2",
	"COMPACT_TELEMETER":          "quay.io/thanos/thanos:v0.37.2",
	"QUERY":                      "quay.io/thanos/thanos:v0.37.2",
	"QUERY_FRONTEND":             "quay.io/thanos/thanos:v0.37.2",
}

// Stage PV storage sizes.
var StageStorageSize = ParamMap[v1alpha1.StorageSize]{
	"STORE02W":          "5GiB",
	"STORE2W90D":        "5GiB",
	"STORE90D+":         "5GiB",
	"STORE_DEFAULT":     "15GiB",
	"RECEIVE_TELEMETER": "10GiB",
	"RECEIVE_DEFAULT":   "15GiB",
	"RULER":             "5GiB",
	"COMPACT_DEFAULT":   "1GiB",
	"COMPACT_TELEMETER": "2GiB",
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

// Stage template function.
// It panics if the param is not found in the map.
// It returns the value of the param.
func stageTemplateFn[T any](param string, m ParamMap[T]) T {
	v, ok := m[param]
	if !ok {
		panic(fmt.Sprintf("param %s not found in stage", param))
	}
	return v
}
