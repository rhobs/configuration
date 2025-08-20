package main

import (
	"github.com/rhobs/configuration/clusters"

	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic"
	"github.com/philipgough/mimic/encoding"
	monitoringv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/intstr"
)

const (
	syntheticsApiTemplate = "synthetics-api-template.yaml"
	syntheticsApiName     = "synthetics-api"

	syntheticsApiPort = 11211

	defaultGatewaySyntheticsApiReplicas = 1
)

// syntheticsApiConfig holds the configuration for synthetics API deployment
type syntheticsApiConfig struct {
	Name               string
	Namespace          string
	Flags              *syntheticsApiFlags
	Labels             map[string]string
	Replicas           int32
	SyntheticsApiImage string
}

type syntheticsApiFlags struct {
	// TODO: Define any additonal command line flags
}

func (f *syntheticsApiFlags) ToArgs() []string {
	var args []string
	return args
}

// SyntheticsApi creates the syntheticsApi resources for the stage environment
func (s Stage) SyntheticsApi() {
	gen := func() *mimic.Generator {
		return s.generator(syntheticsApiName)
	}
	syntheticsApis := []*syntheticsApiConfig{
		newSyntheticsApiConfig(clusters.StageMaps, s.namespace()),
	}
	syntheticsApi(gen, clusters.StageMaps, syntheticsApis)
}

// SyntheticsApi creates the syntheticsApi resources for the production environment
func (p Production) SyntheticsApi() {
	gen := func() *mimic.Generator {
		return p.generator(syntheticsApiName)
	}
	syntheticsApis := []*syntheticsApiConfig{
		newSyntheticsApiConfig(clusters.ProductionMaps, p.namespace()),
	}
	syntheticsApi(gen, clusters.ProductionMaps, syntheticsApis)
}

func syntheticsApi(g func() *mimic.Generator, m clusters.TemplateMaps, confs []*syntheticsApiConfig) {
	var sms []runtime.Object
	var objs []runtime.Object

	for _, c := range confs {
		objs = append(objs, syntheticsApiStatefulSet(c, m))
		objs = append(objs, createSyntheticsApiServiceAccount(c))
		objs = append(objs, createSyntheticsApiHeadlessService(c))
		sms = append(sms, createSyntheticsApiServiceMonitor(c))
	}

	// Set template params
	params := []templatev1.Parameter{}
	params = append(params, templatev1.Parameter{
		Name:  "NAMESPACE",
		Value: "rhobs",
	}, templatev1.Parameter{
		Name:  "IMAGE_TAG",
		Value: "cea7d4656cd0ad338e580cc6ba266264a9938e5c",
	}, templatev1.Parameter{
		Name:  "IMAGE_DIGEST",
		Value: "",
	})

	template := openshift.WrapInTemplate(objs, metav1.ObjectMeta{
		Name: syntheticsApiName,
	}, sortTemplateParams(params))
	enc := encoding.GhodssYAML(template)
	gen := g()
	gen.Add(syntheticsApiTemplate, enc)
	gen.Generate()

	template = openshift.WrapInTemplate(sms, metav1.ObjectMeta{
		Name: syntheticsApiName + "-service-monitor",
	}, nil)
	gen = g()
	gen.Add("service-monitor-"+syntheticsApiTemplate, encoding.GhodssYAML(template))
	gen.Generate()
}

func newSyntheticsApiConfig(m clusters.TemplateMaps, namespace string) *syntheticsApiConfig {
	return &syntheticsApiConfig{
		Flags:              &syntheticsApiFlags{},
		Name:               syntheticsApiName,
		Namespace:          namespace,
		SyntheticsApiImage: m.Images[syntheticsAPI],
		Labels: map[string]string{
			"app.kubernetes.io/component": syntheticsApiName,
			"app.kubernetes.io/instance":  "rhobs",
			"app.kubernetes.io/name":      syntheticsApiName,
			"app.kubernetes.io/part-of":   "rhobs",
			"app.kubernetes.io/version":   m.Versions[syntheticsAPI],
		},
		Replicas: defaultGatewaySyntheticsApiReplicas,
	}
}

func syntheticsApiStatefulSet(config *syntheticsApiConfig, m clusters.TemplateMaps) *appsv1.StatefulSet {
	labels := config.Labels

	syntheticsApiContainer := corev1.Container{
		Name:  syntheticsApiName,
		Image: "quay.io/redhat-services-prod/openshift/rhobs-synthetics-api:${IMAGE_TAG}",
		Args:  config.Flags.ToArgs(),
		Ports: []corev1.ContainerPort{
			{
				Name:          syntheticsApiName,
				ContainerPort: syntheticsApiPort,
				Protocol:      corev1.ProtocolTCP,
			},
		},
		Resources:                m.ResourceRequirements[syntheticsAPI],
		TerminationMessagePolicy: corev1.TerminationMessageFallbackToLogsOnError,
		ImagePullPolicy:          corev1.PullIfNotPresent,
	}

	statefulSet := &appsv1.StatefulSet{
		TypeMeta: metav1.TypeMeta{
			Kind:       "StatefulSet",
			APIVersion: "apps/v1",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      config.Name,
			Namespace: "${NAMESPACE}",
			Labels:    labels,
		},
		Spec: appsv1.StatefulSetSpec{
			Replicas: &config.Replicas,
			Selector: &metav1.LabelSelector{
				MatchLabels: labels,
			},
			ServiceName: config.Name,
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: labels,
				},
				Spec: corev1.PodSpec{
					ServiceAccountName: config.Name,
					Containers: []corev1.Container{
						syntheticsApiContainer,
					},
					SecurityContext: &corev1.PodSecurityContext{},
				},
			},
			PodManagementPolicy: appsv1.OrderedReadyPodManagement,
		},
	}
	return statefulSet
}

func createSyntheticsApiServiceAccount(config *syntheticsApiConfig) *corev1.ServiceAccount {
	return &corev1.ServiceAccount{
		TypeMeta: metav1.TypeMeta{
			Kind:       "ServiceAccount",
			APIVersion: "v1",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      config.Name,
			Namespace: "${NAMESPACE}",
			Labels:    config.Labels,
		},
	}
}

func createSyntheticsApiHeadlessService(config *syntheticsApiConfig) *corev1.Service {
	return &corev1.Service{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Service",
			APIVersion: "v1",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      config.Name,
			Namespace: "${NAMESPACE}",
			Labels:    config.Labels,
		},
		Spec: corev1.ServiceSpec{
			ClusterIP: "None",
			Ports: []corev1.ServicePort{
				{
					Name:       syntheticsApiName,
					Port:       syntheticsApiPort,
					TargetPort: intstr.FromInt32(syntheticsApiPort),
					Protocol:   corev1.ProtocolTCP,
				},
			},
			Selector: config.Labels,
		},
	}
}

func createSyntheticsApiServiceMonitor(config *syntheticsApiConfig) *monitoringv1.ServiceMonitor {
	labels := deepCopyMap(config.Labels)
	labels[openshiftCustomerMonitoringLabel] = openShiftClusterMonitoringLabelValue

	return &monitoringv1.ServiceMonitor{
		TypeMeta: metav1.TypeMeta{
			Kind:       "ServiceMonitor",
			APIVersion: "monitoring.coreos.com/v1",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      config.Name,
			Namespace: openshiftCustomerMonitoringNamespace,
			Labels:    labels,
		},
		Spec: monitoringv1.ServiceMonitorSpec{
			Endpoints: []monitoringv1.Endpoint{
				{
					Port:        "metrics",
					Path:        "/metrics",
					Interval:    monitoringv1.Duration("30s"),
					HonorLabels: true,
				},
			},
			Selector: metav1.LabelSelector{
				MatchLabels: config.Labels,
			},
			NamespaceSelector: monitoringv1.NamespaceSelector{
				MatchNames: []string{"${NAMESPACE}"},
			},
		},
	}
}

func (b Build) SyntheticsApi(config clusters.ClusterConfig) {
	ns := config.Namespace
	gen := func() *mimic.Generator {
		return b.generator(config, syntheticsApiName)
	}
	syntheticsApis := []*syntheticsApiConfig{
		newSyntheticsApiConfig(clusters.ProductionMaps, ns),
	}
	syntheticsApi(gen, clusters.ProductionMaps, syntheticsApis)
}

// generateUnifiedSyntheticsApi generates a single, environment-agnostic template
func generateUnifiedSyntheticsApi() {
	var u Unified
	gen := func() *mimic.Generator {
		return u.generator(syntheticsApiName)
	}

	// Create a single config without environment-specific values
	config := &syntheticsApiConfig{
		Flags:              &syntheticsApiFlags{},
		Name:               syntheticsApiName,
		Namespace:          "", // Will be parameterized
		SyntheticsApiImage: "", // Not used since we use template parameter
		Labels: map[string]string{
			"app.kubernetes.io/component": syntheticsApiName,
			"app.kubernetes.io/instance":  "rhobs",
			"app.kubernetes.io/name":      syntheticsApiName,
			"app.kubernetes.io/part-of":   "rhobs",
			"app.kubernetes.io/version":   "${IMAGE_TAG}",
		},
		Replicas: defaultGatewaySyntheticsApiReplicas,
	}

	syntheticsApi(gen, clusters.TemplateMaps{}, []*syntheticsApiConfig{config})
}
