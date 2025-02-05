package main

import (
	"github.com/magefile/mage/mg"
	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic/encoding"
	"github.com/thanos-community/thanos-operator/api/v1alpha1"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/utils/ptr"
)

// Operator Generates the CRs for Thanos Operator.
func (s Stage) OperatorCR() {
	mg.SerialDeps(s.CRDS)
	templateDir := "thanos-operator"

	gen := s.generator(templateDir)

	gen.Add("receive.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			[]runtime.Object{receiveCR(s.namespace())},
			metav1.ObjectMeta{Name: "thanos-receive"},
			[]templatev1.Parameter{},
		),
	))
	gen.Add("query.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			[]runtime.Object{queryCR(s.namespace())},
			metav1.ObjectMeta{Name: "thanos-query"},
			[]templatev1.Parameter{},
		),
	))
	gen.Add("ruler.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			[]runtime.Object{rulerCR(s.namespace())},
			metav1.ObjectMeta{Name: "thanos-ruler"},
			[]templatev1.Parameter{},
		),
	))
	gen.Add("compact.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			compactCR(s.namespace()),
			metav1.ObjectMeta{Name: "thanos-compact"},
			[]templatev1.Parameter{},
		),
	))
	gen.Add("store.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			storeCR(s.namespace()),
			metav1.ObjectMeta{Name: "thanos-store"},
			[]templatev1.Parameter{},
		),
	))

	gen.Generate()
}

func storeCR(namespace string) []runtime.Object {
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
				Image:           ptr.To(stageTemplateFn("STORE02W", StageImages)),
				ImagePullPolicy: ptr.To(corev1.PullIfNotPresent),
				LogLevel:        ptr.To("info"),
				LogFormat:       ptr.To("logfmt"),
			},
			ObjectStorageConfig: stageTemplateFn("TELEMETER", StageObjectStorageBucket),
			ShardingStrategy: v1alpha1.ShardingStrategy{
				Type:          v1alpha1.Block,
				Shards:        1,
				ShardReplicas: 3,
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
			MaxTime:                  ptr.To(v1alpha1.Duration("-2w")),
			StorageSize:              stageTemplateFn("STORE02W", StageStorageSize),
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
				Image:           ptr.To(stageTemplateFn("STORE2W90D", StageImages)),
				ImagePullPolicy: ptr.To(corev1.PullIfNotPresent),
				LogLevel:        ptr.To("info"),
				LogFormat:       ptr.To("logfmt"),
			},
			ObjectStorageConfig: stageTemplateFn("TELEMETER", StageObjectStorageBucket),
			ShardingStrategy: v1alpha1.ShardingStrategy{
				Type:          v1alpha1.Block,
				Shards:        1,
				ShardReplicas: 3,
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
			MinTime:                  ptr.To(v1alpha1.Duration("-2w")),
			MaxTime:                  ptr.To(v1alpha1.Duration("-90d")),
			StorageSize:              stageTemplateFn("STORE2W90D", StageStorageSize),
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
				Image:           ptr.To(stageTemplateFn("STORE90D+", StageImages)),
				ImagePullPolicy: ptr.To(corev1.PullIfNotPresent),
				LogLevel:        ptr.To("info"),
				LogFormat:       ptr.To("logfmt"),
			},
			ObjectStorageConfig: stageTemplateFn("TELEMETER", StageObjectStorageBucket),
			ShardingStrategy: v1alpha1.ShardingStrategy{
				Type:          v1alpha1.Block,
				Shards:        1,
				ShardReplicas: 3,
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
			MinTime:                  ptr.To(v1alpha1.Duration("-90d")),
			StorageSize:              stageTemplateFn("STORE90D+", StageStorageSize),
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
				Image:           ptr.To(stageTemplateFn("STORE_DEFAULT", StageImages)),
				ImagePullPolicy: ptr.To(corev1.PullIfNotPresent),
				LogLevel:        ptr.To("info"),
				LogFormat:       ptr.To("logfmt"),
			},
			ObjectStorageConfig: stageTemplateFn("DEFAULT", StageObjectStorageBucket),
			ShardingStrategy: v1alpha1.ShardingStrategy{
				Type:          v1alpha1.Block,
				Shards:        1,
				ShardReplicas: 3,
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
			MaxTime:                  ptr.To(v1alpha1.Duration("-22h")),
			StorageSize:              stageTemplateFn("STORE_DEFAULT", StageStorageSize),
		},
	}

	return []runtime.Object{store0to2w, store2wto90d, store90dplus, storeDefault}
}

func receiveCR(namespace string) runtime.Object {
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
					Image:           ptr.To(stageTemplateFn("RECEIVE_ROUTER", StageImages)),
					ImagePullPolicy: ptr.To(corev1.PullIfNotPresent),
					LogLevel:        ptr.To("info"),
					LogFormat:       ptr.To("logfmt"),
				},
				Replicas:          3,
				ReplicationFactor: 3,
				ExternalLabels: map[string]string{
					"receive": "true",
				},
			},
			Ingester: v1alpha1.IngesterSpec{
				DefaultObjectStorageConfig: stageTemplateFn("TELEMETER", StageObjectStorageBucket),
				Hashrings: []v1alpha1.IngesterHashringSpec{
					{
						Name: "telemeter",
						CommonFields: v1alpha1.CommonFields{
							Image:           ptr.To(stageTemplateFn("RECEIVE_INGESTOR_TELEMETER", StageImages)),
							ImagePullPolicy: ptr.To(corev1.PullIfNotPresent),
							LogLevel:        ptr.To("info"),
							LogFormat:       ptr.To("logfmt"),
						},
						ExternalLabels: map[string]string{
							"replica": "$(POD_NAME)",
						},
						Replicas: 6,
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
						StorageSize: stageTemplateFn("RECEIVE_TELEMETER", StageStorageSize),
					},
					{
						Name: "default",
						CommonFields: v1alpha1.CommonFields{
							Image:           ptr.To(stageTemplateFn("RECEIVE_INGESTOR_DEFAULT", StageImages)),
							ImagePullPolicy: ptr.To(corev1.PullIfNotPresent),
							LogLevel:        ptr.To("info"),
							LogFormat:       ptr.To("logfmt"),
						},
						ExternalLabels: map[string]string{
							"replica": "$(POD_NAME)",
						},
						Replicas: 3,
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
						ObjectStorageConfig: ptr.To(stageTemplateFn("DEFAULT", StageObjectStorageBucket)),
						StorageSize:         stageTemplateFn("RECEIVE_DEFAULT", StageStorageSize),
					},
				},
			},
		},
	}
}

func queryCR(namespace string) runtime.Object {
	return &v1alpha1.ThanosQuery{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.thanos.io/v1alpha1",
			Kind:       "ThanosQuery",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "rhobs",
			Namespace: namespace,
		},
		Spec: v1alpha1.ThanosQuerySpec{
			CommonFields: v1alpha1.CommonFields{
				Image:           ptr.To(stageTemplateFn("QUERY", StageImages)),
				ImagePullPolicy: ptr.To(corev1.PullIfNotPresent),
				LogLevel:        ptr.To("info"),
				LogFormat:       ptr.To("logfmt"),
			},
			StoreLabelSelector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"operator.thanos.io/store-api": "true",
					"app.kubernetes.io/part-of":    "thanos",
				},
			},
			Replicas: 6,
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
					Image:           ptr.To(stageTemplateFn("QUERY_FRONTEND", StageImages)),
					ImagePullPolicy: ptr.To(corev1.PullIfNotPresent),
					LogLevel:        ptr.To("info"),
					LogFormat:       ptr.To("logfmt"),
				},
				Replicas:             3,
				CompressResponses:    true,
				LogQueriesLongerThan: ptr.To(v1alpha1.Duration("10s")),
				LabelsMaxRetries:     3,
				QueryRangeMaxRetries: 3,
				QueryLabelSelector: &metav1.LabelSelector{
					MatchLabels: map[string]string{
						"operator.thanos.io/query-api": "true",
					},
				},
				QueryRangeSplitInterval: ptr.To(v1alpha1.Duration("2d")),
				LabelsSplitInterval:     ptr.To(v1alpha1.Duration("2d")),
				LabelsDefaultTimeRange:  ptr.To(v1alpha1.Duration("336h")),
			},
		},
	}
}

func rulerCR(namespace string) runtime.Object {
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
				Image:           ptr.To(stageTemplateFn("RULER", StageImages)),
				ImagePullPolicy: ptr.To(corev1.PullIfNotPresent),
				LogLevel:        ptr.To("info"),
				LogFormat:       ptr.To("logfmt"),
			},
			Replicas: 2,
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
			ObjectStorageConfig: stageTemplateFn("DEFAULT", StageObjectStorageBucket),
			AlertmanagerURL:     "dnssrv+http://alertmanager-cluster." + namespace + ".svc.cluster.local:9093",
			AlertLabelDrop:      []string{"rule_replica"},
			Retention:           v1alpha1.Duration("48h"),
			EvaluationInterval:  v1alpha1.Duration("1m"),
			StorageSize:         string(stageTemplateFn("RULER", StageStorageSize)),
		},
	}
}

func compactCR(namespace string) []runtime.Object {
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
				Image:           ptr.To(stageTemplateFn("COMPACT_DEFAULT", StageImages)),
				ImagePullPolicy: ptr.To(corev1.PullIfNotPresent),
				LogLevel:        ptr.To("info"),
				LogFormat:       ptr.To("logfmt"),
			},
			ObjectStorageConfig: stageTemplateFn("DEFAULT", StageObjectStorageBucket),
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
			StorageSize: stageTemplateFn("COMPACT_DEFAULT", StageStorageSize),
		},
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
				Image:           ptr.To(stageTemplateFn("COMPACT_TELEMETER", StageImages)),
				ImagePullPolicy: ptr.To(corev1.PullIfNotPresent),
				LogLevel:        ptr.To("info"),
				LogFormat:       ptr.To("logfmt"),
			},
			ObjectStorageConfig: stageTemplateFn("TELEMETER", StageObjectStorageBucket),
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
			StorageSize: stageTemplateFn("COMPACT_TELEMETER", StageStorageSize),
		},
	}

	return []runtime.Object{defaultCompact, telemeterCompact}
}
