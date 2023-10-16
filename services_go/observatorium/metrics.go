package observatorium

import (
	_ "embed"
	"fmt"
	"maps"
	"time"

	"github.com/bwplotka/mimic/encoding"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/compactor"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/store"
	"github.com/observatorium/observatorium/configuration_go/k8sutil"
	"github.com/observatorium/observatorium/configuration_go/openshift"
	"github.com/observatorium/observatorium/configuration_go/schemas/thanos/common"
	"github.com/observatorium/observatorium/configuration_go/schemas/thanos/objstore"
	objstore3 "github.com/observatorium/observatorium/configuration_go/schemas/thanos/objstore/s3"
	trclient "github.com/observatorium/observatorium/configuration_go/schemas/thanos/tracing/client"
	"github.com/observatorium/observatorium/configuration_go/schemas/thanos/tracing/jaeger"
	routev1 "github.com/openshift/api/route/v1"
	templatev1 "github.com/openshift/api/template/v1"
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
	monitoringNamespace             = "openshift-customer-monitoring"
	servingCertSecretNameAnnotation = "service.alpha.openshift.io/serving-cert-secret-name"
	tenantLabel                     = "observatorium/tenant"
)

//go:embed assets/store-auto-shard-relabel-configMap.sh
var storeAutoShardRelabelConfigMap string

// makeCompactor creates a base compactor component that can be derived from using the preManifestsHook.
func makeCompactor(namespace, imageTag string, cfg ThanosTenantConfig[compactor.CompactorStatefulSet]) encoding.Encoder {
	// K8s config
	compactorSatefulset := compactor.NewCompactor()
	compactorSatefulset.Name = fmt.Sprintf("%s-%s", compactorSatefulset.Name, cfg.Tenant)
	compactorSatefulset.CommonLabels[tenantLabel] = cfg.Tenant
	compactorSatefulset.Image = thanosImage
	compactorSatefulset.ImageTag = imageTag
	compactorSatefulset.Namespace = namespace
	compactorSatefulset.Affinity.PodAntiAffinity.PreferredDuringSchedulingIgnoredDuringExecution[0].PodAffinityTerm.Namespaces = []string{}
	compactorSatefulset.Replicas = 1
	compactorSatefulset.SecurityContext = corev1.PodSecurityContext{}
	delete(compactorSatefulset.PodResources.Limits, corev1.ResourceCPU)
	compactorSatefulset.PodResources.Requests[corev1.ResourceCPU] = resource.MustParse("200m")
	compactorSatefulset.PodResources.Requests[corev1.ResourceMemory] = resource.MustParse("1Gi")
	compactorSatefulset.PodResources.Limits[corev1.ResourceMemory] = resource.MustParse("5Gi")
	compactorSatefulset.VolumeType = "gp2"
	compactorSatefulset.VolumeSize = "50Gi"
	compactorSatefulset.Env = deleteObjStoreEnv(compactorSatefulset.Env) // delete the default objstore env vars
	compactorSatefulset.Env = append(compactorSatefulset.Env, objStoreEnvVars(cfg.ObjStoreSecret)...)
	tlsSecret := "compact-tls-" + cfg.Tenant
	compactorSatefulset.Sidecars = []k8sutil.ContainerProvider{makeOauthProxy(10902, namespace, compactorSatefulset.Name, tlsSecret)}

	// Compactor config
	compactorSatefulset.Options.LogLevel = common.LogLevelWarn
	compactorSatefulset.Options.RetentionResolutionRaw = 0
	compactorSatefulset.Options.RetentionResolution5m = 0
	compactorSatefulset.Options.RetentionResolution1h = 0
	compactorSatefulset.Options.DeleteDelay = 24 * time.Hour
	compactorSatefulset.Options.CompactConcurrency = 1
	compactorSatefulset.Options.DownsampleConcurrency = 1
	compactorSatefulset.Options.DeduplicationReplicaLabel = "replica"
	compactorSatefulset.Options.AddExtraOpts("--debug.max-compaction-level=3")

	// Execute preManifestsHook
	if cfg.PreManifestsHook != nil {
		cfg.PreManifestsHook(compactorSatefulset)
	}

	// Post process
	manifests := compactorSatefulset.Manifests()
	service := getObject[*corev1.Service](manifests)
	service.ObjectMeta.Annotations[servingCertSecretNameAnnotation] = tlsSecret
	postProcessServiceMonitor(getObject[*monv1.ServiceMonitor](manifests), compactorSatefulset.Namespace)

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
			Namespace: namespace,
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
			Namespace: namespace,
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
	return NewDefaultTemplateYAML(encoding.GhodssYAML(template[""]))
}

// makeStore creates a base store component that can be derived from using the preManifestsHook.
func makeStore(namespace, imageTag string, cfg ThanosTenantConfig[store.StoreStatefulSet]) encoding.Encoder {
	// K8s config
	storeStatefulSet := store.NewStore()
	storeStatefulSet.Name = fmt.Sprintf("%s-%s", storeStatefulSet.Name, cfg.Tenant)
	storeStatefulSet.CommonLabels[tenantLabel] = cfg.Tenant
	storeStatefulSet.Image = thanosImage
	storeStatefulSet.ImageTag = imageTag
	storeStatefulSet.Namespace = namespace
	storeStatefulSet.Affinity.PodAntiAffinity.PreferredDuringSchedulingIgnoredDuringExecution[0].PodAffinityTerm.Namespaces = []string{}
	storeStatefulSet.Replicas = 1
	delete(storeStatefulSet.PodResources.Limits, corev1.ResourceCPU)
	storeStatefulSet.PodResources.Requests[corev1.ResourceCPU] = resource.MustParse("4")
	storeStatefulSet.PodResources.Requests[corev1.ResourceMemory] = resource.MustParse("20Gi")
	storeStatefulSet.PodResources.Limits[corev1.ResourceMemory] = resource.MustParse("80Gi")
	storeStatefulSet.VolumeType = "gp2"
	storeStatefulSet.VolumeSize = "50Gi"
	storeStatefulSet.Env = deleteObjStoreEnv(storeStatefulSet.Env) // delete the default objstore env vars
	storeStatefulSet.Env = append(storeStatefulSet.Env, objStoreEnvVars(cfg.ObjStoreSecret)...)
	storeStatefulSet.Sidecars = []k8sutil.ContainerProvider{makeJaegerAgent("observatorium-tools")}

	// Store auto-sharding using a configMap and an initContainer
	// The configMap contains a script that will be executed by the initContainer
	// The script generates the relabeling config based on the replica ordinal and the number of replicas
	// The relabeling config is then written to a volume shared with the store container
	storeStatefulSet.ConfigMaps[fmt.Sprintf("hashmod-config-template-%s", cfg.Tenant)] = map[string]string{
		"entrypoint.sh": storeAutoShardRelabelConfigMap,
	}
	initContainer := corev1.Container{
		Name:            "init-hashmod-file",
		Image:           "quay.io/app-sre/ubi8-ubi",
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
				Name:      "hashmod-config",
				MountPath: "/etc/config",
			},
		},
	}

	// Store config
	storeStatefulSet.Options.LogLevel = common.LogLevelWarn
	storeStatefulSet.Options.LogFormat = common.LogFormatLogfmt
	storeStatefulSet.Options.IgnoreDeletionMarksDelay = 24 * time.Hour
	maxTimeDur := time.Duration(-22) * time.Hour
	storeStatefulSet.Options.MaxTime = &common.TimeOrDurationValue{Dur: &maxTimeDur}
	storeStatefulSet.Options.SelectorRelabelConfigFile = "/tmp/config/hashmod-config.yaml"
	storeStatefulSet.Options.TracingConfig = &trclient.TracingConfig{
		Type: trclient.Jaeger,
		Config: jaeger.Config{
			SamplerParam: 2,
			SamplerType:  jaeger.SamplerTypeRateLimiting,
			ServiceName:  "thanos-store",
		},
	}
	storeStatefulSet.Options.StoreEnableIndexHeaderLazyReader = true // Enables parallel rolling update of store nodes.

	// Execute preManifestHook
	if cfg.PreManifestsHook != nil {
		cfg.PreManifestsHook(storeStatefulSet)
	}

	// Post process
	manifests := storeStatefulSet.Manifests()
	postProcessServiceMonitor(getObject[*monv1.ServiceMonitor](manifests), storeStatefulSet.Namespace)
	statefulset := getObject[*appsv1.StatefulSet](manifests)
	defaultMode := int32(0777)
	// Add volumes and volume mounts for the initContainer
	statefulset.Spec.Template.Spec.Volumes = append(statefulset.Spec.Template.Spec.Volumes, corev1.Volume{
		Name: "hashmod-config",
		VolumeSource: corev1.VolumeSource{
			EmptyDir: &corev1.EmptyDirVolumeSource{},
		},
	}, corev1.Volume{
		Name: "hashmod-config-template",
		VolumeSource: corev1.VolumeSource{
			ConfigMap: &corev1.ConfigMapVolumeSource{
				LocalObjectReference: corev1.LocalObjectReference{
					Name: storeStatefulSet.CommonLabels[k8sutil.NameLabel],
				},
				DefaultMode: &defaultMode,
			},
		},
	})
	statefulset.Spec.Template.Spec.InitContainers = append(statefulset.Spec.Template.Spec.InitContainers, initContainer)
	mainContainer := &statefulset.Spec.Template.Spec.Containers[0]
	mainContainer.VolumeMounts = append(mainContainer.VolumeMounts, corev1.VolumeMount{
		Name:      "hashmod-config",
		MountPath: "/etc/config",
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
			Name:      fmt.Sprintf("list-pods-%s", cfg.Tenant),
			Namespace: namespace,
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
			Name:      fmt.Sprintf("list-pods-%s", cfg.Tenant),
			Namespace: namespace,
			Labels:    labels,
		},
		Subjects: []rbacv1.Subject{
			{

				Kind:      "ServiceAccount",
				Name:      statefulset.Spec.Template.Spec.ServiceAccountName,
				Namespace: namespace,
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
			Namespace: namespace,
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
	return NewDefaultTemplateYAML(encoding.GhodssYAML(template[""]))
}

type kubeObject interface {
	*corev1.Service | *appsv1.StatefulSet | *monv1.ServiceMonitor | *corev1.ServiceAccount
}

// getObject returns the first object of type T from the given map of kubernetes objects.
// This helper can be used for doing post processing on the objects.
func getObject[T kubeObject](manifests k8sutil.ObjectMap) T {
	for _, obj := range manifests {
		if service, ok := obj.(T); ok {
			return service
		}
	}

	panic(fmt.Sprintf("could not find object of type %T", *new(T)))
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
			Name:  "THANOS_LOG_LEVEL",
			Value: cfg.LogLevel,
		},
		{
			Name:  "THANOS_REPLICAS",
			Value: fmt.Sprintf("%d", cfg.Replicas),
		},
		{
			Name:  "THANOS_CPU_REQUEST",
			Value: cfg.CPURequest.String(),
		},
		{
			Name:  "THANOS_MEMORY_LIMIT",
			Value: cfg.MemoryLimit.String(),
		},
		{
			Name:  "THANOS_MEMORY_REQUEST",
			Value: cfg.MemoryRequest.String(),
		},
	}
}
