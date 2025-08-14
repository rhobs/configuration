package main

import (
	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic"
	"github.com/philipgough/mimic/encoding"
	monitoringv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	"github.com/rhobs/configuration/clusters"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/utils/ptr"
)

func (b Build) ServiceMonitors(config clusters.ClusterConfig) {
	gen := b.generator(config, "servicemonitors")
	objs := createThanosServiceMonitors(config.Namespace)
	objs = append(objs, thanosOperatorServiceMonitor(config.Namespace)...)
	objs = append(objs, createLokiServiceMonitors(config.Namespace)...)
	objs = append(objs, lokiOperatorServiceMonitor(config.Namespace)...)
	generateServiceMonitors(gen, objs)
}

func generateServiceMonitors(gen *mimic.Generator, objs []runtime.Object) {
	template := openshift.WrapInTemplate(objs, metav1.ObjectMeta{Name: "servicemonitors"}, []templatev1.Parameter{})
	encoder := encoding.GhodssYAML(template)
	gen.Add("servicemonitors.yaml", encoder)
	gen.Generate()
}

// ServiceMonitors generates ServiceMonitor resources for the Stage environment.
func (s Stage) ServiceMonitors() {
	objs := createThanosServiceMonitors(s.namespace())
	objs = append(objs, thanosOperatorServiceMonitor(s.namespace())...)
	serviceMonitorTemplateGen(s.generator("servicemonitors"), objs)
}

// ServiceMonitors generates ServiceMonitor resources for the Production environment.
func (p Production) ServiceMonitors() {
	ns := p.namespace()
	objs := createThanosServiceMonitors(ns)
	objs = append(objs, thanosOperatorServiceMonitor(ns)...)
	serviceMonitorTemplateGen(p.generator("servicemonitors"), objs)
}

func serviceMonitorTemplateGen(gen *mimic.Generator, objs []runtime.Object) {
	template := openshift.WrapInTemplate(objs, metav1.ObjectMeta{Name: "thanos-operator-servicemonitors"}, []templatev1.Parameter{})
	encoder := encoding.GhodssYAML(template)
	gen.Add("servicemonitors.yaml", encoder)
	gen.Generate()
}

func (l Local) ServiceMonitors() {
	gen := l.generator("servicemonitors")

	objs := thanosOperatorServiceMonitor(l.namespace())

	encoder := encoding.GhodssYAML(objs[0])
	gen.Add("servicemonitors.yaml", encoder)
	gen.Generate()
}

func thanosOperatorServiceMonitor(namespace string) []runtime.Object {
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

func createThanosServiceMonitors(namespace string) []runtime.Object {
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
				Name:      "thanos-query-frontend-rhobs",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "query-frontend",
					"app.kubernetes.io/instance":   "thanos-query-frontend-rhobs",
					"app.kubernetes.io/managed-by": "thanos-operator",
					"app.kubernetes.io/name":       "thanos-query-frontend",
					"app.kubernetes.io/part-of":    "thanos",
					"operator.thanos.io/owner":     "rhobs",
					"operator.thanos.io/query-api": "true",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: "30s",
						Path:     "/metrics",
						Port:     "http",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "query-frontend",
						"app.kubernetes.io/instance":   "thanos-query-frontend-rhobs",
						"app.kubernetes.io/managed-by": "thanos-operator",
						"app.kubernetes.io/name":       "thanos-query-frontend",
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

func lokiOperatorServiceMonitor(namespace string) []runtime.Object {
	return []runtime.Object{
		&monitoringv1.ServiceMonitor{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "monitoring.coreos.com/v1",
				Kind:       "ServiceMonitor",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "loki-operator-controller-manager-metrics",
				Namespace: "openshift-customer-monitoring",
				Labels: map[string]string{
					"app.kubernetes.io/component":  "monitoring",
					"app.kubernetes.io/created-by": "loki-operator",
					"app.kubernetes.io/instance":   "controller-manager-metrics",
					"app.kubernetes.io/managed-by": "rhobs",
					"app.kubernetes.io/name":       "servicemonitor",
					"app.kubernetes.io/part-of":    "loki-operator",
					"prometheus":                   "app-sre",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Path: "/metrics",
						Port: "metrics",
					},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component": "metrics",
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

func createLokiServiceMonitors(namespace string) []runtime.Object {
	interval30s := monitoringv1.Duration("30s")
	metricsPath := "/metrics"
	objs := []runtime.Object{
		&monitoringv1.ServiceMonitor{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "monitoring.coreos.com/v1",
				Kind:       "ServiceMonitor",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "loki-compactor-http",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "compactor",
					"app.kubernetes.io/created-by": "lokistack-controller",
					"app.kubernetes.io/instance":   "observatorium-lokistack",
					"app.kubernetes.io/managed-by": "lokistack-controller",
					"app.kubernetes.io/name":       "lokistack",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: interval30s,
						Path:     metricsPath,
						Port:     "metrics",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "compactor",
						"app.kubernetes.io/created-by": "lokistack-controller",
						"app.kubernetes.io/instance":   "observatorium-lokistack",
						"app.kubernetes.io/managed-by": "lokistack-controller",
						"app.kubernetes.io/name":       "lokistack",
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
				Name:      "loki-distributor-http",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "distributor",
					"app.kubernetes.io/created-by": "lokistack-controller",
					"app.kubernetes.io/instance":   "observatorium-lokistack",
					"app.kubernetes.io/managed-by": "lokistack-controller",
					"app.kubernetes.io/name":       "lokistack",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: interval30s,
						Path:     metricsPath,
						Port:     "metrics",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "distributor",
						"app.kubernetes.io/created-by": "lokistack-controller",
						"app.kubernetes.io/instance":   "observatorium-lokistack",
						"app.kubernetes.io/managed-by": "lokistack-controller",
						"app.kubernetes.io/name":       "lokistack",
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
				Name:      "loki-index-gateway-http",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "index-gateway",
					"app.kubernetes.io/created-by": "lokistack-controller",
					"app.kubernetes.io/instance":   "observatorium-lokistack",
					"app.kubernetes.io/managed-by": "lokistack-controller",
					"app.kubernetes.io/name":       "lokistack",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: interval30s,
						Path:     metricsPath,
						Port:     "metrics",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "index-gateway",
						"app.kubernetes.io/created-by": "lokistack-controller",
						"app.kubernetes.io/instance":   "observatorium-lokistack",
						"app.kubernetes.io/managed-by": "lokistack-controller",
						"app.kubernetes.io/name":       "lokistack",
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
				Name:      "loki-ingester-http",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "ingester",
					"app.kubernetes.io/created-by": "lokistack-controller",
					"app.kubernetes.io/instance":   "observatorium-lokistack",
					"app.kubernetes.io/managed-by": "lokistack-controller",
					"app.kubernetes.io/name":       "lokistack",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: interval30s,
						Path:     metricsPath,
						Port:     "metrics",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "ingester",
						"app.kubernetes.io/created-by": "lokistack-controller",
						"app.kubernetes.io/instance":   "observatorium-lokistack",
						"app.kubernetes.io/managed-by": "lokistack-controller",
						"app.kubernetes.io/name":       "lokistack",
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
				Name:      "loki-querier-http",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "querier",
					"app.kubernetes.io/created-by": "lokistack-controller",
					"app.kubernetes.io/instance":   "observatorium-lokistack",
					"app.kubernetes.io/managed-by": "lokistack-controller",
					"app.kubernetes.io/name":       "lokistack",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: interval30s,
						Path:     metricsPath,
						Port:     "metrics",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "querier",
						"app.kubernetes.io/created-by": "lokistack-controller",
						"app.kubernetes.io/instance":   "observatorium-lokistack",
						"app.kubernetes.io/managed-by": "lokistack-controller",
						"app.kubernetes.io/name":       "lokistack",
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
				Name:      "loki-query-frontend-http",
				Namespace: openshiftCustomerMonitoringNamespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "query-frontend",
					"app.kubernetes.io/created-by": "lokistack-controller",
					"app.kubernetes.io/instance":   "observatorium-lokistack",
					"app.kubernetes.io/managed-by": "lokistack-controller",
					"app.kubernetes.io/name":       "lokistack",
				},
			},
			Spec: monitoringv1.ServiceMonitorSpec{
				Endpoints: []monitoringv1.Endpoint{
					{
						Interval: interval30s,
						Path:     metricsPath,
						Port:     "metrics",
					},
				},
				NamespaceSelector: monitoringv1.NamespaceSelector{
					MatchNames: []string{namespace},
				},
				Selector: metav1.LabelSelector{
					MatchLabels: map[string]string{
						"app.kubernetes.io/component":  "query-frontend",
						"app.kubernetes.io/created-by": "lokistack-controller",
						"app.kubernetes.io/instance":   "observatorium-lokistack",
						"app.kubernetes.io/managed-by": "lokistack-controller",
						"app.kubernetes.io/name":       "lokistack",
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
