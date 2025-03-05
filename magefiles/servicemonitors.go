package main

import (
	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic/encoding"
	monitoringv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

func (s Stage) ServiceMonitors() {
	gen := s.generator("servicemonitors")
	objs := createServiceMonitors(s.namespace())
	objs = append(objs, serviceMonitor(s.namespace())...)

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
						Path:   "/metrics",
						Port:   "http",
						Scheme: "http",
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

func createServiceMonitors(namespace string) []runtime.Object {
	interval30s := monitoringv1.Duration("30s")
	metricsPath := "/metrics"
	objs := []runtime.Object{
		&monitoringv1.ServiceMonitor{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "monitoring.coreos.com/v1",
				Kind:       "ServiceMonitor",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-compact-rhobs",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "thanos-compactor",
					"app.kubernetes.io/instance":   "thanos-compact-rhobs",
					"app.kubernetes.io/managed-by": "thanos-operator",
					"app.kubernetes.io/name":       "thanos-compact",
					"app.kubernetes.io/part-of":    "thanos",
					"operator.thanos.io/owner":     "rhobs",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: interval30s,
						Path:     metricsPath,
						Port:     "http",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "thanos-compactor",
						"app.kubernetes.io/instance":   "thanos-compact-rhobs",
						"app.kubernetes.io/managed-by": "thanos-operator",
						"app.kubernetes.io/name":       "thanos-compact",
						"app.kubernetes.io/part-of":    "thanos",
						"operator.thanos.io/owner":     "rhobs",
					},
				},
			},
		},
		&monitoringv1.ServiceMonitor{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "monitoring.coreos.com/v1",
				Kind:       "ServiceMonitor",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-compact-telemeter",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "thanos-compactor",
					"app.kubernetes.io/instance":   "thanos-compact-telemeter",
					"app.kubernetes.io/managed-by": "thanos-operator",
					"app.kubernetes.io/name":       "thanos-compact",
					"app.kubernetes.io/part-of":    "thanos",
					"operator.thanos.io/owner":     "telemeter",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: interval30s,
						Path:     metricsPath,
						Port:     "http",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "thanos-compactor",
						"app.kubernetes.io/instance":   "thanos-compact-telemeter",
						"app.kubernetes.io/managed-by": "thanos-operator",
						"app.kubernetes.io/name":       "thanos-compact",
						"app.kubernetes.io/part-of":    "thanos",
						"operator.thanos.io/owner":     "telemeter",
					},
				},
			},
		},
		&monitoringv1.ServiceMonitor{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "monitoring.coreos.com/v1",
				Kind:       "ServiceMonitor",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-query-rhobs",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "query-layer",
					"app.kubernetes.io/instance":   "thanos-query-rhobs",
					"app.kubernetes.io/managed-by": "thanos-operator",
					"app.kubernetes.io/name":       "thanos-query",
					"app.kubernetes.io/part-of":    "thanos",
					"operator.thanos.io/owner":     "rhobs",
					"operator.thanos.io/query-api": "true",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: interval30s,
						Path:     metricsPath,
						Port:     "http",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "query-layer",
						"app.kubernetes.io/instance":   "thanos-query-rhobs",
						"app.kubernetes.io/managed-by": "thanos-operator",
						"app.kubernetes.io/name":       "thanos-query",
						"app.kubernetes.io/part-of":    "thanos",
						"operator.thanos.io/owner":     "rhobs",
						"operator.thanos.io/query-api": "true",
					},
				},
			},
		},
		&monitoringv1.ServiceMonitor{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "monitoring.coreos.com/v1",
				Kind:       "ServiceMonitor",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-receive-ingester-rhobs-default",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "thanos-receive-ingester",
					"app.kubernetes.io/instance":   "thanos-receive-ingester-rhobs-default",
					"app.kubernetes.io/managed-by": "thanos-operator",
					"app.kubernetes.io/name":       "thanos-receive",
					"app.kubernetes.io/part-of":    "thanos",
					"operator.thanos.io/owner":     "rhobs",
					"operator.thanos.io/store-api": "true",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: interval30s,
						Path:     metricsPath,
						Port:     "http",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "thanos-receive-ingester",
						"app.kubernetes.io/instance":   "thanos-receive-ingester-rhobs-default",
						"app.kubernetes.io/managed-by": "thanos-operator",
						"app.kubernetes.io/name":       "thanos-receive",
						"app.kubernetes.io/part-of":    "thanos",
						"operator.thanos.io/owner":     "rhobs",
						"operator.thanos.io/store-api": "true",
					},
				},
			},
		},
		&monitoringv1.ServiceMonitor{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "monitoring.coreos.com/v1",
				Kind:       "ServiceMonitor",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-receive-ingester-rhobs-telemeter",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "thanos-receive-ingester",
					"app.kubernetes.io/instance":   "thanos-receive-ingester-rhobs-telemeter",
					"app.kubernetes.io/managed-by": "thanos-operator",
					"app.kubernetes.io/name":       "thanos-receive",
					"app.kubernetes.io/part-of":    "thanos",
					"operator.thanos.io/owner":     "rhobs",
					"operator.thanos.io/store-api": "true",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: interval30s,
						Path:     metricsPath,
						Port:     "http",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "thanos-receive-ingester",
						"app.kubernetes.io/instance":   "thanos-receive-ingester-rhobs-telemeter",
						"app.kubernetes.io/managed-by": "thanos-operator",
						"app.kubernetes.io/name":       "thanos-receive",
						"app.kubernetes.io/part-of":    "thanos",
						"operator.thanos.io/owner":     "rhobs",
						"operator.thanos.io/store-api": "true",
					},
				},
			},
		},
		&monitoringv1.ServiceMonitor{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "monitoring.coreos.com/v1",
				Kind:       "ServiceMonitor",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-receive-router-rhobs",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "thanos-receive-router",
					"app.kubernetes.io/instance":   "thanos-receive-router-rhobs",
					"app.kubernetes.io/managed-by": "thanos-operator",
					"app.kubernetes.io/name":       "thanos-receive",
					"app.kubernetes.io/part-of":    "thanos",
					"operator.thanos.io/owner":     "rhobs",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: interval30s,
						Path:     metricsPath,
						Port:     "http",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "thanos-receive-router",
						"app.kubernetes.io/instance":   "thanos-receive-router-rhobs",
						"app.kubernetes.io/managed-by": "thanos-operator",
						"app.kubernetes.io/name":       "thanos-receive",
						"app.kubernetes.io/part-of":    "thanos",
						"operator.thanos.io/owner":     "rhobs",
					},
				},
			},
		},
		&monitoringv1.ServiceMonitor{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "monitoring.coreos.com/v1",
				Kind:       "ServiceMonitor",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-store-default",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":       "object-storage-gateway",
					"app.kubernetes.io/instance":        "thanos-store-default",
					"app.kubernetes.io/managed-by":      "thanos-operator",
					"app.kubernetes.io/name":            "thanos-store",
					"app.kubernetes.io/part-of":         "thanos",
					"operator.thanos.io/endpoint-group": "true",
					"operator.thanos.io/owner":          "default",
					"operator.thanos.io/store-api":      "true",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: interval30s,
						Path:     metricsPath,
						Port:     "http",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "object-storage-gateway",
						"app.kubernetes.io/instance":   "thanos-store-default",
						"app.kubernetes.io/managed-by": "thanos-operator",
						"app.kubernetes.io/name":       "thanos-store",
						"app.kubernetes.io/part-of":    "thanos",
						"operator.thanos.io/owner":     "default",
						"operator.thanos.io/store-api": "true",
					},
				},
			},
		},
		&monitoringv1.ServiceMonitor{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "monitoring.coreos.com/v1",
				Kind:       "ServiceMonitor",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-store-telemeter-0to2w",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":       "object-storage-gateway",
					"app.kubernetes.io/instance":        "thanos-store-telemeter-0to2w",
					"app.kubernetes.io/managed-by":      "thanos-operator",
					"app.kubernetes.io/name":            "thanos-store",
					"app.kubernetes.io/part-of":         "thanos",
					"operator.thanos.io/endpoint-group": "true",
					"operator.thanos.io/owner":          "telemeter-0to2w",
					"operator.thanos.io/store-api":      "true",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: interval30s,
						Path:     metricsPath,
						Port:     "http",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "object-storage-gateway",
						"app.kubernetes.io/instance":   "thanos-store-telemeter-0to2w",
						"app.kubernetes.io/managed-by": "thanos-operator",
						"app.kubernetes.io/name":       "thanos-store",
						"app.kubernetes.io/part-of":    "thanos",
						"operator.thanos.io/owner":     "telemeter-0to2w",
						"operator.thanos.io/store-api": "true",
					},
				},
			},
		},
		&monitoringv1.ServiceMonitor{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "monitoring.coreos.com/v1",
				Kind:       "ServiceMonitor",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-store-telemeter-2wto90d",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":       "object-storage-gateway",
					"app.kubernetes.io/instance":        "thanos-store-telemeter-2wto90d",
					"app.kubernetes.io/managed-by":      "thanos-operator",
					"app.kubernetes.io/name":            "thanos-store",
					"app.kubernetes.io/part-of":         "thanos",
					"operator.thanos.io/endpoint-group": "true",
					"operator.thanos.io/owner":          "telemeter-2wto90d",
					"operator.thanos.io/store-api":      "true",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: interval30s,
						Path:     metricsPath,
						Port:     "http",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "object-storage-gateway",
						"app.kubernetes.io/instance":   "thanos-store-telemeter-2wto90d",
						"app.kubernetes.io/managed-by": "thanos-operator",
						"app.kubernetes.io/name":       "thanos-store",
						"app.kubernetes.io/part-of":    "thanos",
						"operator.thanos.io/owner":     "telemeter-2wto90d",
						"operator.thanos.io/store-api": "true",
					},
				},
			},
		},
		&monitoringv1.ServiceMonitor{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "monitoring.coreos.com/v1",
				Kind:       "ServiceMonitor",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-store-telemeter-90dplus",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":       "object-storage-gateway",
					"app.kubernetes.io/instance":        "thanos-store-telemeter-90dplus",
					"app.kubernetes.io/managed-by":      "thanos-operator",
					"app.kubernetes.io/name":            "thanos-store",
					"app.kubernetes.io/part-of":         "thanos",
					"operator.thanos.io/endpoint-group": "true",
					"operator.thanos.io/owner":          "telemeter-90dplus",
					"operator.thanos.io/store-api":      "true",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: interval30s,
						Path:     metricsPath,
						Port:     "http",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "object-storage-gateway",
						"app.kubernetes.io/instance":   "thanos-store-telemeter-90dplus",
						"app.kubernetes.io/managed-by": "thanos-operator",
						"app.kubernetes.io/name":       "thanos-store",
						"app.kubernetes.io/part-of":    "thanos",
						"operator.thanos.io/owner":     "telemeter-90dplus",
						"operator.thanos.io/store-api": "true",
					},
				},
			},
		},
	}
	for _, obj := range objs {
		obj.(*monitoringv1.ServiceMonitor).ObjectMeta.Labels["prometheus"] = "app-sre"
	}
	return objs
}
