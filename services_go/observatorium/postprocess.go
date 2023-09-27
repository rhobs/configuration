package observatorium

import (
	monv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

const (
	servingCertSecretNameAnnotation = "service.alpha.openshift.io/serving-cert-secret-name"
)

// updateServiceMonitorNamespace updates the namespace of all ServiceMonitor objects.
// This is useful when the ServiceMonitor must be deployed in a different namespace than observatorium.
func updateServiceMonitorNamespace(obj runtime.Object) {
	if serviceMonitor, ok := obj.(*monv1.ServiceMonitor); ok {
		serviceMonitor.ObjectMeta.Namespace = monitoringNamespace
	}
}

// addAnnotation adds an annotation to an object.
// The object is filtered by objectType and objectName.
func addAnnotation(objectType, objectName, key, value string) func(object runtime.Object) {
	return func(object runtime.Object) {
		if object.GetObjectKind().GroupVersionKind().Kind != objectType {
			return
		}

		objectMeta, ok := object.(metav1.ObjectMetaAccessor)
		if !ok {
			return
		}

		if objectMeta.GetObjectMeta().GetName() != objectName {
			return
		}

		if objectMeta.GetObjectMeta().GetAnnotations() == nil {
			objectMeta.GetObjectMeta().SetAnnotations(map[string]string{})
		}

		objectMeta.GetObjectMeta().GetAnnotations()[key] = value
	}
}

// addPodContainer adds an init container to a pod.
func addPodInitContainer(objectName string, container corev1.Container) func(object runtime.Object) {
	return func(object runtime.Object) {
		name, pod := getPodFromObject(object)
		if pod == nil {
			return
		}

		if name != objectName {
			return
		}

		pod.Spec.InitContainers = append(pod.Spec.InitContainers, container)
	}
}

// addPodContainer adds a volume to a pod whose deployment/statefulset name is objectName.
func addPodVolume(objectName string, volume corev1.Volume) func(object runtime.Object) {
	return func(object runtime.Object) {
		name, pod := getPodFromObject(object)

		if pod == nil {
			return
		}

		if name != objectName {
			return
		}

		pod.Spec.Volumes = append(pod.Spec.Volumes, volume)
	}
}

// addContainerVolumeMount adds a volume mount to the main container whose deployment/statefulset name is objectName.
// The main container is the first container in the pod.
func addContainerVolumeMount(objectName string, volumeMount corev1.VolumeMount) func(object runtime.Object) {
	return func(object runtime.Object) {
		name, pod := getPodFromObject(object)

		if pod == nil {
			return
		}

		if name != objectName {
			return
		}

		container := &pod.Spec.Containers[0]

		container.VolumeMounts = append(container.VolumeMounts, volumeMount)
	}
}

func getPodFromObject(object runtime.Object) (string, *corev1.PodTemplateSpec) {
	switch object.GetObjectKind().GroupVersionKind().Kind {
	case "Deployment":
		if deployment, ok := object.(*appsv1.Deployment); ok {
			return deployment.ObjectMeta.Name, &deployment.Spec.Template
		}
	case "StatefulSet":
		if statefulSet, ok := object.(*appsv1.StatefulSet); ok {
			return statefulSet.ObjectMeta.Name, &statefulSet.Spec.Template
		}
	}

	return "", nil
}
