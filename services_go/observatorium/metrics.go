package observatorium

import (
	"fmt"
	"time"

	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/compactor"
	"github.com/observatorium/observatorium/configuration_go/k8sutil"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	"k8s.io/apimachinery/pkg/runtime"
)

func makeCompactor(namespace string) *compactor.CompactorStatefulSet {
	// K8s config
	compactorSatefulset := compactor.NewCompactor()
	compactorSatefulset.Image = thanosImage
	compactorSatefulset.ImageTag = thanosImageTag
	compactorSatefulset.Namespace = namespace
	compactorSatefulset.Replicas = 1
	delete(compactorSatefulset.PodResources.Limits, corev1.ResourceCPU) // To be confirmed
	compactorSatefulset.PodResources.Requests[corev1.ResourceCPU] = resource.MustParse("200m")
	compactorSatefulset.PodResources.Requests[corev1.ResourceMemory] = resource.MustParse("1Gi")
	compactorSatefulset.PodResources.Limits[corev1.ResourceMemory] = resource.MustParse("5Gi")
	compactorSatefulset.VolumeType = "gp2"
	compactorSatefulset.VolumeSize = "500Gi"
	compactorSatefulset.Env = []corev1.EnvVar{
		k8sutil.NewEnvFromSecret("AWS_ACCESS_KEY_ID", "rhobs-thanos-s3", "aws_access_key_id"),
		k8sutil.NewEnvFromSecret("AWS_SECRET_ACCESS_KEY", "rhobs-thanos-s3", "aws_secret_access_key"),
		k8sutil.NewEnvFromSecret("OBJSTORE_CONFIG", "rhobs-thanos-objectstorage", "thanos.yaml"),
	}
	tlsSecret := "compact-tls"
	compactorSatefulset.Sidecars = []k8sutil.ContainerProvider{makeOauthProxy(10902, namespace, compactorSatefulset.Name, tlsSecret)}
	// compactorSatefulset.PostProcess = []k8sutil.ObjectProcessor{
	// 	serviceCertAnnotationModifier(tlsSecret),
	// }

	// Compactor config
	compactorSatefulset.Options.LogLevel = "warn"
	compactorSatefulset.Options.RetentionResolutionRaw = 365 * 24 * time.Hour
	compactorSatefulset.Options.RetentionResolution5m = 365 * 24 * time.Hour
	compactorSatefulset.Options.RetentionResolution1h = 365 * 24 * time.Hour
	compactorSatefulset.Options.DeleteDelay = 24 * time.Hour
	compactorSatefulset.Options.CompactConcurrency = 1
	compactorSatefulset.Options.DownsampleConcurrency = 1
	compactorSatefulset.Options.DeduplicationReplicaLabel = "replica"
	compactorSatefulset.Options.AddExtraOpts("--debug.max-compaction-level=3")

	return compactorSatefulset
}

func serviceCertAnnotationModifier(secretName string) func(object runtime.Object) {
	return func(object runtime.Object) {
		if service, ok := object.(*corev1.Service); ok {
			service.ObjectMeta.Annotations["service.beta.openshift.io/serving-cert-secret-name"] = secretName
		}
	}
}

func makeOauthProxy(upstreamPort int32, namespace, serviceAccount, tlsSecret string) *k8sutil.Container {
	proxyPort := int32(8443)

	return &k8sutil.Container{
		Name:     "oauth-proxy",
		Image:    "quay.io/openshift/origin-oauth-proxy",
		ImageTag: "v4.8.0",
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
			"-cookie-secret-file=/etc/proxy/secrets/session_secret",
			"-openshift-ca=/etc/pki/tls/cert.pem",
			"-openshift-ca=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt",
		},
		Resources: k8sutil.NewResourcesRequirements("100m", "200m", "100Mi", "200Mi"),
		Ports: []corev1.ContainerPort{
			{
				Name:          "https",
				ContainerPort: proxyPort,
				Protocol:      corev1.ProtocolTCP,
			},
		},
		ServicePorts: []corev1.ServicePort{
			k8sutil.NewServicePort("https", int(proxyPort), int(proxyPort)),
		},
		VolumeMounts: []corev1.VolumeMount{
			{
				Name:      "compact-tls",
				MountPath: "/etc/tls/private",
				ReadOnly:  true,
			},
			{
				Name:      "compact-proxy",
				MountPath: "/etc/proxy/secrets",
				ReadOnly:  true,
			},
		},
		Volumes: []corev1.Volume{
			k8sutil.NewPodVolumeFromSecret("compact-tls", tlsSecret),
			k8sutil.NewPodVolumeFromSecret("compact-proxy", "compact-proxy"),
		},
		Secrets: map[string]map[string][]byte{
			"compact-proxy": {
				"session_secret": []byte("secret"),
			},
		},
	}
}
