package observatorium

import (
	_ "embed"
	"fmt"
	"maps"
	"net"
	"sort"
	"time"

	"github.com/bwplotka/mimic"
	"github.com/bwplotka/mimic/encoding"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/alertmanager"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/memcached"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/compactor"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/query"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/queryfrontend"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/receive"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/ruler"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/store"
	"github.com/observatorium/observatorium/configuration_go/k8sutil"
	"github.com/observatorium/observatorium/configuration_go/openshift"
	"github.com/observatorium/observatorium/configuration_go/schemas/thanos/cache"
	memcachedclientcfg "github.com/observatorium/observatorium/configuration_go/schemas/thanos/cache/memcached"
	"github.com/observatorium/observatorium/configuration_go/schemas/thanos/log"
	thanostime "github.com/observatorium/observatorium/configuration_go/schemas/thanos/time"
	trclient "github.com/observatorium/observatorium/configuration_go/schemas/thanos/tracing/client"
	"github.com/observatorium/observatorium/configuration_go/schemas/thanos/tracing/jaeger"
	routev1 "github.com/openshift/api/route/v1"
	templatev1 "github.com/openshift/api/template/v1"
	monv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	"github.com/prometheus/common/model"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	policyv1 "k8s.io/api/policy/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/intstr"
)

const (
	thanosImage                     = "quay.io/thanos/thanos"
	thanosReceiveControllerImage    = "quay.io/observatorium/thanos-receive-controller"
	monitoringNamespace             = "openshift-customer-monitoring"
	servingCertSecretNameAnnotation = "service.alpha.openshift.io/serving-cert-secret-name"
	observatoriumInstanceLabel      = "observatorium/tenant" // used by selectors to select the correct observatorium instance
	ingestorControllerLabel         = "controller.receive.thanos.io"
	ingestorControllerLabelValue    = "thanos-receive-controller"
	ingestorControllerLabelHashring = ingestorControllerLabel + "/hashring"
	queryRuleName                   = "observatorium-thanos-query-rule"
	obsQueryFrontendName            = "observatorium-thanos-query-frontend"
	receiveRouterName               = "observatorium-thanos-receive-router"
	alertManagerName                = "observatorium-alertmanager"
)

//go:embed assets/store-auto-shard-relabel-configMap.sh
var storeAutoShardRelabelConfigMap string

// ObservatoriumMetrics contains the configuration common to all metrics instances in an observatorium instance
// and a list of ObservatoriumMetricsInstance configuring the individual metrics instances.
type ObservatoriumMetrics struct {
	Namespace                          string
	ThanosImageTag                     string
	Instances                          []*ObservatoriumMetricsInstance
	ReceiveLimitsGlobal                receive.GlobalLimitsConfig
	ReceiveLimitsDefault               receive.DefaultLimitsConfig
	ReceiveControllerImageTag          string
	ReceiveRouterPreManifestsHook      func(*receive.Router)
	QueryRulePreManifestsHook          func(*query.QueryDeployment)
	QueryAdhocPreManifestsHook         func(*query.QueryDeployment)
	QueryFrontendPreManifestsHook      func(*queryfrontend.QueryFrontendDeployment)
	QueryFrontendCachePreManifestsHook func(*memcached.MemcachedDeployment)
	AlertManagerPreManifestsHook       func(*alertmanager.AlertManagerStatefulSet)
	storesRegister                     []string
	queryRuleURL                       string
	queryAdhocURL                      string
}

// ObservatoriumMetricsInstance contains the configuration for a metrics instance in an observatorium instance.
// It includes all thanos components that are needed for a metrics instance, excluding commons components such as
// the receive router.
type ObservatoriumMetricsInstance struct {
	InstanceName                    string
	ObjStoreSecret                  string
	Tenants                         []Tenants
	StorePreManifestsHook           func(*store.StoreStatefulSet)
	IndexCachePreManifestsHook      func(*memcached.MemcachedDeployment)
	BucketCachePreManifestsHook     func(*memcached.MemcachedDeployment)
	CompactorPreManifestsHook       func(*compactor.CompactorStatefulSet)
	ReceiveIngestorPreManifestsHook func(*receive.Ingestor)
	RulerPreManifestsHook           func(*ruler.RulerStatefulSet)
}

// Tenants contains the configuration for a tenant in a metrics instance.
type Tenants struct {
	Name          string
	ID            string
	ReceiveLimits *receive.WriteLimitConfig
}

// Manifests generates the manifests for the metrics instance of observatorium.
func (o *ObservatoriumMetrics) Manifests(generator *mimic.Generator) {
	makeFileName := func(name, instanceName string) string {
		return fmt.Sprintf("observatorium-metrics-%s-%s-template.yaml", name, instanceName)
	}
	withStatusRemove := func(encoder encoding.Encoder) encoding.Encoder {
		return &statusRemoveEncoder{encoder: encoder}
	}

	for _, instanceCfg := range o.Instances {
		gen := generator.With(instanceCfg.InstanceName)
		gen.Add(makeFileName("receive-ingestor", instanceCfg.InstanceName), withStatusRemove(o.makeTenantReceiveIngestor(instanceCfg)))
		gen.Add(makeFileName("compact", instanceCfg.InstanceName), withStatusRemove(o.makeCompactor(instanceCfg)))
		gen.Add(makeFileName("store", instanceCfg.InstanceName), withStatusRemove(o.makeStore(instanceCfg)))
		gen.Add(makeFileName("ruler", instanceCfg.InstanceName), withStatusRemove(o.makeRuler(instanceCfg)))
	}

	// Order matters here, each component registers itself in the storesRegister slice or the queryRuleURL variable
	generator.Add("observatorium-metrics-receive-router-template.yaml", withStatusRemove(o.makeReceiveRouter()))
	generator.Add("observatorium-metrics-query-rule-template.yaml", withStatusRemove(o.makeQueryConfig(true, o.QueryRulePreManifestsHook)))
	generator.Add("observatorium-metrics-query-template.yaml", withStatusRemove(o.makeQueryConfig(false, o.QueryAdhocPreManifestsHook)))
	generator.Add("observatorium-metrics-query-frontend-template.yaml", withStatusRemove(o.makeQueryFrontend()))
	generator.Add("observatorium-metrics-alertmanager-template.yaml", withStatusRemove(o.makeAlertManager()))
}

func (o *ObservatoriumMetrics) makeAlertManager() encoding.Encoder {
	alertmanSts := alertmanager.NewAlertManager()

	// K8s config
	alertmanSts.Image = thanosImage
	alertmanSts.ImageTag = o.ThanosImageTag
	alertmanSts.Namespace = o.Namespace
	alertmanSts.Replicas = 2
	alertmanSts.Name = alertManagerName
	delete(alertmanSts.PodResources.Limits, corev1.ResourceCPU)
	alertmanSts.PodResources.Requests[corev1.ResourceCPU] = resource.MustParse("100m")
	alertmanSts.PodResources.Requests[corev1.ResourceMemory] = resource.MustParse("256Mi")
	alertmanSts.PodResources.Limits[corev1.ResourceMemory] = resource.MustParse("1Gi")
	tlsSecret := "alertmanager-tls"
	alertmanSts.Sidecars = []k8sutil.ContainerProvider{
		makeOauthProxy(9093, o.Namespace, alertmanSts.Name, tlsSecret),
	}

	// Alertmanager config
	alertmanSts.Options.LogLevel = log.LogLevelWarn
	alertmanSts.Options.LogFormat = log.LogFormatLogfmt
	alertmanSts.Options.StoragePath = "/data"
	headlessServiceName := alertmanSts.Name + "-cluster"
	if alertmanSts.Replicas > 1 {
		for i := 0; i < int(alertmanSts.Replicas); i++ {
			alertmanSts.Options.ClusterPeer = append(alertmanSts.Options.ClusterPeer, fmt.Sprintf("%s-%d.%s.%s.svc.cluster.local:9094", alertmanSts.Name, i, headlessServiceName, o.Namespace))
		}
	}
	alertmanSts.Options.ClusterReconnectTimeout = model.Duration(5 * time.Minute)
	executeIfNotNil(o.AlertManagerPreManifestsHook, alertmanSts)

	// Post process
	manifests := alertmanSts.Manifests()
	postProcessServiceMonitor(k8sutil.GetObject[*monv1.ServiceMonitor](manifests, ""), alertmanSts.Namespace)
	addQuayPullSecret(k8sutil.GetObject[*corev1.ServiceAccount](manifests, ""))
	service := k8sutil.GetObject[*corev1.Service](manifests, alertmanSts.Name)
	service.ObjectMeta.Annotations[servingCertSecretNameAnnotation] = tlsSecret
	// Add annotations for openshift oauth so that the route to access the query ui works
	serviceAccount := k8sutil.GetObject[*corev1.ServiceAccount](manifests, "")
	if serviceAccount.Annotations == nil {
		serviceAccount.Annotations = map[string]string{}
	}
	serviceAccount.Annotations["serviceaccounts.openshift.io/oauth-redirectreference.application"] = fmt.Sprintf(`{"kind":"OAuthRedirectReference","apiVersion":"v1","reference":{"kind":"Route","name":"%s"}}`, alertmanSts.Name)

	// Add route for oauth-proxy
	manifests["oauth-proxy-route"] = &routev1.Route{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Route",
			APIVersion: routev1.SchemeGroupVersion.String(),
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      alertmanSts.Name,
			Namespace: o.Namespace,
			Labels:    maps.Clone(k8sutil.GetObject[*appsv1.StatefulSet](manifests, "").ObjectMeta.Labels),
			Annotations: map[string]string{
				"cert-manager.io/issuer-kind": "ClusterIssuer",
				"cert-manager.io/issuer-name": "letsencrypt-prod-http",
			},
		},
		Spec: routev1.RouteSpec{
			Port: &routev1.RoutePort{
				TargetPort: intstr.FromString("https"),
			},
			TLS: &routev1.TLSConfig{
				Termination:                   routev1.TLSTerminationReencrypt,
				InsecureEdgeTerminationPolicy: routev1.InsecureEdgeTerminationPolicyRedirect,
			},
			To: routev1.RouteTargetReference{
				Kind: "Service",
				Name: alertmanSts.Name,
			},
		},
	}

	// Set encoders and template params
	params := []templatev1.Parameter{}
	params = append(params, templatev1.Parameter{
		Name:     "OAUTH_PROXY_COOKIE_SECRET",
		Generate: "expression",
		From:     "[a-zA-Z0-9]{40}",
	})
	alertEncoder := NewStdTemplateYAML(alertmanSts.Name, "ALERTMGR").WithLogLevel()
	params = append(params, alertEncoder.TemplateParams()...)
	template := openshift.WrapInTemplate("", manifests, metav1.ObjectMeta{
		Name: alertmanSts.Name,
	}, sortTemplateParams(params))

	return alertEncoder.Wrap(encoding.GhodssYAML(template[""]))
}

func (o *ObservatoriumMetrics) makeRuler(instanceCfg *ObservatoriumMetricsInstance) encoding.Encoder {
	rulerStatefulset := ruler.NewRuler()

	// K8s config
	rulerStatefulset.Name = fmt.Sprintf("%s-%s", rulerStatefulset.Name, instanceCfg.InstanceName)
	rulerStatefulset.CommonLabels[observatoriumInstanceLabel] = instanceCfg.InstanceName
	rulerStatefulset.Image = thanosImage
	rulerStatefulset.ImageTag = o.ThanosImageTag
	rulerStatefulset.Namespace = o.Namespace
	rulerStatefulset.Replicas = 1
	delete(rulerStatefulset.PodResources.Limits, corev1.ResourceCPU)
	rulerStatefulset.PodResources.Requests[corev1.ResourceCPU] = resource.MustParse("100m")
	rulerStatefulset.PodResources.Requests[corev1.ResourceMemory] = resource.MustParse("256Mi")
	rulerStatefulset.PodResources.Limits[corev1.ResourceMemory] = resource.MustParse("1Gi")
	tlsSecret := "ruler-tls"
	rulesSyncer := ruler.NewRulesSyncerContainer(&ruler.RulesSyncerOptions{
		File:            "/etc/thanos-rule-syncer/observatorium.yaml",
		Interval:        60,
		RulesBackendUrl: fmt.Sprintf("http://%s.%s.svc.cluster.local:10902", rulesObjstoreName, o.Namespace),
		ThanosRuleUrl: &net.TCPAddr{
			IP:   net.ParseIP("127.0.0.1"),
			Port: 10902,
		},
	})
	rulesSyncer.Image = "quay.io/observatorium/thanos-rule-syncer"
	rulesSyncer.ImageTag = "main-2022-09-14-338f9ec"

	rulerStatefulset.Options.RuleFile = append(rulerStatefulset.Options.RuleFile, ruler.RuleFileOption{
		FileName:   "observatorium.yaml",
		VolumeName: "rule-syncer",
		ParentDir:  "synced-rules",
	})
	rulerStatefulset.Sidecars = []k8sutil.ContainerProvider{
		rulesSyncer,
		&k8sutil.Container{
			Name:  "configmap-reloader",
			Image: "quay.io/openshift/origin-configmap-reloader:4.5.0",
			Args: []string{
				"-volume-dir=/etc/thanos-rule-syncer",
				"-webhook-url=http://localhost:10902/-/reload",
			},
			Resources: k8sutil.NewResourcesRequirements("100m", "200m", "100Mi", "200Mi"),
			VolumeMounts: []corev1.VolumeMount{
				{
					Name:      "observatorium-rules",
					MountPath: "/etc/thanos/rules/observatorium-rules",
				},
			},
		},
		makeOauthProxy(10902, o.Namespace, rulerStatefulset.Name, tlsSecret),
		makeJaegerAgent("observatorium-tools"),
	}
	rulerStatefulset.Env = append(rulerStatefulset.Env, objStoreEnvVars(instanceCfg.ObjStoreSecret)...)

	// Ruler config
	rulerStatefulset.Options.LogLevel = log.LogLevelWarn
	rulerStatefulset.Options.LogFormat = log.LogFormatLogfmt
	rulerStatefulset.Options.Label = []ruler.Label{
		{Key: "rule_replica", Value: "\"$(NAME)\""},
	}
	rulerStatefulset.Options.TracingConfig = &trclient.TracingConfig{
		Type: trclient.Jaeger,
		Config: jaeger.Config{
			SamplerParam: 2,
			SamplerType:  jaeger.SamplerTypeRateLimiting,
			ServiceName:  rulerStatefulset.CommonLabels[k8sutil.NameLabel],
		},
	}
	rulerStatefulset.Options.AlertLabelDrop = []string{"rule_replica"}
	rulerStatefulset.Options.TsdbRetention = model.Duration(2 * 24 * time.Hour)
	rulerStatefulset.Options.Query = []string{
		fmt.Sprintf("http://%s.%s.svc.cluster.local:10902", queryRuleName, o.Namespace), // hardcoded
	}

	//           --alertmanagers.url=dnssrv+http://observatorium-alertmanager-peers.observatorium-mst-stage.svc.cluster.local:9093

	// Register the store api
	o.storesRegister = append(o.storesRegister, fmt.Sprintf("http://%s.%s.svc.cluster.local:10902", rulerStatefulset.Name, rulerStatefulset.Namespace))

	executeIfNotNil(instanceCfg.RulerPreManifestsHook, rulerStatefulset)

	// Post process
	manifests := rulerStatefulset.Manifests()
	postProcessServiceMonitor(k8sutil.GetObject[*monv1.ServiceMonitor](manifests, ""), rulerStatefulset.Namespace)
	addQuayPullSecret(k8sutil.GetObject[*corev1.ServiceAccount](manifests, ""))
	service := k8sutil.GetObject[*corev1.Service](manifests, "")
	service.ObjectMeta.Annotations[servingCertSecretNameAnnotation] = tlsSecret
	// Add annotations for openshift oauth so that the route to access the query ui works
	serviceAccount := k8sutil.GetObject[*corev1.ServiceAccount](manifests, "")
	if serviceAccount.Annotations == nil {
		serviceAccount.Annotations = map[string]string{}
	}
	serviceAccount.Annotations["serviceaccounts.openshift.io/oauth-redirectreference.application"] = fmt.Sprintf(`{"kind":"OAuthRedirectReference","apiVersion":"v1","reference":{"kind":"Route","name":"%s"}}`, rulerStatefulset.Name)

	// Add route for oauth-proxy
	manifests["oauth-proxy-route"] = &routev1.Route{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Route",
			APIVersion: routev1.SchemeGroupVersion.String(),
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      rulerStatefulset.Name,
			Namespace: o.Namespace,
			Labels:    maps.Clone(k8sutil.GetObject[*appsv1.StatefulSet](manifests, "").ObjectMeta.Labels),
			Annotations: map[string]string{
				"cert-manager.io/issuer-kind": "ClusterIssuer",
				"cert-manager.io/issuer-name": "letsencrypt-prod-http",
			},
		},
		Spec: routev1.RouteSpec{
			Port: &routev1.RoutePort{
				TargetPort: intstr.FromString("https"),
			},
			TLS: &routev1.TLSConfig{
				Termination:                   routev1.TLSTerminationReencrypt,
				InsecureEdgeTerminationPolicy: routev1.InsecureEdgeTerminationPolicyRedirect,
			},
			To: routev1.RouteTargetReference{
				Kind: "Service",
				Name: rulerStatefulset.Name,
			},
		},
	}

	// Set encoders and template params
	params := []templatev1.Parameter{}
	params = append(params, templatev1.Parameter{
		Name:     "OAUTH_PROXY_COOKIE_SECRET",
		Generate: "expression",
		From:     "[a-zA-Z0-9]{40}",
	})
	rulerEncoder := NewStdTemplateYAML(rulerStatefulset.Name, "RULER").WithLogLevel()
	params = append(params, rulerEncoder.TemplateParams()...)
	template := openshift.WrapInTemplate("", manifests, metav1.ObjectMeta{
		Name: rulerStatefulset.Name,
	}, sortTemplateParams(params))

	return rulerEncoder.Wrap(encoding.GhodssYAML(template[""]))
}

func (o *ObservatoriumMetrics) makeQueryFrontend() encoding.Encoder {
	queryFrontend := queryfrontend.NewQueryFrontend()

	// K8s config
	queryFrontend.Name = obsQueryFrontendName
	queryFrontend.Image = thanosImage
	queryFrontend.ImageTag = o.ThanosImageTag
	queryFrontend.Namespace = o.Namespace
	queryFrontend.Replicas = 1
	delete(queryFrontend.PodResources.Limits, corev1.ResourceCPU)
	queryFrontend.PodResources.Requests[corev1.ResourceCPU] = resource.MustParse("100m")
	queryFrontend.PodResources.Requests[corev1.ResourceMemory] = resource.MustParse("256Mi")
	queryFrontend.PodResources.Limits[corev1.ResourceMemory] = resource.MustParse("1Gi")
	tlsSecret := "query-frontend-tls"
	queryFrontend.Sidecars = []k8sutil.ContainerProvider{
		makeOauthProxy(10902, o.Namespace, queryFrontend.Name, tlsSecret),
		makeJaegerAgent("observatorium-tools"),
	}

	// Query-fe config
	queryFrontend.Options.LogLevel = log.LogLevelWarn
	queryFrontend.Options.LogFormat = log.LogFormatLogfmt
	queryFrontend.Options.QueryFrontendCompressResponses = true
	queryFrontend.Options.QueryFrontendDownstreamURL = o.queryAdhocURL
	queryFrontend.Options.QueryFrontendLogQueriesLongerThan = model.Duration(5 * time.Second)
	// Add memcached config
	queryFrontend.Options.TracingConfig = &trclient.TracingConfig{
		Type: trclient.Jaeger,
		Config: jaeger.Config{
			SamplerParam: 2,
			SamplerType:  jaeger.SamplerTypeRateLimiting,
			ServiceName:  queryFrontend.CommonLabels[k8sutil.NameLabel],
		},
	}
	queryFrontend.Options.QueryRangeSplitInterval = model.Duration(24 * time.Hour)
	queryFrontend.Options.LabelsSplitInterval = model.Duration(24 * time.Hour)
	zero := 0
	queryFrontend.Options.QueryRangeMaxRetriesPerRequest = &zero
	queryFrontend.Options.LabelsMaxRetriesPerRequest = &zero
	queryFrontend.Options.LabelsDefaultTimeRange = model.Duration(14 * 24 * time.Hour)
	queryFrontend.Options.CacheCompressionType = queryfrontend.CacheCompressionTypeSnappy
	cacheName := "observatorium-thanos-query-range-cache-memcached"
	queryFrontend.Options.QueryRangeResponseCacheConfig = cache.NewResponseCacheConfig(memcachedclientcfg.MemcachedClientConfig{
		Addresses: []string{
			fmt.Sprintf("dnssrv+_client._tcp.%s.%s.svc", cacheName, o.Namespace),
		},
		MaxAsyncBufferSize:     2 * 10e5,
		MaxAsyncConcurrency:    200,
		MaxGetMultiBatchSize:   100,
		MaxGetMultiConcurrency: 1000,
		MaxIdleConnections:     1300,
		MaxItemSize:            "64MiB",
		Timeout:                2 * time.Second,
	})

	executeIfNotNil(o.QueryFrontendPreManifestsHook, queryFrontend)

	// Post process
	manifests := queryFrontend.Manifests()
	postProcessServiceMonitor(k8sutil.GetObject[*monv1.ServiceMonitor](manifests, ""), queryFrontend.Namespace)
	addQuayPullSecret(k8sutil.GetObject[*corev1.ServiceAccount](manifests, ""))
	service := k8sutil.GetObject[*corev1.Service](manifests, "")
	service.ObjectMeta.Annotations[servingCertSecretNameAnnotation] = tlsSecret
	// Add annotations for openshift oauth so that the route to access the query ui works
	serviceAccount := k8sutil.GetObject[*corev1.ServiceAccount](manifests, "")
	if serviceAccount.Annotations == nil {
		serviceAccount.Annotations = map[string]string{}
	}
	serviceAccount.Annotations["serviceaccounts.openshift.io/oauth-redirectreference.application"] = fmt.Sprintf(`{"kind":"OAuthRedirectReference","apiVersion":"v1","reference":{"kind":"Route","name":"%s"}}`, queryFrontend.Name)

	// Add route for oauth-proxy
	manifests["oauth-proxy-route"] = &routev1.Route{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Route",
			APIVersion: routev1.SchemeGroupVersion.String(),
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      queryFrontend.Name,
			Namespace: o.Namespace,
			Labels:    maps.Clone(k8sutil.GetObject[*appsv1.Deployment](manifests, "").ObjectMeta.Labels),
			Annotations: map[string]string{
				"cert-manager.io/issuer-kind": "ClusterIssuer",
				"cert-manager.io/issuer-name": "letsencrypt-prod-http",
			},
		},
		Spec: routev1.RouteSpec{
			Port: &routev1.RoutePort{
				TargetPort: intstr.FromString("https"),
			},
			TLS: &routev1.TLSConfig{
				Termination:                   routev1.TLSTerminationReencrypt,
				InsecureEdgeTerminationPolicy: routev1.InsecureEdgeTerminationPolicyRedirect,
			},
			To: routev1.RouteTargetReference{
				Kind: "Service",
				Name: queryFrontend.Name,
			},
		},
	}

	// Add cache
	rangeCache := "observatorium-thanos-query-range-cache-memcached"
	cachePreManHook := func(memdep *memcached.MemcachedDeployment) {
		memdep.CommonLabels[k8sutil.ComponentLabel] = "query-range-cache"
		executeIfNotNil(o.QueryFrontendCachePreManifestsHook, memdep)
	}
	maps.Copy(manifests, makeMemcached(rangeCache, o.Namespace, cachePreManHook))

	// Set encoders and template params
	params := []templatev1.Parameter{}
	params = append(params, templatev1.Parameter{
		Name:     "OAUTH_PROXY_COOKIE_SECRET",
		Generate: "expression",
		From:     "[a-zA-Z0-9]{40}",
	})
	qfeEncoder := NewStdTemplateYAML(queryFrontend.Name, "QFE").WithLogLevel()
	params = append(params, qfeEncoder.TemplateParams()...)
	template := openshift.WrapInTemplate("", manifests, metav1.ObjectMeta{
		Name: queryFrontend.Name,
	}, sortTemplateParams(params))

	return qfeEncoder.Wrap(encoding.GhodssYAML(template[""]))
}

func (o *ObservatoriumMetrics) makeQueryConfig(isRuleQuery bool, preManifestHook func(*query.QueryDeployment)) encoding.Encoder {
	queryDplt := query.NewQuery()

	// K8s config
	if isRuleQuery {
		queryDplt.Name = queryRuleName
		queryDplt.CommonLabels[k8sutil.NameLabel] = queryDplt.CommonLabels[k8sutil.NameLabel] + "-rule"
		// Regenerate the affinity to update the name selector
		queryDplt.Affinity = k8sutil.NewAntiAffinity(nil, map[string]string{
			k8sutil.NameLabel:     queryDplt.CommonLabels[k8sutil.NameLabel],
			k8sutil.InstanceLabel: queryDplt.CommonLabels[k8sutil.InstanceLabel],
		})
	}
	queryDplt.Image = thanosImage
	queryDplt.ImageTag = o.ThanosImageTag
	queryDplt.Namespace = o.Namespace
	queryDplt.Replicas = 1
	delete(queryDplt.PodResources.Limits, corev1.ResourceCPU)
	queryDplt.PodResources.Requests[corev1.ResourceCPU] = resource.MustParse("250m")
	queryDplt.PodResources.Requests[corev1.ResourceMemory] = resource.MustParse("2Gi")
	queryDplt.PodResources.Limits[corev1.ResourceMemory] = resource.MustParse("8Gi")
	var tlsSecret string
	if isRuleQuery {
		tlsSecret = "query-rule-tls"
	} else {
		tlsSecret = "query-adhoc-tls"
	}
	queryDplt.Sidecars = []k8sutil.ContainerProvider{
		makeJaegerAgent("observatorium-tools"),
		makeOauthProxy(10902, o.Namespace, queryDplt.Name, tlsSecret),
	}

	// Query config
	queryDplt.Options.LogLevel = log.LogLevelWarn
	queryDplt.Options.LogFormat = log.LogFormatLogfmt
	queryDplt.Options.QueryReplicaLabel = []string{"replica", "prometheus_replica", "rule_replica"}
	queryDplt.Options.Endpoint = append(queryDplt.Options.Endpoint, o.storesRegister...)
	sort.Strings(queryDplt.Options.Endpoint) // sort to make the output deterministic and avoid noisy diffs
	queryDplt.Options.QueryTimeout = model.Duration(15 * time.Minute)
	queryDplt.Options.QueryLookbackDelta = model.Duration(15 * time.Minute)
	queryDplt.Options.WebPrefixHeader = "X-Forwarded-Prefix"
	queryDplt.Options.TracingConfig = &trclient.TracingConfig{
		Type: trclient.Jaeger,
		Config: jaeger.Config{
			SamplerParam: 2,
			SamplerType:  jaeger.SamplerTypeRateLimiting,
			ServiceName:  queryDplt.CommonLabels[k8sutil.NameLabel],
		},
	}
	queryDplt.Options.QueryAutoDownsampling = true
	queryDplt.Options.QueryPromQLEngine = "prometheus"
	queryDplt.Options.QueryMaxConcurrent = 10
	if !isRuleQuery {
		queryDplt.Options.QueryTelemetryRequestDurationSecondsQuantiles = []float64{0.1, 0.25, 0.75, 1.25, 1.75, 2.5, 3, 5, 10, 15, 30, 60, 120}
	}

	ruleUrl := fmt.Sprintf("http://%s.%s.svc.cluster.local:10902", queryDplt.Name, queryDplt.Namespace)
	if isRuleQuery {
		o.queryRuleURL = ruleUrl
	} else {
		o.queryAdhocURL = ruleUrl
	}

	executeIfNotNil(preManifestHook, queryDplt)

	// Post process
	manifests := queryDplt.Manifests()
	postProcessServiceMonitor(k8sutil.GetObject[*monv1.ServiceMonitor](manifests, ""), queryDplt.Namespace)
	addQuayPullSecret(k8sutil.GetObject[*corev1.ServiceAccount](manifests, ""))
	service := k8sutil.GetObject[*corev1.Service](manifests, "")
	service.ObjectMeta.Annotations[servingCertSecretNameAnnotation] = tlsSecret
	postProcessServiceMonitor(k8sutil.GetObject[*monv1.ServiceMonitor](manifests, ""), queryDplt.Namespace)
	// Add annotations for openshift oauth so that the route to access the query ui works
	serviceAccount := k8sutil.GetObject[*corev1.ServiceAccount](manifests, "")
	if serviceAccount.Annotations == nil {
		serviceAccount.Annotations = map[string]string{}
	}
	serviceAccount.Annotations["serviceaccounts.openshift.io/oauth-redirectreference.application"] = fmt.Sprintf(`{"kind":"OAuthRedirectReference","apiVersion":"v1","reference":{"kind":"Route","name":"%s"}}`, queryDplt.Name)

	// Add route for oauth-proxy
	manifests["oauth-proxy-route"] = &routev1.Route{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Route",
			APIVersion: routev1.SchemeGroupVersion.String(),
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      queryDplt.Name,
			Namespace: o.Namespace,
			Labels:    maps.Clone(k8sutil.GetObject[*appsv1.Deployment](manifests, "").ObjectMeta.Labels),
			Annotations: map[string]string{
				"cert-manager.io/issuer-kind": "ClusterIssuer",
				"cert-manager.io/issuer-name": "letsencrypt-prod-http",
			},
		},
		Spec: routev1.RouteSpec{
			Port: &routev1.RoutePort{
				TargetPort: intstr.FromString("https"),
			},
			TLS: &routev1.TLSConfig{
				Termination:                   routev1.TLSTerminationReencrypt,
				InsecureEdgeTerminationPolicy: routev1.InsecureEdgeTerminationPolicyRedirect,
			},
			To: routev1.RouteTargetReference{
				Kind: "Service",
				Name: queryDplt.Name,
			},
		},
	}

	// Set encoders and template params
	params := []templatev1.Parameter{}
	params = append(params, templatev1.Parameter{
		Name:     "OAUTH_PROXY_COOKIE_SECRET",
		Generate: "expression",
		From:     "[a-zA-Z0-9]{40}",
	})
	queryEncoder := NewStdTemplateYAML(queryDplt.Name, "QUERY").WithLogLevel()
	params = append(params, queryEncoder.TemplateParams()...)
	template := openshift.WrapInTemplate("", manifests, metav1.ObjectMeta{
		Name: queryDplt.Name,
	}, sortTemplateParams(params))

	return queryEncoder.Wrap(encoding.GhodssYAML(template[""]))
}

// makeReceiveRouter creates a base receive router component that can be derived from using the preManifestsHook
// for each tenant instance of the observatorium metrics.
func (o *ObservatoriumMetrics) makeReceiveRouter() encoding.Encoder {
	router := receive.NewRouter()

	// K8s config
	router.Name = receiveRouterName
	router.Image = thanosImage
	router.ImageTag = o.ThanosImageTag
	router.Namespace = o.Namespace
	router.Replicas = 1
	delete(router.PodResources.Limits, corev1.ResourceCPU)
	router.PodResources.Requests[corev1.ResourceCPU] = resource.MustParse("1")
	router.PodResources.Requests[corev1.ResourceMemory] = resource.MustParse("5Gi")
	router.PodResources.Limits[corev1.ResourceMemory] = resource.MustParse("24Gi")
	router.Sidecars = []k8sutil.ContainerProvider{makeJaegerAgent("observatorium-tools")}

	// Router config
	router.Options.LogLevel = log.LogLevelWarn
	router.Options.LogFormat = log.LogFormatLogfmt
	router.Options.TracingConfig = &trclient.TracingConfig{
		Type: trclient.Jaeger,
		Config: jaeger.Config{
			SamplerParam: 2,
			SamplerType:  jaeger.SamplerTypeRateLimiting,
			ServiceName:  "thanos-receive-router",
		},
	}
	router.Options.Label = []receive.Label{
		{
			Key:   "receive",
			Value: "\"true\"",
		},
	}

	receiveLimits := receive.NewReceiveLimitsConfig()
	receiveLimits.WriteLimits.DefaultLimits = o.ReceiveLimitsDefault
	receiveLimits.WriteLimits.GlobalLimits = o.ReceiveLimitsGlobal
	receiveLimits.WriteLimits.TenantsLimits = map[string]receive.WriteLimitConfig{}
	for _, instanceCfg := range o.Instances {
		for _, tenant := range instanceCfg.Tenants {
			if tenant.ReceiveLimits == nil {
				continue
			}

			receiveLimits.WriteLimits.TenantsLimits[tenant.ID] = *tenant.ReceiveLimits
		}
	}
	router.Options.ReceiveLimitsConfigFile = receive.NewReceiveLimitsConfigFile(router.Name+"-limits", receiveLimits)

	generatedHashringCm := "thanos-receive-hashring-generated"
	// Leave the config map empty, it is generated by the controller
	router.Options.ReceiveHashringsFile = receive.NewReceiveHashringConfigFile(generatedHashringCm, receive.HashRingsConfig{})

	executeIfNotNil(o.ReceiveRouterPreManifestsHook, router)

	// Post process
	baseHashringCm := "thanos-receive-hashring"
	manifests := router.Manifests()
	postProcessServiceMonitor(k8sutil.GetObject[*monv1.ServiceMonitor](manifests, ""), router.Namespace)
	addQuayPullSecret(k8sutil.GetObject[*corev1.ServiceAccount](manifests, ""))

	// Add pod disruption budget
	labels := maps.Clone(k8sutil.GetObject[*appsv1.Deployment](manifests, "").ObjectMeta.Labels)
	delete(labels, k8sutil.VersionLabel)
	manifests["router-pdb"] = &policyv1.PodDisruptionBudget{
		TypeMeta: metav1.TypeMeta{
			Kind:       "PodDisruptionBudget",
			APIVersion: policyv1.SchemeGroupVersion.String(),
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      router.Name,
			Namespace: o.Namespace,
			Labels:    labels,
		},
		Spec: policyv1.PodDisruptionBudgetSpec{
			MaxUnavailable: &intstr.IntOrString{

				Type:   intstr.Int,
				IntVal: 1,
			},
			Selector: &metav1.LabelSelector{
				MatchLabels: labels,
			},
		},
	}

	// Add thanos-receive-controller
	controller := receive.NewController()
	// Controller k8s config
	controller.Image = thanosReceiveControllerImage
	controller.ImageTag = o.ReceiveControllerImageTag
	controller.Namespace = o.Namespace
	controller.Replicas = 1

	var baseHashring receive.HashRingsConfig = []receive.HashringConfig{}
	for _, instanceCfg := range o.Instances {
		newHashring := receive.HashringConfig{
			Hashring:  instanceCfg.InstanceName,
			Algorithm: receive.HashRingAlgorithmKetama,
		}

		for _, tenant := range instanceCfg.Tenants {
			newHashring.Tenants = append(newHashring.Tenants, tenant.ID)
		}

		baseHashring = append(baseHashring, newHashring)
	}
	hashringFileName := "hashrings.json"
	controller.ConfigMaps[baseHashringCm] = map[string]string{
		hashringFileName: baseHashring.String(),
	}

	// Controller config
	controller.Options.ConfigMapName = baseHashringCm
	controller.Options.ConfigMapGeneratedName = generatedHashringCm
	controller.Options.Namespace = o.Namespace
	controller.Options.FileName = hashringFileName

	controllerManifests := controller.Manifests()
	for k, v := range controllerManifests {
		manifests[k] = v
	}

	// Set encoders and template params
	params := []templatev1.Parameter{}
	queryEncoder := NewStdTemplateYAML(router.Name, "ROUTER").WithLogLevel()
	params = append(params, queryEncoder.TemplateParams()...)
	template := openshift.WrapInTemplate("", manifests, metav1.ObjectMeta{
		Name: router.Name,
	}, sortTemplateParams(params))

	return queryEncoder.Wrap(encoding.GhodssYAML(template[""]))
}

// makeReceiveIngestor creates a base receive ingestor component that can be derived from using the preManifestsHook
func (o *ObservatoriumMetrics) makeTenantReceiveIngestor(instanceCfg *ObservatoriumMetricsInstance) encoding.Encoder {
	ingestor := receive.NewIngestor()
	ingestor.Name = fmt.Sprintf("%s-%s", ingestor.Name, instanceCfg.InstanceName)
	ingestor.CommonLabels[observatoriumInstanceLabel] = instanceCfg.InstanceName
	ingestor.Image = thanosImage
	ingestor.ImageTag = o.ThanosImageTag
	ingestor.Namespace = o.Namespace
	ingestor.Replicas = 1
	ingestor.VolumeType = "gp2"
	ingestor.VolumeSize = "50Gi"
	delete(ingestor.PodResources.Limits, corev1.ResourceCPU)
	ingestor.PodResources.Requests[corev1.ResourceCPU] = resource.MustParse("1")
	ingestor.PodResources.Requests[corev1.ResourceMemory] = resource.MustParse("10Gi")
	ingestor.PodResources.Limits[corev1.ResourceMemory] = resource.MustParse("24Gi")
	ingestor.Env = deleteObjStoreEnv(ingestor.Env) // delete the default objstore env vars
	ingestor.Env = append(ingestor.Env, objStoreEnvVars(instanceCfg.ObjStoreSecret)...)
	ingestor.Sidecars = []k8sutil.ContainerProvider{makeJaegerAgent("observatorium-tools")}

	// Router config
	ingestor.Options.LogLevel = log.LogLevelWarn
	ingestor.Options.LogFormat = log.LogFormatLogfmt
	ingestor.Options.TracingConfig = &trclient.TracingConfig{
		Type: trclient.Jaeger,
		Config: jaeger.Config{
			SamplerParam: 2,
			SamplerType:  jaeger.SamplerTypeRateLimiting,
			ServiceName:  "thanos-receive-router",
		},
	}
	ingestor.Options.Label = []receive.Label{
		{
			Key:   "replica",
			Value: "\"$(POD_NAME)\"",
		},
	}

	executeIfNotNil(instanceCfg.ReceiveIngestorPreManifestsHook, ingestor)

	// Register the store for the query component
	o.storesRegister = append(o.storesRegister, fmt.Sprintf("dnssrv+_grpc._tcp.%s.%s.svc.cluster.local", ingestor.Name, o.Namespace))

	// Post process
	manifests := ingestor.Manifests()
	postProcessServiceMonitor(k8sutil.GetObject[*monv1.ServiceMonitor](manifests, ""), ingestor.Namespace)
	statefulSetLabels := k8sutil.GetObject[*appsv1.StatefulSet](manifests, "").ObjectMeta.Labels
	statefulSetLabels[ingestorControllerLabel] = ingestorControllerLabelValue
	statefulSetLabels[ingestorControllerLabelHashring] = instanceCfg.InstanceName
	addQuayPullSecret(k8sutil.GetObject[*corev1.ServiceAccount](manifests, ""))

	// Add pod disruption budget
	labels := maps.Clone(k8sutil.GetObject[*appsv1.StatefulSet](manifests, "").ObjectMeta.Labels)
	delete(labels, k8sutil.VersionLabel)
	manifests["store-pdb"] = &policyv1.PodDisruptionBudget{
		TypeMeta: metav1.TypeMeta{
			Kind:       "PodDisruptionBudget",
			APIVersion: policyv1.SchemeGroupVersion.String(),
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      ingestor.Name,
			Namespace: o.Namespace,
			Labels:    labels,
		},
		Spec: policyv1.PodDisruptionBudgetSpec{
			MaxUnavailable: &intstr.IntOrString{

				Type:   intstr.Int,
				IntVal: 1,
			},
			Selector: &metav1.LabelSelector{
				MatchLabels: labels,
			},
		},
	}

	// Set encoders and template params
	params := []templatev1.Parameter{}
	ingestorEncoder := NewStdTemplateYAML(ingestor.Name, "INGESTOR").WithLogLevel()
	params = append(params, ingestorEncoder.TemplateParams()...)
	template := openshift.WrapInTemplate("", manifests, metav1.ObjectMeta{
		Name: ingestor.Name,
	}, sortTemplateParams(params))

	return ingestorEncoder.Wrap(encoding.GhodssYAML(template[""]))
}

// makeCompactor creates a base compactor component that can be derived from using the preManifestsHook.
func (o *ObservatoriumMetrics) makeCompactor(instanceCfg *ObservatoriumMetricsInstance) encoding.Encoder {
	// K8s config
	compactorSatefulset := compactor.NewCompactor()
	compactorSatefulset.Name = fmt.Sprintf("%s-%s", compactorSatefulset.Name, instanceCfg.InstanceName)
	compactorSatefulset.CommonLabels[observatoriumInstanceLabel] = instanceCfg.InstanceName
	compactorSatefulset.Image = thanosImage
	compactorSatefulset.ImageTag = o.ThanosImageTag
	compactorSatefulset.Namespace = o.Namespace
	compactorSatefulset.Replicas = 1
	delete(compactorSatefulset.PodResources.Limits, corev1.ResourceCPU)
	compactorSatefulset.PodResources.Requests[corev1.ResourceCPU] = resource.MustParse("200m")
	compactorSatefulset.PodResources.Requests[corev1.ResourceMemory] = resource.MustParse("1Gi")
	compactorSatefulset.PodResources.Limits[corev1.ResourceMemory] = resource.MustParse("5Gi")
	compactorSatefulset.VolumeType = "gp2"
	compactorSatefulset.VolumeSize = "50Gi"
	compactorSatefulset.Env = deleteObjStoreEnv(compactorSatefulset.Env) // delete the default objstore env vars
	compactorSatefulset.Env = append(compactorSatefulset.Env, objStoreEnvVars(instanceCfg.ObjStoreSecret)...)
	tlsSecret := "compact-tls-" + instanceCfg.InstanceName
	compactorSatefulset.Sidecars = []k8sutil.ContainerProvider{makeOauthProxy(10902, o.Namespace, compactorSatefulset.Name, tlsSecret)}

	// Compactor config
	compactorSatefulset.Options.LogLevel = log.LogLevelWarn
	compactorSatefulset.Options.RetentionResolutionRaw = 0
	compactorSatefulset.Options.RetentionResolution5m = 0
	compactorSatefulset.Options.RetentionResolution1h = 0
	compactorSatefulset.Options.DeleteDelay = 24 * time.Hour
	compactorSatefulset.Options.CompactConcurrency = 1
	compactorSatefulset.Options.DownsampleConcurrency = 1
	compactorSatefulset.Options.DeduplicationReplicaLabel = "replica"
	compactorSatefulset.Options.AddExtraOpts("--debug.max-compaction-level=3")

	executeIfNotNil(instanceCfg.CompactorPreManifestsHook, compactorSatefulset)

	// Post process
	manifests := compactorSatefulset.Manifests()
	service := k8sutil.GetObject[*corev1.Service](manifests, "")
	service.ObjectMeta.Annotations[servingCertSecretNameAnnotation] = tlsSecret
	postProcessServiceMonitor(k8sutil.GetObject[*monv1.ServiceMonitor](manifests, ""), compactorSatefulset.Namespace)
	// Add annotations for openshift oauth so that the route to access the compactor ui works
	serviceAccount := k8sutil.GetObject[*corev1.ServiceAccount](manifests, "")
	if serviceAccount.Annotations == nil {
		serviceAccount.Annotations = map[string]string{}
	}
	serviceAccount.Annotations["serviceaccounts.openshift.io/oauth-redirectreference.application"] = fmt.Sprintf(`{"kind":"OAuthRedirectReference","apiVersion":"v1","reference":{"kind":"Route","name":"%s"}}`, compactorSatefulset.Name)

	// Add pod disruption budget
	labels := maps.Clone(k8sutil.GetObject[*appsv1.StatefulSet](manifests, "").ObjectMeta.Labels)
	delete(labels, k8sutil.VersionLabel)
	manifests["store-pdb"] = &policyv1.PodDisruptionBudget{
		TypeMeta: metav1.TypeMeta{
			Kind:       "PodDisruptionBudget",
			APIVersion: policyv1.SchemeGroupVersion.String(),
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      compactorSatefulset.Name,
			Namespace: o.Namespace,
			Labels:    labels,
		},
		Spec: policyv1.PodDisruptionBudgetSpec{
			MaxUnavailable: &intstr.IntOrString{

				Type:   intstr.Int,
				IntVal: 1,
			},
			Selector: &metav1.LabelSelector{
				MatchLabels: labels,
			},
		},
	}

	// Add route for oauth-proxy
	manifests["oauth-proxy-route"] = &routev1.Route{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Route",
			APIVersion: routev1.SchemeGroupVersion.String(),
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      compactorSatefulset.Name,
			Namespace: o.Namespace,
			Labels:    labels,
			Annotations: map[string]string{
				"cert-manager.io/issuer-kind": "ClusterIssuer",
				"cert-manager.io/issuer-name": "letsencrypt-prod-http",
			},
		},
		Spec: routev1.RouteSpec{
			Port: &routev1.RoutePort{
				TargetPort: intstr.FromString("https"),
			},
			TLS: &routev1.TLSConfig{
				Termination:                   routev1.TLSTerminationReencrypt,
				InsecureEdgeTerminationPolicy: routev1.InsecureEdgeTerminationPolicyRedirect,
			},
			To: routev1.RouteTargetReference{
				Kind: "Service",
				Name: compactorSatefulset.Name,
			},
		},
	}

	// Set encoders and template params
	params := []templatev1.Parameter{}
	params = append(params, templatev1.Parameter{
		Name:     "OAUTH_PROXY_COOKIE_SECRET",
		Generate: "expression",
		From:     "[a-zA-Z0-9]{40}",
	})
	compactorEncoder := NewStdTemplateYAML(compactorSatefulset.Name, "COMPACTOR").WithLogLevel()
	params = append(params, compactorEncoder.TemplateParams()...)
	template := openshift.WrapInTemplate("", manifests, metav1.ObjectMeta{
		Name: compactorSatefulset.Name,
	}, sortTemplateParams(params))

	return compactorEncoder.Wrap(encoding.GhodssYAML(template[""]))
}

// makeStore creates a base store component that can be derived from using the preManifestsHook.
func (o *ObservatoriumMetrics) makeStore(instanceCfg *ObservatoriumMetricsInstance) encoding.Encoder {
	// K8s config
	storeStatefulSet := store.NewStore()
	storeStatefulSet.Name = fmt.Sprintf("%s-%s", storeStatefulSet.Name, instanceCfg.InstanceName)
	storeStatefulSet.CommonLabels[observatoriumInstanceLabel] = instanceCfg.InstanceName
	storeStatefulSet.Image = thanosImage
	storeStatefulSet.ImageTag = o.ThanosImageTag
	storeStatefulSet.Namespace = o.Namespace
	storeStatefulSet.Replicas = 1
	delete(storeStatefulSet.PodResources.Limits, corev1.ResourceCPU)
	storeStatefulSet.PodResources.Requests[corev1.ResourceCPU] = resource.MustParse("4")
	storeStatefulSet.PodResources.Requests[corev1.ResourceMemory] = resource.MustParse("20Gi")
	storeStatefulSet.PodResources.Limits[corev1.ResourceMemory] = resource.MustParse("80Gi")
	storeStatefulSet.VolumeType = "gp2"
	storeStatefulSet.VolumeSize = "50Gi"
	storeStatefulSet.Env = deleteObjStoreEnv(storeStatefulSet.Env) // delete the default objstore env vars
	storeStatefulSet.Env = append(storeStatefulSet.Env, objStoreEnvVars(instanceCfg.ObjStoreSecret)...)
	storeStatefulSet.Sidecars = []k8sutil.ContainerProvider{makeJaegerAgent("observatorium-tools")}

	// Store auto-sharding using a configMap and an initContainer
	// The configMap contains a script that will be executed by the initContainer
	// The script generates the relabeling config based on the replica ordinal and the number of replicas
	// The relabeling config is then written to a volume shared with the store container
	hasmodCMName := fmt.Sprintf("hashmod-config-template-%s", instanceCfg.InstanceName)
	storeStatefulSet.ConfigMaps[hasmodCMName] = map[string]string{
		"entrypoint.sh": storeAutoShardRelabelConfigMap,
	}
	hashmodVolumeName := "hashmod-config"
	initContainer := corev1.Container{
		Name:            "init-hashmod-file",
		Image:           "quay.io/openshift/origin-cli:4.15",
		ImagePullPolicy: corev1.PullIfNotPresent,
		Args: []string{
			"/tmp/entrypoint/entrypoint.sh",
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
		},
		VolumeMounts: []corev1.VolumeMount{
			{
				Name:      "hashmod-config-template",
				MountPath: "/tmp/entrypoint",
			},
			{
				Name:      hashmodVolumeName,
				MountPath: "/tmp/config",
			},
		},
	}

	// Store config
	storeStatefulSet.Options.LogLevel = log.LogLevelWarn
	storeStatefulSet.Options.LogFormat = log.LogFormatLogfmt
	storeStatefulSet.Options.IgnoreDeletionMarksDelay = 24 * time.Hour
	maxTimeDur := time.Duration(-22) * time.Hour
	storeStatefulSet.Options.MaxTime = &thanostime.TimeOrDurationValue{Dur: &maxTimeDur}
	hasmodConfigPath := "/etc/thanos/hashmod"
	storeStatefulSet.Options.SelectorRelabelConfigFile = fmt.Sprintf("%s/hashmod-config.yaml", hasmodConfigPath)
	storeStatefulSet.Options.TracingConfig = &trclient.TracingConfig{
		Type: trclient.Jaeger,
		Config: jaeger.Config{
			SamplerParam: 2,
			SamplerType:  jaeger.SamplerTypeRateLimiting,
			ServiceName:  "thanos-store",
		},
	}
	// storeStatefulSet.Options.StoreEnableIndexHeaderLazyReader = true // Enables parallel rolling update of store nodes.
	storeStatefulSet.Options.AddExtraOpts("--store.enable-index-header-lazy-reader")
	indexCacheName := fmt.Sprintf("observatorium-thanos-store-index-cache-memcached-%s", instanceCfg.InstanceName)
	bucketCacheName := fmt.Sprintf("observatorium-thanos-store-bucket-cache-memcached-%s", instanceCfg.InstanceName)
	storeStatefulSet.Options.IndexCacheConfig = cache.NewIndexCacheConfig(memcachedclientcfg.MemcachedClientConfig{
		Addresses: []string{
			fmt.Sprintf("dnssrv+_client._tcp.%s.%s.svc", indexCacheName, o.Namespace),
		},
		DNSProviderUpdateInterval: 10 * time.Second,
		MaxAsyncBufferSize:        2500000,
		MaxAsyncConcurrency:       1000,
		MaxGetMultiBatchSize:      100000,
		MaxGetMultiConcurrency:    1000,
		MaxIdleConnections:        2500,
		MaxItemSize:               "5MiB",
		Timeout:                   2 * time.Second,
	})
	memCache := cache.NewBucketCacheConfig(memcachedclientcfg.MemcachedClientConfig{
		Addresses: []string{
			fmt.Sprintf("dnssrv+_client._tcp.%s.%s.svc", indexCacheName, o.Namespace),
		},
		DNSProviderUpdateInterval: 10 * time.Second,
		MaxAsyncBufferSize:        2500000,
		MaxAsyncConcurrency:       1000,
		MaxGetMultiBatchSize:      100000,
		MaxGetMultiConcurrency:    1000,
		MaxIdleConnections:        2500,
		MaxItemSize:               "1MiB",
		Timeout:                   2 * time.Second,
	})
	memCache.MaxChunksGetRangeRequests = 3
	memCache.MetafileMaxSize = "1MiB"
	memCache.MetafileExistsTTL = 2 * time.Hour
	memCache.MetafileDoesntExistTTL = 15 * time.Minute
	memCache.MetafileContentTTL = 24 * time.Hour

	storeStatefulSet.Options.AddExtraOpts(fmt.Sprintf("--store.caching-bucket.config=%s", memCache.String()))

	executeIfNotNil(instanceCfg.StorePreManifestsHook, storeStatefulSet)

	// Register the store for the query component
	o.storesRegister = append(o.storesRegister, fmt.Sprintf("dnssrv+_grpc._tcp.%s.%s.svc.cluster.local", storeStatefulSet.Name, o.Namespace))

	// Post process
	manifests := storeStatefulSet.Manifests()
	postProcessServiceMonitor(k8sutil.GetObject[*monv1.ServiceMonitor](manifests, ""), storeStatefulSet.Namespace)
	addQuayPullSecret(k8sutil.GetObject[*corev1.ServiceAccount](manifests, ""))
	statefulset := k8sutil.GetObject[*appsv1.StatefulSet](manifests, "")
	defaultMode := int32(0777)
	// Add volumes and volume mounts for the initContainer
	statefulset.Spec.Template.Spec.Volumes = append(statefulset.Spec.Template.Spec.Volumes, corev1.Volume{
		Name: hashmodVolumeName,
		VolumeSource: corev1.VolumeSource{
			EmptyDir: &corev1.EmptyDirVolumeSource{},
		},
	}, corev1.Volume{
		Name: "hashmod-config-template",
		VolumeSource: corev1.VolumeSource{
			ConfigMap: &corev1.ConfigMapVolumeSource{
				LocalObjectReference: corev1.LocalObjectReference{
					Name: hasmodCMName,
				},
				DefaultMode: &defaultMode,
			},
		},
	})
	statefulset.Spec.Template.Spec.InitContainers = append(statefulset.Spec.Template.Spec.InitContainers, initContainer)
	mainContainer := &statefulset.Spec.Template.Spec.Containers[0]
	mainContainer.VolumeMounts = append(mainContainer.VolumeMounts, corev1.VolumeMount{
		Name:      hashmodVolumeName,
		MountPath: hasmodConfigPath,
	})

	// add rbac for reading the number of replicas from the statefulset in the initContainer
	labels := maps.Clone(statefulset.ObjectMeta.Labels)
	delete(labels, k8sutil.VersionLabel)
	listPodsRole := &rbacv1.Role{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Role",
			APIVersion: rbacv1.SchemeGroupVersion.String(),
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("list-pods-%s", instanceCfg.InstanceName),
			Namespace: o.Namespace,
			Labels:    labels,
		},
		Rules: []rbacv1.PolicyRule{
			{
				APIGroups: []string{"apps"},
				Resources: []string{"statefulsets"},
				Verbs:     []string{"get", "list"},
			},
		},
	}

	manifests["list-pods-rbac"] = listPodsRole

	manifests["list-pods-rbac-binding"] = &rbacv1.RoleBinding{
		TypeMeta: metav1.TypeMeta{
			Kind:       "RoleBinding",
			APIVersion: rbacv1.SchemeGroupVersion.String(),
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("list-pods-%s", instanceCfg.InstanceName),
			Namespace: o.Namespace,
			Labels:    labels,
		},
		Subjects: []rbacv1.Subject{
			{

				Kind:      "ServiceAccount",
				Name:      statefulset.Spec.Template.Spec.ServiceAccountName,
				Namespace: o.Namespace,
			},
		},
		RoleRef: rbacv1.RoleRef{
			Kind:     "Role",
			Name:     listPodsRole.Name,
			APIGroup: "rbac.authorization.k8s.io",
		},
	}

	// Add pod disruption budget
	manifests["store-pdb"] = &policyv1.PodDisruptionBudget{
		TypeMeta: metav1.TypeMeta{
			Kind:       "PodDisruptionBudget",
			APIVersion: policyv1.SchemeGroupVersion.String(),
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      storeStatefulSet.Name,
			Namespace: o.Namespace,
			Labels:    labels,
		},
		Spec: policyv1.PodDisruptionBudgetSpec{
			MaxUnavailable: &intstr.IntOrString{

				Type:   intstr.Int,
				IntVal: 1,
			},
			Selector: &metav1.LabelSelector{
				MatchLabels: labels,
			},
		},
	}

	// Add index cache
	cachePreManHook := func(memdep *memcached.MemcachedDeployment) {
		memdep.CommonLabels[observatoriumInstanceLabel] = instanceCfg.InstanceName
		memdep.CommonLabels[k8sutil.ComponentLabel] = "store-index-cache"
		executeIfNotNil(instanceCfg.IndexCachePreManifestsHook, memdep)
	}
	maps.Copy(manifests, makeMemcached(indexCacheName, o.Namespace, cachePreManHook))

	// Add bucket cache
	cachePreManHook = func(memdep *memcached.MemcachedDeployment) {
		memdep.CommonLabels[observatoriumInstanceLabel] = instanceCfg.InstanceName
		memdep.CommonLabels[k8sutil.ComponentLabel] = "store-bucket-cache"
		executeIfNotNil(instanceCfg.BucketCachePreManifestsHook, memdep)
	}
	maps.Copy(manifests, makeMemcached(bucketCacheName, o.Namespace, cachePreManHook))

	// Set encoders and template params
	params := []templatev1.Parameter{}
	storeEncoder := NewStdTemplateYAML(storeStatefulSet.Name, "STORE").WithLogLevel()
	params = append(params, storeEncoder.TemplateParams()...)
	template := openshift.WrapInTemplate("", manifests, metav1.ObjectMeta{
		Name: storeStatefulSet.Name,
	}, sortTemplateParams(params))

	return storeEncoder.Wrap(encoding.GhodssYAML(template[""]))
}
