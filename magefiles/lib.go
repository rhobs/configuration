package main

import (
	"fmt"
	"sort"

	"github.com/bwplotka/mimic/encoding"
	kghelpers "github.com/observatorium/observatorium/configuration_go/kubegen/helpers"
	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	"github.com/observatorium/observatorium/configuration_go/kubegen/workload"
	templatev1 "github.com/openshift/api/template/v1"
	monv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

const (
	servingCertSecretNameAnnotation = "service.alpha.openshift.io/serving-cert-secret-name"
	serviceRedirectAnnotation       = "serviceaccounts.openshift.io/oauth-redirectreference.application"

	serviceMonitorTemplate = "service-monitor-template.yaml"
)

type resourceRequirements struct {
	cpuRequest    string
	cpuLimit      string
	memoryRequest string
	memoryLimit   string
}

type manifestOptions struct {
	namespace string
	image     string
	imageTag  string
	resourceRequirements
}

// makeOauthProxy creates a container for the oauth-proxy sidecar.
// It contains a template parameter OAUTH_PROXY_COOKIE_SECRET that must be added to the template parameters.
func makeOauthProxy(upstreamPort int32, namespace, serviceAccount, tlsSecret string) *workload.Container {
	const (
		name     = "oauth-proxy"
		image    = "registry.redhat.io/openshift4/ose-oauth-proxy"
		imageTag = "v4.14"
	)

	const (
		cpuRequest    = "100m"
		cpuLimit      = ""
		memoryRequest = "100Mi"
		memoryLimit   = ""
	)

	proxyPort := int32(8443)

	return &workload.Container{
		Name:     name,
		Image:    image,
		ImageTag: imageTag,
		Args: []string{
			"-provider=openshift",
			fmt.Sprintf("-https-address=:%d", proxyPort),
			"-http-address=",
			"-email-domain=*",
			fmt.Sprintf("-upstream=http://localhost:%d", upstreamPort),
			fmt.Sprintf("-openshift-service-account=%s", serviceAccount),
			fmt.Sprintf(`-openshift-sar={"resource": "namespaces", "verb": "get", "name": "%s", "namespace": "%s"}`, namespace, namespace),
			fmt.Sprintf(`-openshift-delegate-urls={"/": {"resource": "namespaces", "verb": "get", "name": "%s", "namespace": "%s"}}`, namespace, namespace),
			"-tls-cert=/etc/tls/private/tls.crt",
			"-tls-key=/etc/tls/private/tls.key",
			"-client-secret-file=/var/run/secrets/kubernetes.io/serviceaccount/token",
			"-cookie-secret=${OAUTH_PROXY_COOKIE_SECRET}", // replaced by openshift template parameter
			"-openshift-ca=/etc/pki/tls/cert.pem",
			"-openshift-ca=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt",
		},
		Resources: kghelpers.NewResourcesRequirements(cpuRequest, cpuLimit, memoryRequest, memoryLimit),
		Ports: []corev1.ContainerPort{
			{
				Name:          "https",
				ContainerPort: proxyPort,
				Protocol:      corev1.ProtocolTCP,
			},
		},
		ServicePorts: []corev1.ServicePort{
			kghelpers.NewServicePort("https", int(proxyPort), int(proxyPort)),
		},
		VolumeMounts: []corev1.VolumeMount{
			{
				Name:      "tls",
				MountPath: "/etc/tls/private",
				ReadOnly:  true,
			},
		},
		Volumes: []corev1.Volume{
			kghelpers.NewPodVolumeFromSecret("tls", tlsSecret),
		},
	}
}

func getAndRemoveObject[T metav1.Object](objects []runtime.Object, name string) (T, []runtime.Object) {
	var ret T
	var atIndex int
	found := false

	for i, obj := range objects {
		typedObject, ok := obj.(T)
		if ok {
			if name != "" && typedObject.GetName() != name {
				continue
			}

			// Check if we already found an object of this type. If so, panic.
			if found {
				panic(fmt.Sprintf("found multiple objects of type %T", *new(T)))
			}

			ret = typedObject
			found = true
			atIndex = i
			break
		}
	}

	if !found {
		panic(fmt.Sprintf("could not find object of type %T", *new(T)))
	}
	var modifiedObjs []runtime.Object
	for i := range objects {
		if i != atIndex {
			modifiedObjs = append(modifiedObjs, objects[i])
		}
	}
	return ret, modifiedObjs
}

// postProcessServiceMonitor updates the service monitor to work with the app-sre prometheus.
func postProcessServiceMonitor(serviceMonitor *monv1.ServiceMonitor, namespaceSelector string) encoding.Encoder {
	const (
		openshiftCustomerMonitoringLabel     = "prometheus"
		openShiftClusterMonitoringLabelValue = "app-sre"
	)

	serviceMonitor.ObjectMeta.Namespace = "openshift-customer-monitoring"
	serviceMonitor.Spec.NamespaceSelector.MatchNames = []string{namespaceSelector}
	serviceMonitor.ObjectMeta.Labels[openshiftCustomerMonitoringLabel] = openShiftClusterMonitoringLabelValue

	name := serviceMonitor.Name + "-service-monitor-" + namespaceSelector

	template := openshift.WrapInTemplate([]runtime.Object{serviceMonitor}, metav1.ObjectMeta{
		Name: name,
	}, nil)
	return encoding.GhodssYAML(template)
}

func sortTemplateParams(params []templatev1.Parameter) []templatev1.Parameter {
	sort.Slice(params, func(i, j int) bool {
		return params[i].Name < params[j].Name
	})
	return params
}

func createServiceAccount(name, namespace string, labels map[string]string) *corev1.ServiceAccount {
	return &corev1.ServiceAccount{
		TypeMeta: metav1.TypeMeta{
			Kind:       "ServiceAccount",
			APIVersion: "v1",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      name,
			Namespace: namespace,
			Labels:    labels,
		},
	}
}
