package observatorium

import (
	"fmt"

	kghelpers "github.com/observatorium/observatorium/configuration_go/kubegen/helpers"
	"github.com/observatorium/observatorium/configuration_go/kubegen/workload"
	corev1 "k8s.io/api/core/v1"
)

// makeOauthProxy creates a container for the oauth-proxy sidecar.
// It contains a template parameter OAUTH_PROXY_COOKIE_SECRET that must be added to the template parameters.
func makeOauthProxy(upstreamPort int32, namespace, serviceAccount, tlsSecret string) *workload.Container {
	proxyPort := int32(8443)

	return &workload.Container{
		Name:     "oauth-proxy",
		Image:    "quay.io/openshift/origin-oauth-proxy",
		ImageTag: "4.15",
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
		Resources: kghelpers.NewResourcesRequirements("100m", "200m", "100Mi", "200Mi"),
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

// makeJaegerAgent creates a container for the jaeger-agent sidecar.
func makeJaegerAgent(collectorNamespace string) *workload.Container {
	metricsPort := int32(14271)
	livelinesProbe := kghelpers.NewProbe("/", int(metricsPort), kghelpers.ProbeConfig{FailureThreshold: 5})
	readinessProbe := kghelpers.NewProbe("/", int(metricsPort), kghelpers.ProbeConfig{InitialDelaySeconds: 1})
	return &workload.Container{
		Name:     "jaeger-agent",
		Image:    "quay.io/app-sre/jaegertracing-jaeger-agent",
		ImageTag: "1.22.0",
		Args: []string{
			fmt.Sprintf("--reporter.grpc.host-port=dns:///otel-trace-writer-collector-headless.%s.svc:14250", collectorNamespace),
			"--reporter.type=grpc",
			"--agent.tags=pod.namespace=$(NAMESPACE),pod.name=$(POD)",
		},
		Resources: kghelpers.NewResourcesRequirements("32m", "128m", "64Mi", "128Mi"),
		Ports: []corev1.ContainerPort{
			{
				Name:          "configs",
				ContainerPort: 5778,
				Protocol:      corev1.ProtocolTCP,
			},
			{
				Name:          "jaeger-thrift",
				ContainerPort: 6831,
				Protocol:      corev1.ProtocolTCP,
			},
			{
				Name:          "metrics",
				ContainerPort: metricsPort,
				Protocol:      corev1.ProtocolTCP,
			},
		},
		Env: []corev1.EnvVar{
			{
				Name: "NAMESPACE",
				ValueFrom: &corev1.EnvVarSource{
					FieldRef: &corev1.ObjectFieldSelector{
						FieldPath: "metadata.namespace",
					},
				},
			},
			{
				Name: "POD",
				ValueFrom: &corev1.EnvVarSource{
					FieldRef: &corev1.ObjectFieldSelector{
						FieldPath: "metadata.name",
					},
				},
			},
		},
		LivenessProbe:  livelinesProbe,
		ReadinessProbe: readinessProbe,
	}
}
