package main

import (
	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic/encoding"
	monitoringv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/utils/ptr"
)

func (s Stage) ServiceMonitors() {
	gen := s.generator("servicemonitors")

	objs := serviceMonitor(s.namespace())

	template := openshift.WrapInTemplate(objs, metav1.ObjectMeta{Name: "thanos-operator-servicemonitors"}, []templatev1.Parameter{})
	encoder := encoding.GhodssYAML(template)
	gen.Add("servicemonitors.yaml", encoder)
	gen.Generate()
}

func (l Local) ServiceMonitors() {
	gen := l.generator("servicemonitors")

	objs := serviceMonitor(l.namespace())

	encoder := encoding.GhodssYAML(objs[0])
	gen.Add("servicemonitors.yaml", encoder)
	gen.Generate()
}

func serviceMonitor(namespace string) []runtime.Object {
	return []runtime.Object{
		&monitoringv1.ServiceMonitor{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "monitoring.coreos.com/v1",
				Kind:       "ServiceMonitor",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-operator-controller-manager-metrics",
				Namespace: "openshift-customer-monitoring",
				Labels: map[string]string{
					"app.kubernetes.io/component":  "monitoring",
					"app.kubernetes.io/created-by": "thanos-operator",
					"app.kubernetes.io/instance":   "controller-manager-metrics",
					"app.kubernetes.io/managed-by": "rhobs",
					"app.kubernetes.io/name":       "servicemonitor",
					"app.kubernetes.io/part-of":    "thanos-operator",
					"prometheus":                   "app-sre",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						BearerTokenFile: "/var/run/secrets/kubernetes.io/serviceaccount/token",
						Path:            "/metrics",
						Port:            "https",
						Scheme:          "https",
						TLSConfig: &monitoringv1.TLSConfig{
							SafeTLSConfig: monitoringv1.SafeTLSConfig{
								InsecureSkipVerify: ptr.To(true),
							},
						},
					},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"control-plane": "controller-manager",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{
						namespace,
					},
				},
			},
		},
	}
}
