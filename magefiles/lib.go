package main

import (
	"fmt"
	"sort"

	kghelpers "github.com/observatorium/observatorium/configuration_go/kubegen/helpers"
	"github.com/observatorium/observatorium/configuration_go/kubegen/workload"
	templatev1 "github.com/openshift/api/template/v1"
	monv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"

	corev1 "k8s.io/api/core/v1"
)

const (
	servingCertSecretNameAnnotation = "service.alpha.openshift.io/serving-cert-secret-name"
	serviceRedirectAnnotation       = "serviceaccounts.openshift.io/oauth-redirectreference.application"
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

// postProcessServiceMonitor updates the service monitor to work with the app-sre prometheus.
func postProcessServiceMonitor(serviceMonitor *monv1.ServiceMonitor, namespaceSelector string) {
	const (
		openshiftCustomerMonitoringLabel     = "prometheus"
		openShiftClusterMonitoringLabelValue = "app-sre"
	)

	serviceMonitor.Spec.NamespaceSelector.MatchNames = []string{namespaceSelector}
	serviceMonitor.ObjectMeta.Labels[openshiftCustomerMonitoringLabel] = openShiftClusterMonitoringLabelValue
}

func sortTemplateParams(params []templatev1.Parameter) []templatev1.Parameter {
	sort.Slice(params, func(i, j int) bool {
		return params[i].Name < params[j].Name
	})
	return params
}
