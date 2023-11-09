package observatorium

import (
	_ "embed"
	"fmt"
	"maps"
	"time"

	"github.com/bwplotka/mimic"
	"github.com/bwplotka/mimic/encoding"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/memcached"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/compactor"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/receive"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/store"
	"github.com/observatorium/observatorium/configuration_go/k8sutil"
	"github.com/observatorium/observatorium/configuration_go/openshift"
	"github.com/observatorium/observatorium/configuration_go/schemas/thanos/cache"
	memcachedclientcfg "github.com/observatorium/observatorium/configuration_go/schemas/thanos/cache/memcached"
	"github.com/observatorium/observatorium/configuration_go/schemas/thanos/log"
	"github.com/observatorium/observatorium/configuration_go/schemas/thanos/objstore"
	objstore3 "github.com/observatorium/observatorium/configuration_go/schemas/thanos/objstore/s3"
	thanostime "github.com/observatorium/observatorium/configuration_go/schemas/thanos/time"
	trclient "github.com/observatorium/observatorium/configuration_go/schemas/thanos/tracing/client"
	"github.com/observatorium/observatorium/configuration_go/schemas/thanos/tracing/jaeger"
	routev1 "github.com/openshift/api/route/v1"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/pelletier/go-toml/query"
	monv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	"gopkg.in/yaml.v3"
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
)

//go:embed assets/store-auto-shard-relabel-configMap.sh
var storeAutoShardRelabelConfigMap string

// ObservatoriumMetrics contains the configuration common to all metrics instances in an observatorium instance
// and a list of ObservatoriumMetricsInstance configuring the individual metrics instances.
type ObservatoriumMetrics struct {
	Namespace                     string
	ThanosImageTag                string
	Instances                     []*ObservatoriumMetricsInstance
	ReceiveLimitsGlobal           receive.GlobalLimitsConfig
	ReceiveLimitsDefault          receive.DefaultLimitsConfig
	ReceiveControllerImageTag     string
	ReceiveRouterPreManifestsHook func(*receive.Router)
	QueryPreManifestsHook         func(*query.Query)
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
	QueryRulePreManifestsHook       func(*query.Query)
}

// Tenants contains the configuration for a tenant in a metrics instance.
type Tenants struct {
	Name          string
	ID            string
	ReceiveLimits *receive.WriteLimitConfig
}

// Manifests generates the manifests for the metrics instance of observatorium.
func (o ObservatoriumMetrics) Manifests(generator *mimic.Generator) {
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
	}

	generator.Add("observatorium-metrics-receive-router-template.yaml", withStatusRemove(o.makeReceiveRouter()))
}

// makeReceiveRouter creates a base receive router component that can be derived from using the preManifestsHook
// for each tenant instance of the observatorium metrics.
func (o ObservatoriumMetrics) makeReceiveRouter() encoding.Encoder {
	router := receive.NewRouter()

	// K8s config
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

	// Execute preManifestsHook
	if o.ReceiveRouterPreManifestsHook != nil {
		o.ReceiveRouterPreManifestsHook(router)
	}

	// Post process
	baseHashringCm := "thanos-receive-hashring"
	manifests := router.Manifests()
	postProcessServiceMonitor(getObject[*monv1.ServiceMonitor](manifests), router.Namespace)
	addQuayPullSecret(getObject[*corev1.ServiceAccount](manifests))

	// Add pod disruption budget
	labels := maps.Clone(getObject[*appsv1.Deployment](manifests).ObjectMeta.Labels)
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
	controller.ConfigMaps[baseHashringCm] = map[string]string{
		"hashring.json": baseHashring.String(),
	}

	// Controller config
	controller.Options.ConfigMapName = baseHashringCm
	controller.Options.ConfigMapGeneratedName = generatedHashringCm
	controller.Options.Namespace = o.Namespace
	controller.Options.FileName = "hashring.json"

	controllerManifests := controller.Manifests()
	for k, v := range controllerManifests {
		manifests[k] = v
	}

	// Wrap in template, add parameters
	defaultParams := defaultTemplateParams(defaultTemplateParamsConfig{
		LogLevel:      string(router.Options.LogLevel),
		Replicas:      router.Replicas,
		CPURequest:    router.PodResources.Requests[corev1.ResourceCPU],
		MemoryLimit:   router.PodResources.Limits[corev1.ResourceMemory],
		MemoryRequest: router.PodResources.Requests[corev1.ResourceMemory],
	})
	template := openshift.WrapInTemplate("", manifests, metav1.ObjectMeta{
		Name: router.Name,
	}, defaultParams)

	// Adding a special encoder wrapper to replace the templated values in the template with their corresponding template parameter.
	return NewDefaultTemplateYAML(encoding.GhodssYAML(template[""]), router.Name)
}

// makeReceiveIngestor creates a base receive ingestor component that can be derived from using the preManifestsHook
func (o ObservatoriumMetrics) makeTenantReceiveIngestor(instanceCfg *ObservatoriumMetricsInstance) encoding.Encoder {
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
	ingestor.Env = append(ingestor.Env, k8sutil.NewEnvFromField("POD_NAME", "metadata.name"))
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

	// Execute preManifestsHook
	if instanceCfg.ReceiveIngestorPreManifestsHook != nil {
		instanceCfg.ReceiveIngestorPreManifestsHook(ingestor)
	}

	// Post process
	manifests := ingestor.Manifests()
	postProcessServiceMonitor(getObject[*monv1.ServiceMonitor](manifests), ingestor.Namespace)
	statefulSetLabels := getObject[*appsv1.StatefulSet](manifests).ObjectMeta.Labels
	statefulSetLabels[ingestorControllerLabel] = ingestorControllerLabelValue
	statefulSetLabels[ingestorControllerLabelHashring] = instanceCfg.InstanceName
	addQuayPullSecret(getObject[*corev1.ServiceAccount](manifests))

	// Add pod disruption budget
	labels := maps.Clone(getObject[*appsv1.StatefulSet](manifests).ObjectMeta.Labels)
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

	// Wrap in template, add parameters
	defaultParams := defaultTemplateParams(defaultTemplateParamsConfig{
		LogLevel:      string(ingestor.Options.LogLevel),
		Replicas:      ingestor.Replicas,
		CPURequest:    ingestor.PodResources.Requests[corev1.ResourceCPU],
		MemoryLimit:   ingestor.PodResources.Limits[corev1.ResourceMemory],
		MemoryRequest: ingestor.PodResources.Requests[corev1.ResourceMemory],
	})
	template := openshift.WrapInTemplate("", manifests, metav1.ObjectMeta{
		Name: ingestor.Name,
	}, defaultParams)

	// Adding a special encoder wrapper to replace the templated values in the template with their corresponding template parameter.
	return NewDefaultTemplateYAML(encoding.GhodssYAML(template[""]), ingestor.Name)
}

// makeCompactor creates a base compactor component that can be derived from using the preManifestsHook.
func (o ObservatoriumMetrics) makeCompactor(instanceCfg *ObservatoriumMetricsInstance) encoding.Encoder {
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

	// Execute preManifestsHook
	if instanceCfg.CompactorPreManifestsHook != nil {
		instanceCfg.CompactorPreManifestsHook(compactorSatefulset)
	}

	// Post process
	manifests := compactorSatefulset.Manifests()
	service := getObject[*corev1.Service](manifests)
	service.ObjectMeta.Annotations[servingCertSecretNameAnnotation] = tlsSecret
	postProcessServiceMonitor(getObject[*monv1.ServiceMonitor](manifests), compactorSatefulset.Namespace)
	// Add annotations for openshift oauth so that the route to access the compactor ui works
	serviceAccount := getObject[*corev1.ServiceAccount](manifests)
	if serviceAccount.Annotations == nil {
		serviceAccount.Annotations = map[string]string{}
	}
	serviceAccount.Annotations["serviceaccounts.openshift.io/oauth-redirectreference.application"] = fmt.Sprintf(`{"kind":"OAuthRedirectReference","apiVersion":"v1","reference":{"kind":"Route","name":"%s"}}`, compactorSatefulset.Name)

	// Add pod disruption budget
	labels := maps.Clone(getObject[*appsv1.StatefulSet](manifests).ObjectMeta.Labels)
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

	// Wrap in template, add parameters
	defaultParams := defaultTemplateParams(defaultTemplateParamsConfig{
		LogLevel:      string(compactorSatefulset.Options.LogLevel),
		Replicas:      compactorSatefulset.Replicas,
		CPURequest:    compactorSatefulset.PodResources.Requests[corev1.ResourceCPU],
		MemoryLimit:   compactorSatefulset.PodResources.Limits[corev1.ResourceMemory],
		MemoryRequest: compactorSatefulset.PodResources.Requests[corev1.ResourceMemory],
	})
	template := openshift.WrapInTemplate("", manifests, metav1.ObjectMeta{
		Name: compactorSatefulset.Name,
	}, append(defaultParams, []templatev1.Parameter{
		{
			Name:     "OAUTH_PROXY_COOKIE_SECRET",
			Generate: "expression",
			From:     "[a-zA-Z0-9]{40}",
		},
	}...))

	// Adding a special encoder wrapper to replace the templated values in the template with their corresponding template parameter.
	return NewDefaultTemplateYAML(encoding.GhodssYAML(template[""]), compactorSatefulset.Name)
}

// makeStore creates a base store component that can be derived from using the preManifestsHook.
func (o ObservatoriumMetrics) makeStore(instanceCfg *ObservatoriumMetricsInstance) encoding.Encoder {
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

	// Execute preManifestHook
	if instanceCfg.StorePreManifestsHook != nil {
		instanceCfg.StorePreManifestsHook(storeStatefulSet)
	}

	// Post process
	manifests := storeStatefulSet.Manifests()
	postProcessServiceMonitor(getObject[*monv1.ServiceMonitor](manifests), storeStatefulSet.Namespace)
	addQuayPullSecret(getObject[*corev1.ServiceAccount](manifests))
	statefulset := getObject[*appsv1.StatefulSet](manifests)
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
	for k, v := range o.makeStoreCache(indexCacheName, "store-index-cache", instanceCfg.InstanceName, instanceCfg.IndexCachePreManifestsHook) {
		manifests["index-cache-"+k] = v
	}

	// Add bucket cache
	for k, v := range o.makeStoreCache(bucketCacheName, "store-bucket-cache", instanceCfg.InstanceName, instanceCfg.BucketCachePreManifestsHook) {
		manifests["bucket-cache-"+k] = v
	}

	// Wrap in template
	template := openshift.WrapInTemplate("", manifests, metav1.ObjectMeta{
		Name: storeStatefulSet.Name,
	}, defaultTemplateParams(defaultTemplateParamsConfig{
		LogLevel:      string(storeStatefulSet.Options.LogLevel),
		Replicas:      storeStatefulSet.Replicas,
		CPURequest:    storeStatefulSet.PodResources.Requests[corev1.ResourceCPU],
		MemoryLimit:   storeStatefulSet.PodResources.Limits[corev1.ResourceMemory],
		MemoryRequest: storeStatefulSet.PodResources.Requests[corev1.ResourceMemory],
	}))

	// Adding a special encoder wrapper to replace the templated values in the template with their corresponding template parameter.
	return NewDefaultTemplateYAML(encoding.GhodssYAML(template[""]), storeStatefulSet.Name)
}

func (o ObservatoriumMetrics) makeStoreCache(name, component, instanceName string, preManifestHook func(*memcached.MemcachedDeployment)) k8sutil.ObjectMap {
	// K8s config
	memcachedDeployment := memcached.NewMemcachedStatefulSet()
	memcachedDeployment.Name = name
	memcachedDeployment.CommonLabels[observatoriumInstanceLabel] = instanceName
	memcachedDeployment.CommonLabels[k8sutil.ComponentLabel] = component
	memcachedDeployment.Image = "quay.io/app-sre/memcached"
	memcachedDeployment.ImageTag = "1.5"
	memcachedDeployment.Namespace = o.Namespace
	memcachedDeployment.Replicas = 1
	delete(memcachedDeployment.PodResources.Limits, corev1.ResourceCPU)
	memcachedDeployment.SecurityContext = nil
	memcachedDeployment.PodResources.Requests[corev1.ResourceCPU] = resource.MustParse("500m")
	memcachedDeployment.PodResources.Requests[corev1.ResourceMemory] = resource.MustParse("2Gi")
	memcachedDeployment.PodResources.Limits[corev1.ResourceMemory] = resource.MustParse("3Gi")
	memcachedDeployment.ExporterImage = "quay.io/prometheus/memcached-exporter"
	memcachedDeployment.ExporterImageTag = "v0.13.0"

	// Compactor config
	memcachedDeployment.Options.MemoryLimit = 2048
	memcachedDeployment.Options.MaxItemSize = "5m"
	memcachedDeployment.Options.ConnLimit = 3072
	memcachedDeployment.Options.Verbose = true

	// Execute preManifestsHook
	if preManifestHook != nil {
		preManifestHook(memcachedDeployment)
	}

	// Post process
	manifests := memcachedDeployment.Manifests()
	postProcessServiceMonitor(getObject[*monv1.ServiceMonitor](manifests), memcachedDeployment.Namespace)
	addQuayPullSecret(getObject[*corev1.ServiceAccount](manifests))

	// Add pod disruption budget
	labels := maps.Clone(getObject[*appsv1.Deployment](manifests).ObjectMeta.Labels)
	delete(labels, k8sutil.VersionLabel)
	manifests["store-index-cache-pdb"] = &policyv1.PodDisruptionBudget{
		TypeMeta: metav1.TypeMeta{
			Kind:       "PodDisruptionBudget",
			APIVersion: policyv1.SchemeGroupVersion.String(),
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      memcachedDeployment.Name,
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

	return manifests
}

type kubeObject interface {
	*corev1.Service | *appsv1.StatefulSet | *appsv1.Deployment | *monv1.ServiceMonitor | *corev1.ServiceAccount
}

// getObject returns the first object of type T from the given map of kubernetes objects.
// This helper can be used for doing post processing on the objects.
func getObject[T kubeObject](manifests k8sutil.ObjectMap) T {
	var ret T
	for _, obj := range manifests {
		if service, ok := obj.(T); ok {
			if ret != nil {
				panic(fmt.Sprintf("found multiple objects of type %T", *new(T)))
			}
			ret = service
		}
	}

	if ret == nil {
		panic(fmt.Sprintf("could not find object of type %T", *new(T)))
	}

	return ret
}

// postProcessServiceMonitor updates the service monitor to work with the app-sre prometheus.
func postProcessServiceMonitor(serviceMonitor *monv1.ServiceMonitor, namespaceSelector string) {
	serviceMonitor.ObjectMeta.Namespace = monitoringNamespace
	serviceMonitor.Spec.NamespaceSelector.MatchNames = []string{namespaceSelector}
	serviceMonitor.ObjectMeta.Labels["prometheus"] = "app-sre"
}

// deleteObjStoreEnv deletes the objstore env var from the list of env vars.
// This env var is included by default by the observatorium config for each thanos component.
func deleteObjStoreEnv(objStoreEnv []corev1.EnvVar) []corev1.EnvVar {
	for i, env := range objStoreEnv {
		if env.Name == "OBJSTORE_CONFIG" {
			return append(objStoreEnv[:i], objStoreEnv[i+1:]...)
		}
	}

	return objStoreEnv
}

// objStoreEnvVars returns the env vars required for the objstore config.
// Base env vars are taken from the s3 secret generated by app-interface.
// The objstore config env var is generated by aggregating the other env vars.
func objStoreEnvVars(objstoreSecret string) []corev1.EnvVar {
	objStoreCfg, err := yaml.Marshal(objstore.BucketConfig{
		Type: objstore.S3,
		Config: objstore3.Config{
			Bucket:   "$(OBJ_STORE_BUCKET)",
			Endpoint: "$(OBJ_STORE_ENDPOINT)",
			Region:   "$(OBJ_STORE_REGION)",
		},
	})
	if err != nil {
		panic(err)
	}

	return []corev1.EnvVar{
		k8sutil.NewEnvFromSecret("AWS_ACCESS_KEY_ID", objstoreSecret, "aws_access_key_id"),
		k8sutil.NewEnvFromSecret("AWS_SECRET_ACCESS_KEY", objstoreSecret, "aws_secret_access_key"),
		k8sutil.NewEnvFromSecret("OBJ_STORE_BUCKET", objstoreSecret, "bucket"),
		k8sutil.NewEnvFromSecret("OBJ_STORE_REGION", objstoreSecret, "aws_region"),
		k8sutil.NewEnvFromSecret("OBJ_STORE_ENDPOINT", objstoreSecret, "endpoint"),
		{
			Name:  "OBJSTORE_CONFIG",
			Value: string(objStoreCfg),
		},
	}
}

type defaultTemplateParamsConfig struct {
	LogLevel      string
	Replicas      int32
	CPURequest    resource.Quantity
	MemoryLimit   resource.Quantity
	MemoryRequest resource.Quantity
}

// defaultTemplateParams returns the default template parameters for the thanos components.
func defaultTemplateParams(cfg defaultTemplateParamsConfig) []templatev1.Parameter {
	return []templatev1.Parameter{
		{
			Name:  "LOG_LEVEL",
			Value: cfg.LogLevel,
		},
		{
			Name:  "REPLICAS",
			Value: fmt.Sprintf("%d", cfg.Replicas),
		},
		{
			Name:  "CPU_REQUEST",
			Value: cfg.CPURequest.String(),
		},
		{
			Name:  "MEMORY_LIMIT",
			Value: cfg.MemoryLimit.String(),
		},
		{
			Name:  "MEMORY_REQUEST",
			Value: cfg.MemoryRequest.String(),
		},
	}
}

func addQuayPullSecret(sa *corev1.ServiceAccount) {
	sa.ImagePullSecrets = append(sa.ImagePullSecrets, corev1.LocalObjectReference{
		Name: "quay.io",
	})
}
