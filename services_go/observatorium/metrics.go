package observatorium

import (
	"fmt"
	"net"
	"time"

	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/compactor"
	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/thanos/store"
	"github.com/observatorium/observatorium/configuration_go/k8sutil"
	"github.com/observatorium/observatorium/configuration_go/schemas/thanos/cache"
	"github.com/observatorium/observatorium/configuration_go/schemas/thanos/cache/redis"
	"github.com/observatorium/observatorium/configuration_go/schemas/thanos/common"
	"github.com/observatorium/observatorium/configuration_go/schemas/thanos/units"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
)

func makeCompactor(namespace string) (*compactor.CompactorStatefulSet, PostProcessFunc) {
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

	return compactorSatefulset, addServiceCertAnnotation(compactorSatefulset.CommonLabels[k8sutil.NameLabel], tlsSecret)
}

func makeStore(namespace string) (*store.StoreStatefulSet, PostProcessFunc) {
	storeStatefulSet := store.NewStore()
	storeStatefulSet.Image = thanosImage
	storeStatefulSet.ImageTag = thanosImageTag
	storeStatefulSet.Namespace = namespace
	storeStatefulSet.Replicas = 1
	delete(storeStatefulSet.PodResources.Limits, corev1.ResourceCPU) // To be confirmed
	storeStatefulSet.PodResources.Requests[corev1.ResourceCPU] = resource.MustParse("200m")
	storeStatefulSet.PodResources.Requests[corev1.ResourceMemory] = resource.MustParse("1Gi")
	storeStatefulSet.PodResources.Limits[corev1.ResourceMemory] = resource.MustParse("5Gi")
	storeStatefulSet.VolumeType = "gp2"
	storeStatefulSet.VolumeSize = "500Gi"
	storeStatefulSet.Env = []corev1.EnvVar{
		k8sutil.NewEnvFromSecret("AWS_ACCESS_KEY_ID", "rhobs-thanos-s3", "aws_access_key_id"),
		k8sutil.NewEnvFromSecret("AWS_SECRET_ACCESS_KEY", "rhobs-thanos-s3", "aws_secret_access_key"),
		k8sutil.NewEnvFromSecret("OBJSTORE_CONFIG", "rhobs-thanos-objectstorage", "thanos.yaml"),
	}
	tlsSecret := "store-tls"
	storeStatefulSet.Sidecars = []k8sutil.ContainerProvider{makeOauthProxy(10902, namespace, storeStatefulSet.Name, tlsSecret)}

	// Store config
	storeStatefulSet.Options.LogLevel = "warn"
	storeStatefulSet.Options.LogFormat = "logfmt"
	storeStatefulSet.Options.IgnoreDeletionMarksDelay = 24 * time.Hour
	maxTime := time.Duration(365*24) * time.Hour
	storeStatefulSet.Options.MaxTime = &common.TimeOrDurationValue{Dur: &maxTime}
	storeStatefulSet.Options.ChunkPoolSize = 2040 * units.GiB
	storeStatefulSet.Options.HttpAddress = &net.TCPAddr{Port: 10902, IP: net.ParseIP("0.0.0.0")}
	// storeStatefulSet.Options.StoreGrpcDownloadedBytesLimit
	// indexCacheCfg, err := yaml.Marshal(cache.NewConfig(redis.RedisClientConfig{
	// 	Addr: "rhobs-redis.rhobs.svc.cluster.local:6379",
	// }))
	// mimic.PanicOnErr(err)

	storeStatefulSet.Options.IndexCacheConfig = cache.NewConfig(redis.RedisClientConfig{
		Addr: "rhobs-redis.rhobs.svc.cluster.local:6379",
	})

	return storeStatefulSet, addServiceCertAnnotation(storeStatefulSet.CommonLabels[k8sutil.NameLabel], tlsSecret)
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
