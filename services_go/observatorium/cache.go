package observatorium

import (
	"maps"

	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/memcached"
	"github.com/observatorium/observatorium/configuration_go/k8sutil"
	monv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	policyv1 "k8s.io/api/policy/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/intstr"
)

func makeMemcached(name, namespace string, preManifestHook func(*memcached.MemcachedDeployment)) k8sutil.ObjectMap {
	// K8s config
	memcachedDeployment := memcached.NewMemcached()
	memcachedDeployment.Name = name
	memcachedDeployment.Image = "quay.io/app-sre/memcached"
	memcachedDeployment.ImageTag = "1.5"
	memcachedDeployment.Namespace = namespace
	memcachedDeployment.Replicas = 1
	delete(memcachedDeployment.ContainerResources.Limits, corev1.ResourceCPU)
	memcachedDeployment.SecurityContext = nil
	memcachedDeployment.ContainerResources.Requests[corev1.ResourceCPU] = resource.MustParse("500m")
	memcachedDeployment.ContainerResources.Requests[corev1.ResourceMemory] = resource.MustParse("2Gi")
	memcachedDeployment.ContainerResources.Limits[corev1.ResourceMemory] = resource.MustParse("3Gi")
	memcachedDeployment.ExporterImage = "quay.io/prometheus/memcached-exporter"
	memcachedDeployment.ExporterImageTag = "v0.13.0"

	// Compactor config
	memcachedDeployment.Options.MemoryLimit = 2048
	memcachedDeployment.Options.MaxItemSize = "5m"
	memcachedDeployment.Options.ConnLimit = 3072
	memcachedDeployment.Options.Verbose = true

	// Execute preManifestsHook
	executeIfNotNil(preManifestHook, memcachedDeployment)

	// Post process
	manifests := memcachedDeployment.Manifests()
	postProcessServiceMonitor(k8sutil.GetObject[*monv1.ServiceMonitor](manifests, ""), memcachedDeployment.Namespace)
	addQuayPullSecret(k8sutil.GetObject[*corev1.ServiceAccount](manifests, ""))

	// Add pod disruption budget
	labels := maps.Clone(k8sutil.GetObject[*appsv1.Deployment](manifests, "").ObjectMeta.Labels)
	delete(labels, k8sutil.VersionLabel)
	manifests["store-index-cache-pdb"] = &policyv1.PodDisruptionBudget{
		TypeMeta: metav1.TypeMeta{
			Kind:       "PodDisruptionBudget",
			APIVersion: policyv1.SchemeGroupVersion.String(),
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      memcachedDeployment.Name,
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

	return manifests
}
