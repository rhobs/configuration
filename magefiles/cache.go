package main

import (
	"fmt"

	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	"github.com/philipgough/mimic/encoding"
	monitoringv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/intstr"
)

const (
	cacheTemplate               = "memcached-template.yaml"
	cacheName                   = "memcached"
	gatewayCacheName            = "api-memcached"
	defaultGatewayCacheReplicas = 1
)

// memcachedConfig holds the configuration for Memcached deployment
type memcachedConfig struct {
	Name           string
	Namespace      string
	Flags          *memcachedFlags
	Labels         map[string]string
	Replicas       int32
	MemcachedImage string
	ExporterImage  string
	ServiceAccount string
}

type memcachedFlags struct {
	// Memory limit in megabytes
	Memory int
	// Maximum simultaneous connections
	MaxConnections int
	// Item size limit in bytes
	MaxItemSize string
	// Minimum space allocated for key+value+flags
	MinItemSize string
	// Verbose level
	Verbose bool
	// Stats refresh interval
	StatsInterval string
}

func (f *memcachedFlags) ToArgs() []string {
	var args []string

	if f.Memory > 0 {
		args = append(args, fmt.Sprintf("-m %d", f.Memory))
	}

	if f.MaxConnections > 0 {
		args = append(args, fmt.Sprintf("-c %d", f.MaxConnections))
	}

	if f.StatsInterval != "" {
		args = append(args, fmt.Sprintf("-I %s", f.StatsInterval))
	}

	if f.Verbose {
		args = append(args, "-v")
	}

	if f.MaxItemSize != "" {
		args = append(args, fmt.Sprintf("-I %s", f.MaxItemSize))
	}

	if f.MinItemSize != "" {
		args = append(args, fmt.Sprintf("-n %s", f.MinItemSize))
	}

	return args
}

func (s Stage) Cache() {
	gen := s.generator(cacheName)
	gwConf := s.gatewayCache(StageMaps)

	var sms []runtime.Object

	objs := []runtime.Object{
		memcachedStatefulSet(gwConf, StageMaps),
		createServiceAccount(gwConf.ServiceAccount, gwConf.Namespace, gwConf.Labels),
		createCacheHeadlessService(gwConf),
	}

	sms = append(sms, createCacheServiceMonitor(gwConf))

	template := openshift.WrapInTemplate(objs, metav1.ObjectMeta{
		Name: cacheName,
	}, nil)
	enc := encoding.GhodssYAML(template)
	gen.Add(cacheTemplate, enc)
	gen.Generate()

	gen = s.generator(cacheName)
	template = openshift.WrapInTemplate(sms, metav1.ObjectMeta{
		Name: cacheName + "-service-monitor",
	}, nil)
	gen.Add("service-monitor-"+cacheTemplate, encoding.GhodssYAML(template))
	gen.Generate()

}

func (s Stage) gatewayCache(m TemplateMaps) *memcachedConfig {
	return &memcachedConfig{
		Flags: &memcachedFlags{
			Memory:         2048,
			MaxConnections: 3072,
			StatsInterval:  "5m",
			Verbose:        true,
		},
		Name:           gatewayCacheName,
		Namespace:      s.namespace(),
		MemcachedImage: m.Images[apiCache],
		ExporterImage:  m.Images[memcachedExporter],
		Labels: map[string]string{
			"app.kubernetes.io/component": gatewayCacheName,
			"app.kubernetes.io/instance":  "rhobs",
			"app.kubernetes.io/name":      "memcached",
			"app.kubernetes.io/part-of":   "observatorium",
			"app.kubernetes.io/version":   m.Versions[apiCache],
		},
		Replicas:       defaultGatewayCacheReplicas,
		ServiceAccount: gatewayCacheName,
	}
}

func memcachedStatefulSet(config *memcachedConfig, m TemplateMaps) *appsv1.StatefulSet {
	labels := config.Labels

	memcachedContainer := corev1.Container{
		Name:  "memcached",
		Image: config.MemcachedImage,
		Args:  config.Flags.ToArgs(),
		Ports: []corev1.ContainerPort{
			{
				Name:          "client",
				ContainerPort: 11211,
				Protocol:      corev1.ProtocolTCP,
			},
		},
		Resources:                m.ResourceRequirements[apiCache],
		TerminationMessagePolicy: corev1.TerminationMessageFallbackToLogsOnError,
		ImagePullPolicy:          corev1.PullIfNotPresent,
	}

	exporterContainer := corev1.Container{
		Name:  "exporter",
		Image: config.ExporterImage,
		Args: []string{
			"--memcached.address=localhost:11211",
			"--web.listen-address=0.0.0.0:9150",
		},
		Ports: []corev1.ContainerPort{
			{
				Name:          "metrics",
				ContainerPort: 9150,
				Protocol:      corev1.ProtocolTCP,
			},
		},
		Resources:       m.ResourceRequirements[memcachedExporter],
		ImagePullPolicy: corev1.PullIfNotPresent,
	}

	statefulSet := &appsv1.StatefulSet{
		TypeMeta: metav1.TypeMeta{
			Kind:       "StatefulSet",
			APIVersion: "apps/v1",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      config.Name,
			Namespace: config.Namespace,
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
					ServiceAccountName: config.ServiceAccount,
					Containers: []corev1.Container{
						memcachedContainer,
						exporterContainer,
					},
					SecurityContext: &corev1.PodSecurityContext{},
				},
			},
			PodManagementPolicy: appsv1.OrderedReadyPodManagement,
		},
	}
	return statefulSet
}

func createCacheHeadlessService(config *memcachedConfig) *corev1.Service {
	return &corev1.Service{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Service",
			APIVersion: "v1",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      config.Name,
			Namespace: config.Namespace,
			Labels:    config.Labels,
		},
		Spec: corev1.ServiceSpec{
			ClusterIP: "None",
			Ports: []corev1.ServicePort{
				{
					Name:       "client",
					Port:       11211,
					TargetPort: intstr.FromInt32(11211),
					Protocol:   corev1.ProtocolTCP,
				},
				{
					Name:       "metrics",
					Port:       9150,
					TargetPort: intstr.FromInt32(9150),
					Protocol:   corev1.ProtocolTCP,
				},
			},
			Selector: config.Labels,
		},
	}
}

func createCacheServiceMonitor(config *memcachedConfig) *monitoringv1.ServiceMonitor {
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
		},
	}
}
