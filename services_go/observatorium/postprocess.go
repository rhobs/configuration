package observatorium

import (
	"github.com/observatorium/observatorium/configuration_go/k8sutil"
	monv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

func updateServiceMonitorNamespace(obj runtime.Object) {
	if serviceMonitor, ok := obj.(*monv1.ServiceMonitor); ok {
		serviceMonitor.ObjectMeta.Namespace = monitoringNamespace
	}
}

func addServiceCertAnnotation(nameLabelSelector, secretName string) func(object runtime.Object) {
	return func(object runtime.Object) {
		if service, ok := object.(*corev1.Service); ok {
			if service.ObjectMeta.Labels == nil {
				return
			}

			if service.ObjectMeta.Labels[k8sutil.NameLabel] != nameLabelSelector {
				return
			}

			if service.ObjectMeta.Annotations == nil {
				service.ObjectMeta.Annotations = map[string]string{}
			}

			service.ObjectMeta.Annotations["service.beta.openshift.io/serving-cert-secret-name"] = secretName
		}
	}
}
