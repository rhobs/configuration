package main

import (
	"log"
	"sort"

	kghelpers "github.com/observatorium/observatorium/configuration_go/kubegen/helpers"
	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	routev1 "github.com/openshift/api/route/v1"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic/encoding"
	"github.com/rhobs/configuration/clusters"
	"github.com/thanos-community/thanos-operator/api/v1alpha1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/intstr"
	"k8s.io/utils/ptr"
)

func (b Build) DefaultThanosStack(config clusters.ClusterConfig) {
	gen := b.generator(config, "thanos-operator-default-cr")
	var objs []runtime.Object

	objs = append(objs, defaultQueryCR(config.Namespace, config.Templates, true)...)
	objs = append(objs, defaultReceiveCR(config.Namespace, config.Templates))
	objs = append(objs, defaultCompactCR(config.Namespace, config.Templates))
	objs = append(objs, defaultRulerCR(config.Namespace, config.Templates))
	objs = append(objs, defaultStoreCR(config.Namespace, config.Templates))

	// Sort objects by Kind then Name
	sort.Slice(objs, func(i, j int) bool {
		iMeta := objs[i].(metav1.Object)
		jMeta := objs[j].(metav1.Object)
		iType := objs[i].GetObjectKind().GroupVersionKind().Kind
		jType := objs[j].GetObjectKind().GroupVersionKind().Kind

		if iType != jType {
			return iType < jType
		}
		return iMeta.GetName() < jMeta.GetName()
	})

	gen.Add("thanos-operator-default-cr.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			objs,
			metav1.ObjectMeta{Name: "thanos-rhobs"},
			[]templatev1.Parameter{
				{
					Name:     "OAUTH_PROXY_COOKIE_SECRET",
					Generate: "expression",
					From:     `[a-zA-Z0-9]{40}`,
				},
			},
		),
	))

	gen.Generate()
}

// Thanos Generates the RHOBS-specific CRs for Thanos Operator.
func (p Production) Thanos() {
	templateDir := "rhobs-thanos-operator"

	gen := p.generator(templateDir)
	ns := p.namespace()
	var objs []runtime.Object

	tmpAdditionalQueryArgs := []string{
		`--rule=dnssrv+_grpc._tcp.observatorium-thanos-rule.observatorium-metrics-production.svc.cluster.local`,
		`--endpoint=dnssrv+_grpc._tcp.observatorium-thanos-receive-default.observatorium-metrics-production.svc.cluster.local`,
	}

	objs = append(objs, queryCR(ns, clusters.ProductionMaps, true, tmpAdditionalQueryArgs...)...)
	objs = append(objs, tmpStoreProduction(ns, clusters.ProductionMaps)...)
	objs = append(objs, compactTempProduction(clusters.ProductionMaps)...)

	// Sort objects by Kind then Name
	sort.Slice(objs, func(i, j int) bool {
		iMeta := objs[i].(metav1.Object)
		jMeta := objs[j].(metav1.Object)
		iType := objs[i].GetObjectKind().GroupVersionKind().Kind
		jType := objs[j].GetObjectKind().GroupVersionKind().Kind

		if iType != jType {
			return iType < jType
		}
		return iMeta.GetName() < jMeta.GetName()
	})

	gen.Add("rhobs.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			objs,
			metav1.ObjectMeta{Name: "thanos-rhobs"},
			[]templatev1.Parameter{
				{
					Name:     "OAUTH_PROXY_COOKIE_SECRET",
					Generate: "expression",
					From:     `[a-zA-Z0-9]{40}`,
				},
			},
		),
	))

	gen.Generate()
}

// Thanos Generates the RHOBS-specific CRs for Thanos Operator.
func (s Stage) Thanos() {
	templateDir := "rhobs-thanos-operator"

	gen := s.generator(templateDir)

	var objs []runtime.Object

	objs = append(objs, receiveCR(s.namespace(), clusters.StageMaps))
	objs = append(objs, queryCR(s.namespace(), clusters.StageMaps, true)...)
	objs = append(objs, rulerCR(s.namespace(), clusters.StageMaps))
	// TODO: Add compact CRs for stage once we shut down previous
	// objs = append(objs, compactCR(s.namespace(), templates, true)...)
	objs = append(objs, stageCompactCR(s.namespace(), clusters.StageMaps)...)
	objs = append(objs, storeCR(s.namespace(), clusters.StageMaps)...)

	// Sort objects by Kind then Name
	sort.Slice(objs, func(i, j int) bool {
		iMeta := objs[i].(metav1.Object)
		jMeta := objs[j].(metav1.Object)
		iType := objs[i].GetObjectKind().GroupVersionKind().Kind
		jType := objs[j].GetObjectKind().GroupVersionKind().Kind

		if iType != jType {
			return iType < jType
		}
		return iMeta.GetName() < jMeta.GetName()
	})

	gen.Add("rhobs.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			objs,
			metav1.ObjectMeta{Name: "thanos-rhobs"},
			[]templatev1.Parameter{
				{
					Name:     "OAUTH_PROXY_COOKIE_SECRET",
					Generate: "expression",
					From:     `[a-zA-Z0-9]{40}`,
				},
			},
		),
	))

	gen.Generate()
}

// Thanos Generates the RHOBS-specific CRs for Thanos Operator for a local environment.
func (l Local) Thanos() {
	templateDir := "rhobs-thanos-operator"

	gen := l.generator(templateDir)

	var objs []runtime.Object

	objs = append(objs, receiveCR(l.namespace(), clusters.LocalMaps))
	objs = append(objs, queryCR(l.namespace(), clusters.LocalMaps, false)...)
	objs = append(objs, rulerCR(l.namespace(), clusters.LocalMaps))
	objs = append(objs, compactCR(l.namespace(), clusters.LocalMaps, false)...)
	objs = append(objs, storeCR(l.namespace(), clusters.LocalMaps)...)

	// Sort objects by Kind then Name
	sort.Slice(objs, func(i, j int) bool {
		iMeta := objs[i].(metav1.Object)
		jMeta := objs[j].(metav1.Object)
		iType := objs[i].GetObjectKind().GroupVersionKind().Kind
		jType := objs[j].GetObjectKind().GroupVersionKind().Kind

		if iType != jType {
			return iType < jType
		}
		return iMeta.GetName() < jMeta.GetName()
	})

	gen.Add("rhobs.yaml", encoding.GhodssYAML(
		objs[0],
		objs[1],
		objs[2],
		objs[3],
		objs[4],
		objs[5],
		objs[6],
		objs[7],
		objs[8],
	))

	gen.Generate()
}

// tracingSidecar is the jaeger-agent sidecar container for tracing.
func tracingSidecar(m clusters.TemplateMaps) corev1.Container {
	return corev1.Container{
		Name:            "jaeger-agent",
		Image:           clusters.TemplateFn(clusters.Jaeger, m.Images),
		ImagePullPolicy: corev1.PullIfNotPresent,
		Args: []string{
			"--reporter.grpc.host-port=dns:///otel-trace-writer-collector-headless.observatorium-tools.svc:14250",
			"--reporter.type=grpc",
			"--agent.tags=pod.namespace=$(NAMESPACE),pod.name=$(POD)",
		},
		Env: []corev1.EnvVar{
			{
				Name: "NAMESPACE",
				ValueFrom: &corev1.EnvVarSource{
					FieldRef: &corev1.ObjectFieldSelector{
						FieldPath: "metadata.namespace",
					},
				},
			},
			{
				Name: "POD",
				ValueFrom: &corev1.EnvVarSource{
					FieldRef: &corev1.ObjectFieldSelector{
						FieldPath: "metadata.name",
					},
				},
			},
		},
		Ports: []corev1.ContainerPort{
			{
				ContainerPort: 5778,
				Name:          "configs",
			},
			{
				ContainerPort: 6831,
				Name:          "jaeger-thrift",
			},
			{
				ContainerPort: 14271,
				Name:          "metrics",
			},
		},
		ReadinessProbe: &corev1.Probe{
			ProbeHandler: corev1.ProbeHandler{
				HTTPGet: &corev1.HTTPGetAction{
					Path:   "/",
					Port:   intstr.FromInt(14271),
					Scheme: corev1.URISchemeHTTP,
				},
			},
			InitialDelaySeconds: 1,
		},
		LivenessProbe: &corev1.Probe{
			ProbeHandler: corev1.ProbeHandler{
				HTTPGet: &corev1.HTTPGetAction{
					Path:   "/",
					Port:   intstr.FromInt(14271),
					Scheme: corev1.URISchemeHTTP,
				},
			},
			FailureThreshold:    5,
			InitialDelaySeconds: 1,
		},
		Resources: corev1.ResourceRequirements{
			Requests: corev1.ResourceList{
				corev1.ResourceCPU:    resource.MustParse("32m"),
				corev1.ResourceMemory: resource.MustParse("64Mi"),
			},
			Limits: corev1.ResourceList{
				corev1.ResourceCPU:    resource.MustParse("128m"),
				corev1.ResourceMemory: resource.MustParse("128Mi"),
			},
		},
	}
}

func storeCR(namespace string, m clusters.TemplateMaps) []runtime.Object {
	store0to2w := &v1alpha1.ThanosStore{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosStore",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "telemeter-0to2w",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosStoreSpec{
			CommonFields: v1alpha1.CommonFields{
				Image:                ptr.To(clusters.TemplateFn("STORE02W", m.Images)),
				Version:              ptr.To(clusters.TemplateFn("STORE02W", m.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn("STORE02W", m.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn("STORE02W", m.ResourceRequirements)),
			},
			Replicas:            clusters.TemplateFn("STORE02W", m.Replicas),
			ObjectStorageConfig: clusters.TemplateFn("TELEMETER", m.ObjectStorageBucket),
			ShardingStrategy: v1alpha1.ShardingStrategy{
				Type:   v1alpha1.Block,
				Shards: 1,
			},
			IndexHeaderConfig: &v1alpha1.IndexHeaderConfig{
				EnableLazyReader:      ptr.To(true),
				LazyDownloadStrategy:  ptr.To("lazy"),
				LazyReaderIdleTimeout: ptr.To(v1alpha1.Duration("5m")),
			},
			StoreLimitsOptions: &v1alpha1.StoreLimitsOptions{
				StoreLimitsRequestSamples: 627040000,
				StoreLimitsRequestSeries:  1000000,
			},
			BlockConfig: &v1alpha1.BlockConfig{
				BlockDiscoveryStrategy:    v1alpha1.BlockDiscoveryStrategy("concurrent"),
				BlockFilesConcurrency:     ptr.To(int32(1)),
				BlockMetaFetchConcurrency: ptr.To(int32(32)),
			},
			IgnoreDeletionMarksDelay: v1alpha1.Duration("24h"),
			TimeRangeConfig: &v1alpha1.TimeRangeConfig{
				MaxTime: ptr.To(v1alpha1.Duration("-2w")),
			},
			StorageSize: clusters.TemplateFn("STORE02W", m.StorageSize),
			Additional: v1alpha1.Additional{
				Containers: []corev1.Container{
					tracingSidecar(m),
				},
				Args: []string{
					`--tracing.config="config":
  "sampler_param": 2
  "sampler_type": "ratelimiting"
  "service_name": "thanos-store"
"type": "JAEGER"`,
				},
			},
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}

	store2wto90d := &v1alpha1.ThanosStore{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosStore",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "telemeter-2wto90d",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosStoreSpec{
			CommonFields: v1alpha1.CommonFields{
				Image:                ptr.To(clusters.TemplateFn("STORE2W90D", m.Images)),
				Version:              ptr.To(clusters.TemplateFn("STORE2W90D", m.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn("STORE2W90D", m.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn("STORE2W90D", m.ResourceRequirements)),
			},
			Replicas:            clusters.TemplateFn("STORE2W90D", m.Replicas),
			ObjectStorageConfig: clusters.TemplateFn("TELEMETER", m.ObjectStorageBucket),
			ShardingStrategy: v1alpha1.ShardingStrategy{
				Type:   v1alpha1.Block,
				Shards: 1,
			},
			IndexHeaderConfig: &v1alpha1.IndexHeaderConfig{
				EnableLazyReader:      ptr.To(true),
				LazyDownloadStrategy:  ptr.To("lazy"),
				LazyReaderIdleTimeout: ptr.To(v1alpha1.Duration("5m")),
			},
			StoreLimitsOptions: &v1alpha1.StoreLimitsOptions{
				StoreLimitsRequestSamples: 627040000,
				StoreLimitsRequestSeries:  1000000,
			},
			BlockConfig: &v1alpha1.BlockConfig{
				BlockDiscoveryStrategy:    v1alpha1.BlockDiscoveryStrategy("concurrent"),
				BlockFilesConcurrency:     ptr.To(int32(1)),
				BlockMetaFetchConcurrency: ptr.To(int32(32)),
			},
			IgnoreDeletionMarksDelay: v1alpha1.Duration("24h"),
			TimeRangeConfig: &v1alpha1.TimeRangeConfig{
				MinTime: ptr.To(v1alpha1.Duration("-90d")),
				MaxTime: ptr.To(v1alpha1.Duration("-2w")),
			},
			StorageSize: clusters.TemplateFn("STORE2W90D", m.StorageSize),
			Additional: v1alpha1.Additional{
				Containers: []corev1.Container{
					tracingSidecar(m),
				},
				Args: []string{
					`--tracing.config="config":
  "sampler_param": 2
  "sampler_type": "ratelimiting"
  "service_name": "thanos-store"
"type": "JAEGER"`,
				},
			},
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
				PodDisruptionBudgetConfig: &v1alpha1.PodDisruptionBudgetConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}

	store90dplus := &v1alpha1.ThanosStore{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosStore",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "telemeter-90dplus",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosStoreSpec{
			CommonFields: v1alpha1.CommonFields{
				Image:                ptr.To(clusters.TemplateFn("STORE90D+", m.Images)),
				Version:              ptr.To(clusters.TemplateFn("STORE90D+", m.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn("STORE90D+", m.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn("STORE90D+", m.ResourceRequirements)),
			},
			Replicas:            clusters.TemplateFn("STORE90D+", m.Replicas),
			ObjectStorageConfig: clusters.TemplateFn("TELEMETER", m.ObjectStorageBucket),
			ShardingStrategy: v1alpha1.ShardingStrategy{
				Type:   v1alpha1.Block,
				Shards: 1,
			},
			IndexHeaderConfig: &v1alpha1.IndexHeaderConfig{
				EnableLazyReader:      ptr.To(true),
				LazyDownloadStrategy:  ptr.To("lazy"),
				LazyReaderIdleTimeout: ptr.To(v1alpha1.Duration("5m")),
			},
			StoreLimitsOptions: &v1alpha1.StoreLimitsOptions{
				StoreLimitsRequestSamples: 627040000,
				StoreLimitsRequestSeries:  1000000,
			},
			BlockConfig: &v1alpha1.BlockConfig{
				BlockDiscoveryStrategy:    v1alpha1.BlockDiscoveryStrategy("concurrent"),
				BlockFilesConcurrency:     ptr.To(int32(1)),
				BlockMetaFetchConcurrency: ptr.To(int32(32)),
			},
			IgnoreDeletionMarksDelay: v1alpha1.Duration("24h"),
			TimeRangeConfig: &v1alpha1.TimeRangeConfig{
				MinTime: ptr.To(v1alpha1.Duration("-90d")),
			},
			StorageSize: clusters.TemplateFn("STORE90D+", m.StorageSize),
			Additional: v1alpha1.Additional{
				Containers: []corev1.Container{
					tracingSidecar(m),
				},
				Args: []string{
					`--tracing.config="config":
  "sampler_param": 2
  "sampler_type": "ratelimiting"
  "service_name": "thanos-store"
"type": "JAEGER"`,
				},
			},
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}

	// RHOBS-904: Standalone Store for RH Resource Optimisation (ROS) Managed Service
	storeRos := &v1alpha1.ThanosStore{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosStore",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "ros",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosStoreSpec{
			CommonFields: v1alpha1.CommonFields{
				Image:                ptr.To(clusters.TemplateFn("STORE_ROS", m.Images)),
				Version:              ptr.To(clusters.TemplateFn("STORE_ROS", m.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn("STORE_ROS", m.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn("STORE_ROS", m.ResourceRequirements)),
			},
			Replicas:            clusters.TemplateFn("STORE_ROS", m.Replicas),
			ObjectStorageConfig: clusters.TemplateFn("ROS", m.ObjectStorageBucket),
			ShardingStrategy: v1alpha1.ShardingStrategy{
				Type:   v1alpha1.Block,
				Shards: 1,
			},
			IndexHeaderConfig: &v1alpha1.IndexHeaderConfig{
				EnableLazyReader:      ptr.To(true),
				LazyDownloadStrategy:  ptr.To("lazy"),
				LazyReaderIdleTimeout: ptr.To(v1alpha1.Duration("5m")),
			},
			StoreLimitsOptions: &v1alpha1.StoreLimitsOptions{
				StoreLimitsRequestSamples: 0,
				StoreLimitsRequestSeries:  0,
			},
			BlockConfig: &v1alpha1.BlockConfig{
				BlockDiscoveryStrategy:    v1alpha1.BlockDiscoveryStrategy("concurrent"),
				BlockFilesConcurrency:     ptr.To(int32(1)),
				BlockMetaFetchConcurrency: ptr.To(int32(32)),
			},
			IgnoreDeletionMarksDelay: v1alpha1.Duration("24h"),
			StorageSize:              clusters.TemplateFn("STORE_ROS", m.StorageSize),
			Additional: v1alpha1.Additional{
				Containers: []corev1.Container{
					tracingSidecar(m),
				},
				Args: []string{
					`--tracing.config="config":
  "sampler_param": 2
  "sampler_type": "ratelimiting"
  "service_name": "thanos-store"
"type": "JAEGER"`,
				},
			},
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}

	storeDefault := &v1alpha1.ThanosStore{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosStore",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "default",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosStoreSpec{
			CommonFields: v1alpha1.CommonFields{
				Image:                ptr.To(clusters.TemplateFn("STORE_DEFAULT", m.Images)),
				Version:              ptr.To(clusters.TemplateFn("STORE_DEFAULT", m.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn("STORE_DEFAULT", m.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn("STORE_DEFAULT", m.ResourceRequirements)),
			},
			Replicas:            clusters.TemplateFn("STORE_DEFAULT", m.Replicas),
			ObjectStorageConfig: clusters.TemplateFn("DEFAULT", m.ObjectStorageBucket),
			ShardingStrategy: v1alpha1.ShardingStrategy{
				Type:   v1alpha1.Block,
				Shards: 1,
			},
			IndexHeaderConfig: &v1alpha1.IndexHeaderConfig{
				EnableLazyReader:      ptr.To(true),
				LazyDownloadStrategy:  ptr.To("lazy"),
				LazyReaderIdleTimeout: ptr.To(v1alpha1.Duration("5m")),
			},
			StoreLimitsOptions: &v1alpha1.StoreLimitsOptions{
				StoreLimitsRequestSamples: 0,
				StoreLimitsRequestSeries:  0,
			},
			BlockConfig: &v1alpha1.BlockConfig{
				BlockDiscoveryStrategy:    v1alpha1.BlockDiscoveryStrategy("concurrent"),
				BlockFilesConcurrency:     ptr.To(int32(1)),
				BlockMetaFetchConcurrency: ptr.To(int32(32)),
			},
			IgnoreDeletionMarksDelay: v1alpha1.Duration("24h"),
			TimeRangeConfig: &v1alpha1.TimeRangeConfig{
				MaxTime: ptr.To(v1alpha1.Duration("-22h")),
			},
			StorageSize: clusters.TemplateFn("STORE_DEFAULT", m.StorageSize),
			Additional: v1alpha1.Additional{
				Containers: []corev1.Container{
					tracingSidecar(m),
				},
				Args: []string{
					`--tracing.config="config":
  "sampler_param": 2
  "sampler_type": "ratelimiting"
  "service_name": "thanos-store"
"type": "JAEGER"`,
				},
			},
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}

	objs := []runtime.Object{store0to2w, store2wto90d, store90dplus, storeDefault}

	//TODO @moadz RHOBS-904: Temporary block, only return in stage
	if clusters.TemplateFn("STORE_ROS", m.Replicas) > 0 {
		objs = append(objs, storeRos)
	}

	return objs
}

func tmpStoreProduction(namespace string, m clusters.TemplateMaps) []runtime.Object {
	iC := `--index-cache.config="config":
  "addresses":
    - "dnssrv+_client._tcp.thanos-index-cache.rhobs-production.svc"
  "dns_provider_update_interval": "30s"
  "max_async_buffer_size": 50000000
  "max_async_concurrency": 1000
  "max_get_multi_batch_size": 1000
  "max_get_multi_concurrency": 100
  "max_idle_connections": 500
  "max_item_size": "1000MiB"
  "timeout": "5s"
"type": "memcached"`

	inMem := `--index-cache.config="config":
  "max_size": "10000MB"
  "max_item_size": "1000MB"
"type": "IN-MEMORY"`

	bc := `--store.caching-bucket.config=
  "type": "memcached"
  "blocks_iter_ttl": "10m"
  "chunk_object_attrs_ttl": "48h"
  "chunk_subrange_size": 16000
  "chunk_subrange_ttl": "48h"
  "metafile_content_ttl": "48h"
  "metafile_doesnt_exist_ttl": "30m"
  "metafile_exists_ttl": "24h"
  "metafile_max_size": "20MiB"
  "max_chunks_get_range_requests": 5
  "config":
    "addresses":
      - "dnssrv+_client._tcp.thanos-bucket-cache.rhobs-production.svc"
    "dns_provider_update_interval": "30s"
    "max_async_buffer_size": 1000000
    "max_async_concurrency": 100
    "max_get_multi_batch_size": 500
    "max_get_multi_concurrency": 100
    "max_idle_connections": 500
    "max_item_size": "500MiB"
    "timeout": "5s"`

	additionalCacheArgs := v1alpha1.Additional{
		Args: []string{
			inMem,
		},
	}

	zero2wArgs := v1alpha1.Additional{
		Args: []string{
			bc,
			iC,
		},
	}

	store0to2w := &v1alpha1.ThanosStore{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosStore",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "telemeter-0to2w",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosStoreSpec{
			Additional: zero2wArgs,
			CommonFields: v1alpha1.CommonFields{
				Affinity: &corev1.Affinity{
					NodeAffinity: &corev1.NodeAffinity{
						RequiredDuringSchedulingIgnoredDuringExecution: &corev1.NodeSelector{
							NodeSelectorTerms: []corev1.NodeSelectorTerm{
								{
									MatchExpressions: []corev1.NodeSelectorRequirement{
										{
											Key:      "workload-type",
											Operator: corev1.NodeSelectorOpIn,
											Values:   []string{"query"},
										},
									},
								},
							},
						},
					},
					PodAntiAffinity: &corev1.PodAntiAffinity{
						RequiredDuringSchedulingIgnoredDuringExecution: []corev1.PodAffinityTerm{
							{
								TopologyKey: "kubernetes.io/hostname",
								LabelSelector: &metav1.LabelSelector{
									MatchExpressions: []metav1.LabelSelectorRequirement{
										{
											Key:      "app.kubernetes.io/instance",
											Operator: metav1.LabelSelectorOpIn,
											Values:   []string{"telemeter-0to2w"},
										},
									},
								},
							},
						},
					},
				},
				Image:                ptr.To(clusters.TemplateFn("STORE02W", m.Images)),
				Version:              ptr.To(clusters.TemplateFn("STORE02W", m.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn("STORE02W", m.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn("STORE02W", m.ResourceRequirements)),
			},
			Replicas:            clusters.TemplateFn("STORE02W", m.Replicas),
			ObjectStorageConfig: clusters.TemplateFn("TELEMETER", m.ObjectStorageBucket),
			ShardingStrategy: v1alpha1.ShardingStrategy{
				Type:   v1alpha1.Block,
				Shards: 1,
			},
			IndexHeaderConfig: &v1alpha1.IndexHeaderConfig{
				EnableLazyReader:      ptr.To(true),
				LazyReaderIdleTimeout: ptr.To(v1alpha1.Duration("5m")),
			},
			StoreLimitsOptions: &v1alpha1.StoreLimitsOptions{
				StoreLimitsRequestSamples: 0,
				StoreLimitsRequestSeries:  0,
			},
			BlockConfig: &v1alpha1.BlockConfig{
				BlockDiscoveryStrategy:    v1alpha1.BlockDiscoveryStrategy("concurrent"),
				BlockFilesConcurrency:     ptr.To(int32(1)),
				BlockMetaFetchConcurrency: ptr.To(int32(32)),
			},
			IgnoreDeletionMarksDelay: v1alpha1.Duration("12h"),
			TimeRangeConfig: &v1alpha1.TimeRangeConfig{
				MinTime: ptr.To(v1alpha1.Duration("-336h")),
			},
			StorageSize: clusters.TemplateFn("STORE02W", m.StorageSize),
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}

	store2wto90d := &v1alpha1.ThanosStore{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosStore",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "telemeter-2wto90d",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosStoreSpec{
			Additional: additionalCacheArgs,
			CommonFields: v1alpha1.CommonFields{
				Affinity: &corev1.Affinity{
					NodeAffinity: &corev1.NodeAffinity{
						RequiredDuringSchedulingIgnoredDuringExecution: &corev1.NodeSelector{
							NodeSelectorTerms: []corev1.NodeSelectorTerm{
								{
									MatchExpressions: []corev1.NodeSelectorRequirement{
										{
											Key:      "workload-type",
											Operator: corev1.NodeSelectorOpIn,
											Values:   []string{"query"},
										},
									},
								},
							},
						},
					},
					PodAntiAffinity: &corev1.PodAntiAffinity{
						RequiredDuringSchedulingIgnoredDuringExecution: []corev1.PodAffinityTerm{
							{
								TopologyKey: "kubernetes.io/hostname",
								LabelSelector: &metav1.LabelSelector{
									MatchExpressions: []metav1.LabelSelectorRequirement{
										{
											Key:      "app.kubernetes.io/instance",
											Operator: metav1.LabelSelectorOpIn,
											Values:   []string{"telemeter-2wto90d"},
										},
									},
								},
							},
						},
					},
				},
				Image:                ptr.To(clusters.TemplateFn("STORE2W90D", m.Images)),
				Version:              ptr.To(clusters.TemplateFn("STORE2W90D", m.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn("STORE2W90D", m.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn("STORE2W90D", m.ResourceRequirements)),
			},
			Replicas:            clusters.TemplateFn("STORE2W90D", m.Replicas),
			ObjectStorageConfig: clusters.TemplateFn("TELEMETER", m.ObjectStorageBucket),
			ShardingStrategy: v1alpha1.ShardingStrategy{
				Type:   v1alpha1.Block,
				Shards: 1,
			},
			IndexHeaderConfig: &v1alpha1.IndexHeaderConfig{
				EnableLazyReader:      ptr.To(true),
				LazyDownloadStrategy:  ptr.To("lazy"),
				LazyReaderIdleTimeout: ptr.To(v1alpha1.Duration("5m")),
			},
			StoreLimitsOptions: &v1alpha1.StoreLimitsOptions{
				StoreLimitsRequestSamples: 0,
				StoreLimitsRequestSeries:  0,
			},
			BlockConfig: &v1alpha1.BlockConfig{
				BlockDiscoveryStrategy:    v1alpha1.BlockDiscoveryStrategy("concurrent"),
				BlockFilesConcurrency:     ptr.To(int32(1)),
				BlockMetaFetchConcurrency: ptr.To(int32(32)),
			},
			IgnoreDeletionMarksDelay: v1alpha1.Duration("24h"),
			TimeRangeConfig: &v1alpha1.TimeRangeConfig{
				MinTime: ptr.To(v1alpha1.Duration("-2160h")),
				MaxTime: ptr.To(v1alpha1.Duration("-336h")),
			},
			StorageSize: clusters.TemplateFn("STORE2W90D", m.StorageSize),
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
				PodDisruptionBudgetConfig: &v1alpha1.PodDisruptionBudgetConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}

	store90dplus := &v1alpha1.ThanosStore{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosStore",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "telemeter-90dplus",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosStoreSpec{
			Additional: additionalCacheArgs,
			CommonFields: v1alpha1.CommonFields{
				Affinity: &corev1.Affinity{
					NodeAffinity: &corev1.NodeAffinity{
						RequiredDuringSchedulingIgnoredDuringExecution: &corev1.NodeSelector{
							NodeSelectorTerms: []corev1.NodeSelectorTerm{
								{
									MatchExpressions: []corev1.NodeSelectorRequirement{
										{
											Key:      "workload-type",
											Operator: corev1.NodeSelectorOpIn,
											Values:   []string{"query"},
										},
									},
								},
							},
						},
					},
					PodAntiAffinity: &corev1.PodAntiAffinity{
						RequiredDuringSchedulingIgnoredDuringExecution: []corev1.PodAffinityTerm{
							{
								TopologyKey: "kubernetes.io/hostname",
								LabelSelector: &metav1.LabelSelector{
									MatchExpressions: []metav1.LabelSelectorRequirement{
										{
											Key:      "app.kubernetes.io/instance",
											Operator: metav1.LabelSelectorOpIn,
											Values:   []string{"telemeter-90dplus"},
										},
									},
								},
							},
						},
					},
				},
				Image:                ptr.To(clusters.TemplateFn("STORE90D+", m.Images)),
				Version:              ptr.To(clusters.TemplateFn("STORE90D+", m.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn("STORE90D+", m.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn("STORE90D+", m.ResourceRequirements)),
			},
			Replicas:            clusters.TemplateFn("STORE90D+", m.Replicas),
			ObjectStorageConfig: clusters.TemplateFn("TELEMETER", m.ObjectStorageBucket),
			ShardingStrategy: v1alpha1.ShardingStrategy{
				Type:   v1alpha1.Block,
				Shards: 1,
			},
			IndexHeaderConfig: &v1alpha1.IndexHeaderConfig{
				EnableLazyReader:      ptr.To(true),
				LazyDownloadStrategy:  ptr.To("lazy"),
				LazyReaderIdleTimeout: ptr.To(v1alpha1.Duration("5m")),
			},
			StoreLimitsOptions: &v1alpha1.StoreLimitsOptions{
				StoreLimitsRequestSamples: 0,
				StoreLimitsRequestSeries:  0,
			},
			BlockConfig: &v1alpha1.BlockConfig{
				BlockDiscoveryStrategy:    v1alpha1.BlockDiscoveryStrategy("concurrent"),
				BlockFilesConcurrency:     ptr.To(int32(1)),
				BlockMetaFetchConcurrency: ptr.To(int32(32)),
			},
			IgnoreDeletionMarksDelay: v1alpha1.Duration("24h"),
			TimeRangeConfig: &v1alpha1.TimeRangeConfig{
				MinTime: ptr.To(v1alpha1.Duration("-8760h")),
				MaxTime: ptr.To(v1alpha1.Duration("-2160h")),
			},
			StorageSize: clusters.TemplateFn("STORE90D+", m.StorageSize),
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}

	storeDefault := &v1alpha1.ThanosStore{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosStore",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "default",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosStoreSpec{
			Additional: additionalCacheArgs,
			CommonFields: v1alpha1.CommonFields{
				Affinity: &corev1.Affinity{
					NodeAffinity: &corev1.NodeAffinity{
						RequiredDuringSchedulingIgnoredDuringExecution: &corev1.NodeSelector{
							NodeSelectorTerms: []corev1.NodeSelectorTerm{
								{
									MatchExpressions: []corev1.NodeSelectorRequirement{
										{
											Key:      "workload-type",
											Operator: corev1.NodeSelectorOpIn,
											Values:   []string{"query"},
										},
									},
								},
							},
						},
					},
					PodAntiAffinity: &corev1.PodAntiAffinity{
						RequiredDuringSchedulingIgnoredDuringExecution: []corev1.PodAffinityTerm{
							{
								TopologyKey: "kubernetes.io/hostname",
								LabelSelector: &metav1.LabelSelector{
									MatchExpressions: []metav1.LabelSelectorRequirement{
										{
											Key:      "app.kubernetes.io/instance",
											Operator: metav1.LabelSelectorOpIn,
											Values:   []string{"default"},
										},
									},
								},
							},
						},
					},
				},
				Image:                ptr.To(clusters.TemplateFn("STORE_DEFAULT", m.Images)),
				Version:              ptr.To(clusters.TemplateFn("STORE_DEFAULT", m.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn("STORE_DEFAULT", m.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn("STORE_DEFAULT", m.ResourceRequirements)),
			},
			Replicas:            clusters.TemplateFn("STORE_DEFAULT", m.Replicas),
			ObjectStorageConfig: clusters.TemplateFn("DEFAULT", m.ObjectStorageBucket),
			ShardingStrategy: v1alpha1.ShardingStrategy{
				Type:   v1alpha1.Block,
				Shards: 1,
			},
			IndexHeaderConfig: &v1alpha1.IndexHeaderConfig{
				EnableLazyReader:      ptr.To(true),
				LazyDownloadStrategy:  ptr.To("lazy"),
				LazyReaderIdleTimeout: ptr.To(v1alpha1.Duration("5m")),
			},
			StoreLimitsOptions: &v1alpha1.StoreLimitsOptions{
				StoreLimitsRequestSamples: 0,
				StoreLimitsRequestSeries:  0,
			},
			BlockConfig: &v1alpha1.BlockConfig{
				BlockDiscoveryStrategy:    v1alpha1.BlockDiscoveryStrategy("concurrent"),
				BlockFilesConcurrency:     ptr.To(int32(1)),
				BlockMetaFetchConcurrency: ptr.To(int32(32)),
			},
			IgnoreDeletionMarksDelay: v1alpha1.Duration("24h"),
			TimeRangeConfig: &v1alpha1.TimeRangeConfig{
				MaxTime: ptr.To(v1alpha1.Duration("-22h")),
			},
			StorageSize: clusters.TemplateFn("STORE_DEFAULT", m.StorageSize),
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}
	return []runtime.Object{store0to2w, store2wto90d, store90dplus, storeDefault}
}

func receiveCR(namespace string, templates clusters.TemplateMaps) *v1alpha1.ThanosReceive {
	return &v1alpha1.ThanosReceive{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosReceive",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "rhobs",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosReceiveSpec{
			Router: v1alpha1.RouterSpec{
				CommonFields: v1alpha1.CommonFields{
					Image:                ptr.To(clusters.TemplateFn("RECEIVE_ROUTER", templates.Images)),
					Version:              ptr.To(clusters.TemplateFn("RECEIVE_ROUTER", templates.Versions)),
					ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
					LogLevel:             ptr.To(clusters.TemplateFn("RECEIVE_ROUTER", templates.LogLevels)),
					LogFormat:            ptr.To("logfmt"),
					ResourceRequirements: ptr.To(clusters.TemplateFn("RECEIVE_ROUTER", templates.ResourceRequirements)),
				},
				Replicas:          clusters.TemplateFn("RECEIVE_ROUTER", templates.Replicas),
				ReplicationFactor: 3,
				ExternalLabels: map[string]string{
					"receive": "true",
				},
				Additional: v1alpha1.Additional{
					Containers: []corev1.Container{
						tracingSidecar(templates),
					},
					Args: []string{
						`--tracing.config="config":
  "sampler_param": 2
  "sampler_type": "ratelimiting"
  "service_name": "thanos-receive-router"
"type": "JAEGER"`,
					},
				},
			},
			Ingester: v1alpha1.IngesterSpec{
				DefaultObjectStorageConfig: clusters.TemplateFn("TELEMETER", templates.ObjectStorageBucket),
				Additional: v1alpha1.Additional{
					Containers: []corev1.Container{
						tracingSidecar(templates),
					},
					Args: []string{
						`--tracing.config="config":
  "sampler_param": 2
  "sampler_type": "ratelimiting"
  "service_name": "thanos-receive-ingester"
"type": "JAEGER"`,
					},
				},
				Hashrings: []v1alpha1.IngesterHashringSpec{
					{
						Name: "telemeter",
						CommonFields: v1alpha1.CommonFields{
							Image:                ptr.To(clusters.TemplateFn("RECEIVE_INGESTOR_TELEMETER", templates.Images)),
							Version:              ptr.To(clusters.TemplateFn("RECEIVE_INGESTOR_TELEMETER", templates.Versions)),
							ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
							LogLevel:             ptr.To(clusters.TemplateFn("RECEIVE_INGESTOR_TELEMETER", templates.LogLevels)),
							LogFormat:            ptr.To("logfmt"),
							ResourceRequirements: ptr.To(clusters.TemplateFn("RECEIVE_INGESTOR_TELEMETER", templates.ResourceRequirements)),
						},
						ExternalLabels: map[string]string{
							"replica": "$(POD_NAME)",
						},
						Replicas: clusters.TemplateFn("RECEIVE_INGESTOR_TELEMETER", templates.Replicas),
						TSDBConfig: v1alpha1.TSDBConfig{
							Retention: v1alpha1.Duration("4h"),
						},
						AsyncForwardWorkerCount:  ptr.To(uint64(50)),
						TooFarInFutureTimeWindow: ptr.To(v1alpha1.Duration("5m")),
						StoreLimitsOptions: &v1alpha1.StoreLimitsOptions{
							StoreLimitsRequestSamples: 627040000,
							StoreLimitsRequestSeries:  1000000,
						},
						TenancyConfig: &v1alpha1.TenancyConfig{
							TenantMatcherType: "exact",
							DefaultTenantID:   "FB870BF3-9F3A-44FF-9BF7-D7A047A52F43",
							TenantHeader:      "THANOS-TENANT",
							TenantLabelName:   "tenant_id",
						},
						StorageSize: clusters.TemplateFn("RECEIVE_TELEMETER", templates.StorageSize),
					},
					{
						Name: "default",
						CommonFields: v1alpha1.CommonFields{
							Image:                ptr.To(clusters.TemplateFn("RECEIVE_INGESTOR_DEFAULT", templates.Images)),
							Version:              ptr.To(clusters.TemplateFn("RECEIVE_INGESTOR_DEFAULT", templates.Versions)),
							ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
							LogLevel:             ptr.To(clusters.TemplateFn("RECEIVE_INGESTOR_DEFAULT", templates.LogLevels)),
							LogFormat:            ptr.To("logfmt"),
							ResourceRequirements: ptr.To(clusters.TemplateFn("RECEIVE_INGESTOR_DEFAULT", templates.ResourceRequirements)),
						},
						ExternalLabels: map[string]string{
							"replica": "$(POD_NAME)",
						},
						Replicas: clusters.TemplateFn("RECEIVE_INGESTOR_DEFAULT", templates.Replicas),
						TSDBConfig: v1alpha1.TSDBConfig{
							Retention: v1alpha1.Duration("1d"),
						},
						AsyncForwardWorkerCount:  ptr.To(uint64(5)),
						TooFarInFutureTimeWindow: ptr.To(v1alpha1.Duration("5m")),
						StoreLimitsOptions: &v1alpha1.StoreLimitsOptions{
							StoreLimitsRequestSamples: 0,
							StoreLimitsRequestSeries:  0,
						},
						TenancyConfig: &v1alpha1.TenancyConfig{
							TenantMatcherType: "exact",
							DefaultTenantID:   "FB870BF3-9F3A-44FF-9BF7-D7A047A52F43",
							TenantHeader:      "THANOS-TENANT",
							TenantLabelName:   "tenant_id",
						},
						ObjectStorageConfig: ptr.To(clusters.TemplateFn("DEFAULT", templates.ObjectStorageBucket)),
						StorageSize:         clusters.TemplateFn("RECEIVE_DEFAULT", templates.StorageSize),
					},
				},
			},
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}
}

func defaultQueryCR(namespace string, templates clusters.TemplateMaps, oauth bool, withAdditionalArgs ...string) []runtime.Object {
	// placeholder for prod caches - temp removed whilst debugging
	qfeCacheTempProd := v1alpha1.Additional{
		Args: []string{`--query-range.response-cache-config=
  "type": "memcached"
  "config":
    "addresses":
      - "dnssrv+_client._tcp.thanos-query-range-cache.rhobs-production.svc"
    "dns_provider_update_interval": "30s"
    "max_async_buffer_size": 1000000
    "max_async_concurrency": 100
    "max_get_multi_batch_size": 500
    "max_get_multi_concurrency": 100
    "max_idle_connections": 500
    "max_item_size": "100MiB"
    "timeout": "5s"`,
		},
	}
	log.Println(qfeCacheTempProd)

	var objs []runtime.Object

	query := &v1alpha1.ThanosQuery{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosQuery",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "rhobs",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosQuerySpec{
			Additional: v1alpha1.Additional{
				Args: withAdditionalArgs,
			},
			CommonFields: v1alpha1.CommonFields{
				Image:                ptr.To(clusters.TemplateFn(clusters.Query, templates.Images)),
				Version:              ptr.To(clusters.TemplateFn(clusters.Query, templates.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn(clusters.Query, templates.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn(clusters.Query, templates.ResourceRequirements)),
			},
			StoreLabelSelector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"operator.thanos.io/store-api": "true",
					"app.kubernetes.io/part-of":    "thanos",
				},
			},
			Replicas: clusters.TemplateFn(clusters.Query, templates.Replicas),
			ReplicaLabels: []string{
				"prometheus_replica",
				"replica",
				"rule_replica",
			},
			WebConfig: &v1alpha1.WebConfig{
				PrefixHeader: ptr.To("X-Forwarded-Prefix"),
			},
			GRPCProxyStrategy: "lazy",
			TelemetryQuantiles: &v1alpha1.TelemetryQuantiles{
				Duration: []string{
					"0.1", "0.25", "0.75", "1.25", "1.75", "2.5", "3", "5", "10", "15", "30", "60", "120",
				},
			},
			QueryFrontend: &v1alpha1.QueryFrontendSpec{
				CommonFields: v1alpha1.CommonFields{
					Image:                ptr.To(clusters.TemplateFn("QUERY_FRONTEND", templates.Images)),
					Version:              ptr.To(clusters.TemplateFn("QUERY_FRONTEND", templates.Versions)),
					ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
					LogLevel:             ptr.To(clusters.TemplateFn("QUERY_FRONTEND", templates.LogLevels)),
					LogFormat:            ptr.To("logfmt"),
					ResourceRequirements: ptr.To(clusters.TemplateFn("QUERY_FRONTEND", templates.ResourceRequirements)),
				},
				Replicas:             clusters.TemplateFn("QUERY_FRONTEND", templates.Replicas),
				CompressResponses:    true,
				LogQueriesLongerThan: ptr.To(v1alpha1.Duration("10s")),
				LabelsMaxRetries:     3,
				QueryRangeMaxRetries: 3,
				QueryLabelSelector: &metav1.LabelSelector{
					MatchLabels: map[string]string{
						"operator.thanos.io/query-api": "true",
					},
				},
				QueryRangeSplitInterval: ptr.To(v1alpha1.Duration("48h")),
				LabelsSplitInterval:     ptr.To(v1alpha1.Duration("48h")),
				LabelsDefaultTimeRange:  ptr.To(v1alpha1.Duration("336h")),
			},
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
				PodDisruptionBudgetConfig: &v1alpha1.PodDisruptionBudgetConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}
	if oauth {
		route := &routev1.Route{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "route.openshift.io/v1",
				Kind:       "Route",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-query-frontend-rhobs",
				Namespace: namespace,
				Labels: map[string]string{
					"app.kubernetes.io/part-of": "thanos",
				},
			},
			Spec: routev1.RouteSpec{
				To: routev1.RouteTargetReference{
					Kind:   "Service",
					Name:   "thanos-query-frontend-rhobs",
					Weight: ptr.To(int32(100)),
				},
				Port: &routev1.RoutePort{
					TargetPort: intstr.FromString("https"), // Assuming the oauth-proxy is exposing on https port
				},
				TLS: &routev1.TLSConfig{
					Termination:                   routev1.TLSTerminationReencrypt,
					InsecureEdgeTerminationPolicy: routev1.InsecureEdgeTerminationPolicyRedirect,
				},
			},
		}
		objs = append(objs, route)
		query.Annotations = map[string]string{
			"service.beta.openshift.io/serving-cert-secret-name":               "query-frontend-tls",
			"serviceaccounts.openshift.io/oauth-redirectreference.application": `{"kind":"OAuthRedirectReference","apiVersion":"v1","reference":{"kind":"Route","name":"thanos-query-frontend-rhobs"}}`,
		}
		query.Spec.QueryFrontend.Additional.ServicePorts = append(query.Spec.QueryFrontend.Additional.ServicePorts, corev1.ServicePort{
			Name: "https",
			Port: 8443,
			TargetPort: intstr.IntOrString{
				Type:   intstr.Int,
				IntVal: 8443,
			},
		})
		query.Spec.QueryFrontend.Additional.Containers = append(query.Spec.QueryFrontend.Additional.Containers, makeOauthProxy(9090, namespace, "thanos-query-frontend-rhobs", "query-frontend-tls").GetContainer())
		query.Spec.QueryFrontend.Additional.Volumes = append(query.Spec.QueryFrontend.Additional.Volumes, kghelpers.NewPodVolumeFromSecret("tls", "query-frontend-tls"))
	}

	objs = append(objs, query)
	return objs
}

func defaultStoreCR(namespace string, templates clusters.TemplateMaps) runtime.Object {
	return &v1alpha1.ThanosStore{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosStore",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "default",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosStoreSpec{
			CommonFields: v1alpha1.CommonFields{
				Image:                ptr.To(clusters.TemplateFn(clusters.StoreDefault, templates.Images)),
				Version:              ptr.To(clusters.TemplateFn(clusters.StoreDefault, templates.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn(clusters.StoreDefault, templates.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn(clusters.StoreDefault, templates.ResourceRequirements)),
			},
			Replicas:            clusters.TemplateFn(clusters.StoreDefault, templates.Replicas),
			ObjectStorageConfig: clusters.TemplateFn(clusters.DefaultBucket, templates.ObjectStorageBucket),
			ShardingStrategy: v1alpha1.ShardingStrategy{
				Type:   v1alpha1.Block,
				Shards: 1,
			},
			IndexHeaderConfig: &v1alpha1.IndexHeaderConfig{
				EnableLazyReader:      ptr.To(true),
				LazyDownloadStrategy:  ptr.To("lazy"),
				LazyReaderIdleTimeout: ptr.To(v1alpha1.Duration("5m")),
			},
			StoreLimitsOptions: &v1alpha1.StoreLimitsOptions{
				StoreLimitsRequestSamples: 0,
				StoreLimitsRequestSeries:  0,
			},
			BlockConfig: &v1alpha1.BlockConfig{
				BlockDiscoveryStrategy:    v1alpha1.BlockDiscoveryStrategy("concurrent"),
				BlockFilesConcurrency:     ptr.To(int32(1)),
				BlockMetaFetchConcurrency: ptr.To(int32(32)),
			},
			IgnoreDeletionMarksDelay: v1alpha1.Duration("24h"),
			TimeRangeConfig: &v1alpha1.TimeRangeConfig{
				MaxTime: ptr.To(v1alpha1.Duration("-22h")),
			},
			StorageSize: clusters.TemplateFn(clusters.StoreDefault, templates.StorageSize),
			Additional: v1alpha1.Additional{
				Containers: []corev1.Container{
					tracingSidecar(templates),
				},
				Args: []string{
					`--tracing.config="config":
  "sampler_param": 2
  "sampler_type": "ratelimiting"
  "service_name": "thanos-store"
"type": "JAEGER"`,
				},
			},
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}
}

func defaultReceiveCR(namespace string, templates clusters.TemplateMaps) runtime.Object {
	return &v1alpha1.ThanosReceive{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosReceive",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "rhobs",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosReceiveSpec{
			Router: v1alpha1.RouterSpec{
				CommonFields: v1alpha1.CommonFields{
					Image:                ptr.To(clusters.TemplateFn(clusters.ReceiveRouter, templates.Images)),
					Version:              ptr.To(clusters.TemplateFn(clusters.ReceiveRouter, templates.Versions)),
					ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
					LogLevel:             ptr.To(clusters.TemplateFn(clusters.ReceiveRouter, templates.LogLevels)),
					LogFormat:            ptr.To("logfmt"),
					ResourceRequirements: ptr.To(clusters.TemplateFn(clusters.ReceiveRouter, templates.ResourceRequirements)),
				},
				Replicas:          clusters.TemplateFn(clusters.ReceiveRouter, templates.Replicas),
				ReplicationFactor: 3,
				ExternalLabels: map[string]string{
					"receive": "true",
				},
				Additional: v1alpha1.Additional{
					Containers: []corev1.Container{
						tracingSidecar(templates),
					},
					Args: []string{
						`--tracing.config="config":
  "sampler_param": 2
  "sampler_type": "ratelimiting"
  "service_name": "thanos-receive-router"
"type": "JAEGER"`,
					},
				},
			},
			Ingester: v1alpha1.IngesterSpec{
				DefaultObjectStorageConfig: clusters.TemplateFn(clusters.DefaultBucket, templates.ObjectStorageBucket),
				Additional: v1alpha1.Additional{
					Containers: []corev1.Container{
						tracingSidecar(templates),
					},
					Args: []string{
						`--tracing.config="config":
  "sampler_param": 2
  "sampler_type": "ratelimiting"
  "service_name": "thanos-receive-ingester"
"type": "JAEGER"`,
					},
				},
				Hashrings: []v1alpha1.IngesterHashringSpec{
					{
						Name: "default",
						CommonFields: v1alpha1.CommonFields{
							Image:                ptr.To(clusters.TemplateFn(clusters.ReceiveIngestorDefault, templates.Images)),
							Version:              ptr.To(clusters.TemplateFn(clusters.ReceiveIngestorDefault, templates.Versions)),
							ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
							LogLevel:             ptr.To(clusters.TemplateFn(clusters.ReceiveIngestorDefault, templates.LogLevels)),
							LogFormat:            ptr.To("logfmt"),
							ResourceRequirements: ptr.To(clusters.TemplateFn(clusters.ReceiveIngestorDefault, templates.ResourceRequirements)),
						},
						ExternalLabels: map[string]string{
							"replica": "$(POD_NAME)",
						},
						Replicas: clusters.TemplateFn(clusters.ReceiveIngestorDefault, templates.Replicas),
						TSDBConfig: v1alpha1.TSDBConfig{
							Retention: v1alpha1.Duration("1d"),
						},
						AsyncForwardWorkerCount:  ptr.To(uint64(5)),
						TooFarInFutureTimeWindow: ptr.To(v1alpha1.Duration("5m")),
						StoreLimitsOptions: &v1alpha1.StoreLimitsOptions{
							StoreLimitsRequestSamples: 0,
							StoreLimitsRequestSeries:  0,
						},
						TenancyConfig: &v1alpha1.TenancyConfig{
							TenantMatcherType: "exact",
							DefaultTenantID:   "FB870BF3-9F3A-44FF-9BF7-D7A047A52F43",
							TenantHeader:      "THANOS-TENANT",
							TenantLabelName:   "tenant_id",
						},
						ObjectStorageConfig: ptr.To(clusters.TemplateFn(clusters.DefaultBucket, templates.ObjectStorageBucket)),
						StorageSize:         clusters.TemplateFn(clusters.ReceiveIngestorDefault, templates.StorageSize),
					},
				},
			},
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}
}

func defaultCompactCR(namespace string, templates clusters.TemplateMaps) runtime.Object {
	defaultCompact := &v1alpha1.ThanosCompact{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosCompact",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "rhobs",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosCompactSpec{
			CommonFields: v1alpha1.CommonFields{
				Image:                ptr.To(clusters.TemplateFn(clusters.CompactDefault, templates.Images)),
				Version:              ptr.To(clusters.TemplateFn(clusters.CompactDefault, templates.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn(clusters.CompactDefault, templates.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn(clusters.CompactDefault, templates.ResourceRequirements)),
			},
			ObjectStorageConfig: clusters.TemplateFn(clusters.DefaultBucket, templates.ObjectStorageBucket),
			RetentionConfig: v1alpha1.RetentionResolutionConfig{
				Raw:         v1alpha1.Duration("365d"),
				FiveMinutes: v1alpha1.Duration("365d"),
				OneHour:     v1alpha1.Duration("365d"),
			},
			DownsamplingConfig: &v1alpha1.DownsamplingConfig{
				Concurrency: ptr.To(int32(1)),
				Disable:     ptr.To(false),
			},
			CompactConfig: &v1alpha1.CompactConfig{
				CompactConcurrency: ptr.To(int32(1)),
			},
			DebugConfig: &v1alpha1.DebugConfig{
				AcceptMalformedIndex: ptr.To(true),
				HaltOnError:          ptr.To(true),
				MaxCompactionLevel:   ptr.To(int32(3)),
			},
			StorageSize: clusters.TemplateFn(clusters.CompactDefault, templates.StorageSize),
			Additional: v1alpha1.Additional{
				Containers: []corev1.Container{
					tracingSidecar(templates),
				},
				Args: []string{
					`--tracing.config="config":
  "sampler_param": 2
  "sampler_type": "ratelimiting"
  "service_name": "thanos-compact"
"type": "JAEGER"`,
				},
			},
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}

	defaultCompact.Spec.Additional.Containers = append(defaultCompact.Spec.Additional.Containers, makeOauthProxy(10902, namespace, "thanos-compact-rhobs", "compact-tls").GetContainer())
	defaultCompact.Spec.Additional.Volumes = append(defaultCompact.Spec.Additional.Volumes, kghelpers.NewPodVolumeFromSecret("tls", "compact-tls"))

	return defaultCompact
}

func defaultRulerCR(namespace string, templates clusters.TemplateMaps) runtime.Object {
	return &v1alpha1.ThanosRuler{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosRuler",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "rhobs",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosRulerSpec{
			CommonFields: v1alpha1.CommonFields{
				Image:                ptr.To(clusters.TemplateFn(clusters.Ruler, templates.Images)),
				Version:              ptr.To(clusters.TemplateFn(clusters.Ruler, templates.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn(clusters.Ruler, templates.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn(clusters.Ruler, templates.ResourceRequirements)),
			},
			Paused:   ptr.To(true),
			Replicas: clusters.TemplateFn(clusters.Ruler, templates.Replicas),
			RuleConfigSelector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"operator.thanos.io/rule-file": "true",
				},
			},
			PrometheusRuleSelector: metav1.LabelSelector{
				MatchLabels: map[string]string{
					"operator.thanos.io/prometheus-rule": "true",
				},
			},
			QueryLabelSelector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"operator.thanos.io/query-api": "true",
					"app.kubernetes.io/part-of":    "thanos",
				},
			},
			ExternalLabels: map[string]string{
				"rule_replica": "$(NAME)",
			},
			ObjectStorageConfig: clusters.TemplateFn(clusters.DefaultBucket, templates.ObjectStorageBucket),
			AlertmanagerURL:     "dnssrv+http://alertmanager-cluster." + namespace + ".svc.cluster.local:9093",
			AlertLabelDrop:      []string{"rule_replica"},
			Retention:           v1alpha1.Duration("48h"),
			EvaluationInterval:  v1alpha1.Duration("1m"),
			StorageSize:         string(clusters.TemplateFn(clusters.Ruler, templates.StorageSize)),
			Additional: v1alpha1.Additional{
				Containers: []corev1.Container{
					tracingSidecar(templates),
				},
				Args: []string{
					`--tracing.config="config":
  "sampler_param": 2
  "sampler_type": "ratelimiting"
  "service_name": "thanos-ruler"
"type": "JAEGER"`,
				},
			},
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}
}

func queryCR(namespace string, templates clusters.TemplateMaps, oauth bool, withAdditonalArgs ...string) []runtime.Object {
	// placeholder for prod caches - temp removed whilst debugging
	qfeCacheTempProd := v1alpha1.Additional{
		Args: []string{`--query-range.response-cache-config=
  "type": "memcached"
  "config":
    "addresses":
      - "dnssrv+_client._tcp.thanos-query-range-cache.rhobs-production.svc"
    "dns_provider_update_interval": "30s"
    "max_async_buffer_size": 1000000
    "max_async_concurrency": 100
    "max_get_multi_batch_size": 500
    "max_get_multi_concurrency": 100
    "max_idle_connections": 500
    "max_item_size": "100MiB"
    "timeout": "5s"`,
		},
	}
	log.Println(qfeCacheTempProd)

	var objs []runtime.Object

	query := &v1alpha1.ThanosQuery{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosQuery",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "rhobs",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosQuerySpec{
			Additional: v1alpha1.Additional{
				Args: withAdditonalArgs,
			},
			CommonFields: v1alpha1.CommonFields{
				Image:                ptr.To(clusters.TemplateFn("QUERY", templates.Images)),
				Version:              ptr.To(clusters.TemplateFn("QUERY", templates.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn("QUERY", templates.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn("QUERY", templates.ResourceRequirements)),
			},
			StoreLabelSelector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"operator.thanos.io/store-api": "true",
					"app.kubernetes.io/part-of":    "thanos",
				},
			},
			Replicas: clusters.TemplateFn("QUERY", templates.Replicas),
			ReplicaLabels: []string{
				"prometheus_replica",
				"replica",
				"rule_replica",
			},
			WebConfig: &v1alpha1.WebConfig{
				PrefixHeader: ptr.To("X-Forwarded-Prefix"),
			},
			GRPCProxyStrategy: "lazy",
			TelemetryQuantiles: &v1alpha1.TelemetryQuantiles{
				Duration: []string{
					"0.1", "0.25", "0.75", "1.25", "1.75", "2.5", "3", "5", "10", "15", "30", "60", "120",
				},
			},
			QueryFrontend: &v1alpha1.QueryFrontendSpec{
				CommonFields: v1alpha1.CommonFields{
					Image:                ptr.To(clusters.TemplateFn("QUERY_FRONTEND", templates.Images)),
					Version:              ptr.To(clusters.TemplateFn("QUERY_FRONTEND", templates.Versions)),
					ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
					LogLevel:             ptr.To(clusters.TemplateFn("QUERY_FRONTEND", templates.LogLevels)),
					LogFormat:            ptr.To("logfmt"),
					ResourceRequirements: ptr.To(clusters.TemplateFn("QUERY_FRONTEND", templates.ResourceRequirements)),
				},
				Replicas:             clusters.TemplateFn("QUERY_FRONTEND", templates.Replicas),
				CompressResponses:    true,
				LogQueriesLongerThan: ptr.To(v1alpha1.Duration("10s")),
				LabelsMaxRetries:     3,
				QueryRangeMaxRetries: 3,
				QueryLabelSelector: &metav1.LabelSelector{
					MatchLabels: map[string]string{
						"operator.thanos.io/query-api": "true",
					},
				},
				QueryRangeSplitInterval: ptr.To(v1alpha1.Duration("48h")),
				LabelsSplitInterval:     ptr.To(v1alpha1.Duration("48h")),
				LabelsDefaultTimeRange:  ptr.To(v1alpha1.Duration("336h")),
			},
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
				PodDisruptionBudgetConfig: &v1alpha1.PodDisruptionBudgetConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}
	if oauth {
		route := &routev1.Route{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "route.openshift.io/v1",
				Kind:       "Route",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-query-frontend-rhobs",
				Namespace: namespace,
				Labels: map[string]string{
					"app.kubernetes.io/part-of": "thanos",
				},
			},
			Spec: routev1.RouteSpec{
				To: routev1.RouteTargetReference{
					Kind:   "Service",
					Name:   "thanos-query-frontend-rhobs",
					Weight: ptr.To(int32(100)),
				},
				Port: &routev1.RoutePort{
					TargetPort: intstr.FromString("https"), // Assuming the oauth-proxy is exposing on https port
				},
				TLS: &routev1.TLSConfig{
					Termination:                   routev1.TLSTerminationReencrypt,
					InsecureEdgeTerminationPolicy: routev1.InsecureEdgeTerminationPolicyRedirect,
				},
			},
		}
		objs = append(objs, route)
		query.Annotations = map[string]string{
			"service.beta.openshift.io/serving-cert-secret-name":               "query-frontend-tls",
			"serviceaccounts.openshift.io/oauth-redirectreference.application": `{"kind":"OAuthRedirectReference","apiVersion":"v1","reference":{"kind":"Route","name":"thanos-query-frontend-rhobs"}}`,
		}
		query.Spec.QueryFrontend.Additional.ServicePorts = append(query.Spec.QueryFrontend.Additional.ServicePorts, corev1.ServicePort{
			Name: "https",
			Port: 8443,
			TargetPort: intstr.IntOrString{
				Type:   intstr.Int,
				IntVal: 8443,
			},
		})
		query.Spec.QueryFrontend.Additional.Containers = append(query.Spec.QueryFrontend.Additional.Containers, makeOauthProxy(9090, namespace, "thanos-query-frontend-rhobs", "query-frontend-tls").GetContainer())
		query.Spec.QueryFrontend.Additional.Volumes = append(query.Spec.QueryFrontend.Additional.Volumes, kghelpers.NewPodVolumeFromSecret("tls", "query-frontend-tls"))
	}

	objs = append(objs, query)
	return objs
}

func rulerCR(namespace string, templates clusters.TemplateMaps) runtime.Object {
	return &v1alpha1.ThanosRuler{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosRuler",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "rhobs",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosRulerSpec{
			CommonFields: v1alpha1.CommonFields{
				Image:                ptr.To(clusters.TemplateFn("RULER", templates.Images)),
				Version:              ptr.To(clusters.TemplateFn("RULER", templates.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn("RULER", templates.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn("RULER", templates.ResourceRequirements)),
			},
			Paused:   ptr.To(true),
			Replicas: clusters.TemplateFn("RULER", templates.Replicas),
			RuleConfigSelector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"operator.thanos.io/rule-file": "true",
				},
			},
			PrometheusRuleSelector: metav1.LabelSelector{
				MatchLabels: map[string]string{
					"operator.thanos.io/prometheus-rule": "true",
				},
			},
			QueryLabelSelector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"operator.thanos.io/query-api": "true",
					"app.kubernetes.io/part-of":    "thanos",
				},
			},
			ExternalLabels: map[string]string{
				"rule_replica": "$(NAME)",
			},
			ObjectStorageConfig: clusters.TemplateFn("DEFAULT", templates.ObjectStorageBucket),
			AlertmanagerURL:     "dnssrv+http://alertmanager-cluster." + namespace + ".svc.cluster.local:9093",
			AlertLabelDrop:      []string{"rule_replica"},
			Retention:           v1alpha1.Duration("48h"),
			EvaluationInterval:  v1alpha1.Duration("1m"),
			StorageSize:         string(clusters.TemplateFn("RULER", templates.StorageSize)),
			Additional: v1alpha1.Additional{
				Containers: []corev1.Container{
					tracingSidecar(templates),
				},
				Args: []string{
					`--tracing.config="config":
  "sampler_param": 2
  "sampler_type": "ratelimiting"
  "service_name": "thanos-ruler"
"type": "JAEGER"`,
				},
			},
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}
}

func compactTempProduction(templates clusters.TemplateMaps) []runtime.Object {
	ns := "rhobs-production"
	image := string(clusters.TemplateFn("COMPACT", templates.Images))
	version := string(clusters.TemplateFn("RULER", templates.Versions))
	storageBucket := "TELEMETER"

	m := clusters.ProductionMaps

	notTelemeter := &v1alpha1.ThanosCompact{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosCompact",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "rules-and-rhobs",
			Namespace: ns,
		},
		Spec: v1alpha1.ThanosCompactSpec{
			Additional: v1alpha1.Additional{
				Args: []string{
					`--deduplication.replica-label=replica`,
				},
			},
			ShardingConfig: []v1alpha1.ShardingConfig{
				{
					ShardName: "rhobs",
					ExternalLabelSharding: []v1alpha1.ExternalLabelShardingConfig{
						{
							Label: "receive",
							Value: "true",
						},
						{
							Label: "tenant_id",
							Value: "0fc2b00e-201b-4c17-b9f2-19d91adc4fd2",
						},
					},
				},
				{
					ShardName: "rules",
					ExternalLabelSharding: []v1alpha1.ExternalLabelShardingConfig{
						{
							Label: "receive",
							Value: "!true",
						},
					},
				},
			},
			CommonFields: v1alpha1.CommonFields{
				Image:           ptr.To(image),
				Version:         ptr.To(version),
				ImagePullPolicy: ptr.To(corev1.PullIfNotPresent),
				LogLevel:        ptr.To("warn"),
				LogFormat:       ptr.To("logfmt"),
			},
			ObjectStorageConfig: clusters.TemplateFn(storageBucket, m.ObjectStorageBucket),
			RetentionConfig: v1alpha1.RetentionResolutionConfig{
				Raw:         v1alpha1.Duration("3650d"),
				FiveMinutes: v1alpha1.Duration("3650d"),
				OneHour:     v1alpha1.Duration("3650d"),
			},
			DownsamplingConfig: &v1alpha1.DownsamplingConfig{
				Concurrency: ptr.To(int32(4)),
				Disable:     ptr.To(false),
			},
			CompactConfig: &v1alpha1.CompactConfig{
				BlockFetchConcurrency: ptr.To(int32(8)),
				CompactConcurrency:    ptr.To(int32(8)),
			},
			DebugConfig: &v1alpha1.DebugConfig{
				AcceptMalformedIndex: ptr.To(true),
				HaltOnError:          ptr.To(false),
				MaxCompactionLevel:   ptr.To(int32(4)),
			},
			StorageSize: v1alpha1.StorageSize("500Gi"),
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}

	telemeterHistoric := &v1alpha1.ThanosCompact{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosCompact",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "receive-historic",
			Namespace: ns,
		},
		Spec: v1alpha1.ThanosCompactSpec{
			Additional: v1alpha1.Additional{
				Args: []string{
					`--deduplication.replica-label=replica`,
				},
			},
			ShardingConfig: []v1alpha1.ShardingConfig{
				{
					ShardName: "telemeter",
					ExternalLabelSharding: []v1alpha1.ExternalLabelShardingConfig{
						{
							Label: "receive",
							Value: "true",
						},
						{
							Label: "tenant_id",
							Value: "FB870BF3-9F3A-44FF-9BF7-D7A047A52F43",
						},
					},
				},
			},
			CommonFields: v1alpha1.CommonFields{
				Image:           ptr.To(image),
				Version:         ptr.To(version),
				ImagePullPolicy: ptr.To(corev1.PullIfNotPresent),
				LogLevel:        ptr.To("info"),
				LogFormat:       ptr.To("logfmt"),
			},
			ObjectStorageConfig: clusters.TemplateFn(storageBucket, m.ObjectStorageBucket),
			RetentionConfig: v1alpha1.RetentionResolutionConfig{
				Raw:         v1alpha1.Duration("3650d"),
				FiveMinutes: v1alpha1.Duration("3650d"),
				OneHour:     v1alpha1.Duration("3650d"),
			},
			DownsamplingConfig: &v1alpha1.DownsamplingConfig{
				Concurrency: ptr.To(int32(4)),
				Disable:     ptr.To(false),
			},
			CompactConfig: &v1alpha1.CompactConfig{
				BlockFetchConcurrency: ptr.To(int32(4)),
				CompactConcurrency:    ptr.To(int32(4)),
			},
			DebugConfig: &v1alpha1.DebugConfig{
				AcceptMalformedIndex: ptr.To(true),
				HaltOnError:          ptr.To(true),
				MaxCompactionLevel:   ptr.To(int32(4)),
			},
			StorageSize: v1alpha1.StorageSize("3000Gi"),
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
			TimeRangeConfig: &v1alpha1.TimeRangeConfig{
				MaxTime: ptr.To(v1alpha1.Duration("-120d")),
			},
		},
	}

	telemeter := &v1alpha1.ThanosCompact{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosCompact",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "receive",
			Namespace: ns,
		},
		Spec: v1alpha1.ThanosCompactSpec{
			Additional: v1alpha1.Additional{
				Args: []string{
					`--deduplication.replica-label=replica`,
				},
			},
			ShardingConfig: []v1alpha1.ShardingConfig{
				{
					ShardName: "telemeter",
					ExternalLabelSharding: []v1alpha1.ExternalLabelShardingConfig{
						{
							Label: "receive",
							Value: "true",
						},
						{
							Label: "tenant_id",
							Value: "FB870BF3-9F3A-44FF-9BF7-D7A047A52F43",
						},
					},
				},
			},
			CommonFields: v1alpha1.CommonFields{
				Image:           ptr.To(image),
				Version:         ptr.To(version),
				ImagePullPolicy: ptr.To(corev1.PullIfNotPresent),
				LogLevel:        ptr.To("info"),
				LogFormat:       ptr.To("logfmt"),
			},
			ObjectStorageConfig: clusters.TemplateFn(storageBucket, m.ObjectStorageBucket),
			RetentionConfig: v1alpha1.RetentionResolutionConfig{
				Raw:         v1alpha1.Duration("3650d"),
				FiveMinutes: v1alpha1.Duration("3650d"),
				OneHour:     v1alpha1.Duration("3650d"),
			},
			DownsamplingConfig: &v1alpha1.DownsamplingConfig{
				Concurrency: ptr.To(int32(4)),
				Disable:     ptr.To(false),
			},
			CompactConfig: &v1alpha1.CompactConfig{
				BlockFetchConcurrency: ptr.To(int32(4)),
				CompactConcurrency:    ptr.To(int32(4)),
			},
			DebugConfig: &v1alpha1.DebugConfig{
				AcceptMalformedIndex: ptr.To(true),
				HaltOnError:          ptr.To(true),
				MaxCompactionLevel:   ptr.To(int32(4)),
			},
			StorageSize: v1alpha1.StorageSize("3000Gi"),
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
			TimeRangeConfig: &v1alpha1.TimeRangeConfig{
				MinTime: ptr.To(v1alpha1.Duration("-61d")),
			},
		},
	}
	return []runtime.Object{notTelemeter, telemeterHistoric, telemeter}
}

// RHOBS-904: Standalone Compact for RH Resource Optimisation (ROS) Managed Service
func stageCompactCR(namespace string, templates clusters.TemplateMaps) []runtime.Object {
	rosCompact := &v1alpha1.ThanosCompact{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosCompact",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "ros",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosCompactSpec{
			CommonFields: v1alpha1.CommonFields{
				Image:                ptr.To(clusters.TemplateFn("COMPACT_ROS", templates.Images)),
				Version:              ptr.To(clusters.TemplateFn("COMPACT_ROS", templates.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn("COMPACT_ROS", templates.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn("COMPACT_ROS", templates.ResourceRequirements)),
			},
			ObjectStorageConfig: clusters.TemplateFn("ROS", templates.ObjectStorageBucket),
			RetentionConfig: v1alpha1.RetentionResolutionConfig{
				Raw:         v1alpha1.Duration("14d"),
				FiveMinutes: v1alpha1.Duration("14d"),
				OneHour:     v1alpha1.Duration("14d"),
			},
			DownsamplingConfig: &v1alpha1.DownsamplingConfig{
				Concurrency: ptr.To(int32(1)),
				Disable:     ptr.To(false),
			},
			CompactConfig: &v1alpha1.CompactConfig{
				CompactConcurrency: ptr.To(int32(1)),
			},
			DebugConfig: &v1alpha1.DebugConfig{
				AcceptMalformedIndex: ptr.To(true),
				HaltOnError:          ptr.To(true),
				MaxCompactionLevel:   ptr.To(int32(3)),
			},
			StorageSize: clusters.TemplateFn("COMPACT_ROS", templates.StorageSize),
			Additional: v1alpha1.Additional{
				Containers: []corev1.Container{
					tracingSidecar(templates),
				},
				Args: []string{
					`--tracing.config="config":
  "sampler_param": 2
  "sampler_type": "ratelimiting"
  "service_name": "thanos-compact"
"type": "JAEGER"`,
				},
			},
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}

	return []runtime.Object{rosCompact}
}

func compactCR(namespace string, templates clusters.TemplateMaps, oauth bool) []runtime.Object {
	defaultCompact := &v1alpha1.ThanosCompact{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosCompact",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "rhobs",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosCompactSpec{
			CommonFields: v1alpha1.CommonFields{
				Image:                ptr.To(clusters.TemplateFn("COMPACT_DEFAULT", templates.Images)),
				Version:              ptr.To(clusters.TemplateFn("COMPACT_DEFAULT", templates.Versions)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn("COMPACT_DEFAULT", templates.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn("COMPACT_DEFAULT", templates.ResourceRequirements)),
			},
			ObjectStorageConfig: clusters.TemplateFn("DEFAULT", templates.ObjectStorageBucket),
			RetentionConfig: v1alpha1.RetentionResolutionConfig{
				Raw:         v1alpha1.Duration("365d"),
				FiveMinutes: v1alpha1.Duration("365d"),
				OneHour:     v1alpha1.Duration("365d"),
			},
			DownsamplingConfig: &v1alpha1.DownsamplingConfig{
				Concurrency: ptr.To(int32(1)),
				Disable:     ptr.To(false),
			},
			CompactConfig: &v1alpha1.CompactConfig{
				CompactConcurrency: ptr.To(int32(1)),
			},
			DebugConfig: &v1alpha1.DebugConfig{
				AcceptMalformedIndex: ptr.To(true),
				HaltOnError:          ptr.To(true),
				MaxCompactionLevel:   ptr.To(int32(3)),
			},
			StorageSize: clusters.TemplateFn("COMPACT_DEFAULT", templates.StorageSize),
			Additional: v1alpha1.Additional{
				Containers: []corev1.Container{
					tracingSidecar(templates),
				},
				Args: []string{
					`--tracing.config="config":
  "sampler_param": 2
  "sampler_type": "ratelimiting"
  "service_name": "thanos-compact"
"type": "JAEGER"`,
				},
			},
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}

	if oauth {
		defaultCompact.Spec.Additional.Containers = append(defaultCompact.Spec.Additional.Containers, makeOauthProxy(10902, namespace, "thanos-compact-rhobs", "compact-tls").GetContainer())
		defaultCompact.Spec.Additional.Volumes = append(defaultCompact.Spec.Additional.Volumes, kghelpers.NewPodVolumeFromSecret("tls", "compact-tls"))
	}

	telemeterCompact := &v1alpha1.ThanosCompact{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosCompact",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "telemeter",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosCompactSpec{
			CommonFields: v1alpha1.CommonFields{
				Version:              ptr.To(clusters.TemplateFn("COMPACT_TELEMETER", templates.Versions)),
				Image:                ptr.To(clusters.TemplateFn("COMPACT_TELEMETER", templates.Images)),
				ImagePullPolicy:      ptr.To(corev1.PullIfNotPresent),
				LogLevel:             ptr.To(clusters.TemplateFn("COMPACT_TELEMETER", templates.LogLevels)),
				LogFormat:            ptr.To("logfmt"),
				ResourceRequirements: ptr.To(clusters.TemplateFn("COMPACT_TELEMETER", templates.ResourceRequirements)),
			},
			ObjectStorageConfig: clusters.TemplateFn("TELEMETER", templates.ObjectStorageBucket),
			RetentionConfig: v1alpha1.RetentionResolutionConfig{
				Raw:         v1alpha1.Duration("365d"),
				FiveMinutes: v1alpha1.Duration("365d"),
				OneHour:     v1alpha1.Duration("365d"),
			},
			DownsamplingConfig: &v1alpha1.DownsamplingConfig{
				Concurrency: ptr.To(int32(1)),
				Disable:     ptr.To(false),
			},
			CompactConfig: &v1alpha1.CompactConfig{
				CompactConcurrency: ptr.To(int32(1)),
			},
			DebugConfig: &v1alpha1.DebugConfig{
				AcceptMalformedIndex: ptr.To(true),
				HaltOnError:          ptr.To(true),
				MaxCompactionLevel:   ptr.To(int32(3)),
			},
			StorageSize: clusters.TemplateFn("COMPACT_TELEMETER", templates.StorageSize),
			Additional: v1alpha1.Additional{
				Containers: []corev1.Container{
					tracingSidecar(templates),
				},
				Args: []string{
					`--tracing.config="config":
  "sampler_param": 2
  "sampler_type": "ratelimiting"
  "service_name": "thanos-compact"
"type": "JAEGER"`,
				},
			},
			FeatureGates: &v1alpha1.FeatureGates{
				ServiceMonitorConfig: &v1alpha1.ServiceMonitorConfig{
					Enable: ptr.To(false),
				},
			},
		},
	}

	if oauth {
		telemeterCompact.Spec.Additional.Containers = append(telemeterCompact.Spec.Additional.Containers, makeOauthProxy(10902, namespace, "thanos-compact-telemeter", "compact-tls").GetContainer())
		telemeterCompact.Spec.Additional.Volumes = append(telemeterCompact.Spec.Additional.Volumes, kghelpers.NewPodVolumeFromSecret("tls", "compact-tls"))
	}

	return []runtime.Object{defaultCompact, telemeterCompact}
}
