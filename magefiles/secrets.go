package main

import (
	"os"
	"time"

	"gopkg.in/yaml.v2"

	"github.com/go-kit/log"
	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic"
	"github.com/philipgough/mimic/encoding"
	"github.com/rhobs/configuration/clusters"
	"github.com/thanos-io/objstore/client"
	"github.com/thanos-io/objstore/providers/s3"
	"github.com/thanos-io/thanos/pkg/cacheutil"
	"github.com/thanos-io/thanos/pkg/model"
	"github.com/thanos-io/thanos/pkg/queryfrontend"
	storecache "github.com/thanos-io/thanos/pkg/store/cache"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

const (
	objStoreSecretsTemplateDir = "objstore"
	cacheTemplatesDir          = "redis"
)

// ObjectStorageSecretTemplate generates the Thanos object storage secret template
func ObjectStorageSecretTemplate() {
	gen := &mimic.Generator{}
	gen = gen.With(templatePath, templateServicesPath, objStoreSecretsTemplateDir)
	gen.Logger = log.NewLogfmtLogger(log.NewSyncWriter(os.Stdout))

	gen.Add("thanos-object-store-secret.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			[]runtime.Object{thanosObjectStoreSecretTemplate()},
			metav1.ObjectMeta{Name: "thanos-object-store-secret"},
			[]templatev1.Parameter{
				{Name: "SECRET_NAME"},
				{Name: "NAMESPACE"},
				{Name: "S3_BUCKET_NAME"},
				{Name: "S3_BUCKET_REGION"},
				{Name: "S3_BUCKET_ENDPOINT"},
				{Name: "ACCESS_KEY_ID"},
				{Name: "SECRET_ACCESS_KEY"},
			},
		),
	))

	gen.Generate()

}

// Secrets generates the secrets for the Production environment
func (p Production) Secrets() {
	secrets(p.generator(objStoreSecretsTemplateDir), p.namespace())
}

// Secrets generates the secrets for the Stage environment
func (s Stage) Secrets() {
	ns := s.namespace()
	secrets(s.generator(objStoreSecretsTemplateDir), ns)
	var cacheObjs []runtime.Object
	for _, secret := range cacheSecretsStage(ns) {
		cacheObjs = append(cacheObjs, secret)
	}
	cacheSecrets(s.generator(cacheTemplatesDir), cacheObjs)
}

func cacheSecrets(gen *mimic.Generator, secrets []runtime.Object) {
	gen.Add("cache.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			secrets,
			metav1.ObjectMeta{Name: "redis-cache-secret"},
			[]templatev1.Parameter{
				{Name: "INDEX_CACHE_ADDR"},
				{Name: "INDEX_CACHE_PORT"},
				{Name: "INDEX_CACHE_AUTH_TOKEN"},
				{Name: "BUCKET_CACHE_ADDR"},
				{Name: "BUCKET_CACHE_PORT"},
				{Name: "BUCKET_CACHE_AUTH_TOKEN"},
			},
		),
	))
	gen.Generate()
}

func secrets(gen *mimic.Generator, ns string) {
	gen.Add("thanos-telemeter-secret.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			[]runtime.Object{thanosObjectStoreSecret("thanos-objectstorage", ns)},
			metav1.ObjectMeta{Name: "thanos-telemeter-secret"},
			[]templatev1.Parameter{
				{Name: "S3_BUCKET_NAME"},
				{Name: "S3_BUCKET_REGION"},
				{Name: "S3_BUCKET_ENDPOINT"},
				{Name: "ACCESS_KEY_ID"},
				{Name: "SECRET_ACCESS_KEY"},
			},
		),
	))

	// Generate MST Thanos objectstorage secret
	gen.Add("thanos-default-secret.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			[]runtime.Object{thanosObjectStoreSecret("observatorium-mst-thanos-objectstorage", ns)},
			metav1.ObjectMeta{Name: "thanos-default-secret"},
			[]templatev1.Parameter{
				{Name: "S3_BUCKET_NAME"},
				{Name: "S3_BUCKET_REGION"},
				{Name: "S3_BUCKET_ENDPOINT"},
				{Name: "ACCESS_KEY_ID"},
				{Name: "SECRET_ACCESS_KEY"},
			},
		),
	))

	gen.Generate()
}

func (b Build) Secrets(config clusters.ClusterConfig) {
	gen := b.generator(config, "secrets")
	cacheSecrets := memcachedCacheSecrets(config.Namespace)

	secrets := []runtime.Object{
		thanosObjectStoreSecret("default-thanos-bucket", config.Namespace),
	}

	for _, secret := range cacheSecrets {
		secrets = append(secrets, secret)
	}

	gen.Add("thanos-default-secret.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			secrets,
			metav1.ObjectMeta{Name: "thanos-object-store-secret"},
			[]templatev1.Parameter{
				{Name: "S3_BUCKET_NAME"},
				{Name: "S3_BUCKET_REGION"},
				{Name: "S3_BUCKET_ENDPOINT"},
				{Name: "ACCESS_KEY_ID"},
				{Name: "SECRET_ACCESS_KEY"},
			},
		),
	))

	gen.Generate()
}

// Secrets generates the secrets for the Local environment
func (l Local) Secrets() {
	templateDir := "objstore"
	gen := l.generator(templateDir)

	gen.Add("thanos-telemeter-secret.yaml", encoding.GhodssYAML(
		localThanosObjectStore("thanos-objectstorage", l.namespace()),
	))

	gen.Add("thanos-default-secret.yaml", encoding.GhodssYAML(
		localThanosObjectStore("observatorium-mst-thanos-objectstorage", l.namespace()),
	))

	gen.Generate()
}

func cacheSecretsStage(namespace string) []*corev1.Secret {
	redisClientConfig := cacheutil.DefaultRedisClientConfig
	redisClientConfig.Addr = "${INDEX_CACHE_ADDR}:${INDEX_CACHE_PORT}"
	redisClientConfig.Password = "${INDEX_CACHE_AUTH_TOKEN}"
	redisClientConfig.DB = 0
	redisClientConfig.TLSEnabled = true

	indexCacheConfig := storecache.IndexCacheConfig{
		Type:   storecache.REDIS,
		Config: redisClientConfig,
	}

	indexCacheConfigYaml, err := yaml.Marshal(indexCacheConfig)
	if err != nil {
		panic(err)
	}

	redisClientConfig.Addr = "${BUCKET_CACHE_ADDR}:${BUCKET_CACHE_PORT}"
	redisClientConfig.Password = "${BUCKET_CACHE_AUTH_TOKEN}"

	bucketCacheConfig := storecache.CachingWithBackendConfig{
		Type:                      storecache.MemcachedBucketCacheProvider,
		BackendConfig:             redisClientConfig,
		ChunkSubrangeSize:         16000,
		ChunkObjectAttrsTTL:       24 * time.Hour,
		ChunkSubrangeTTL:          24 * time.Hour,
		MaxChunksGetRangeRequests: 3,
		MetafileMaxSize:           model.Bytes(1 * 1024 * 1024),
		MetafileExistsTTL:         2 * time.Hour,
		MetafileDoesntExistTTL:    15 * time.Minute,
		MetafileContentTTL:        24 * time.Hour,
	}

	bucketCacheConfigYaml, err := yaml.Marshal(bucketCacheConfig)
	if err != nil {
		panic(err)
	}

	return []*corev1.Secret{
		{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "v1",
				Kind:       "Secret",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      indexCacheName,
				Namespace: namespace,
				Labels: map[string]string{
					"app.kubernetes.io/name": indexCacheName,
				},
			},
			Type: corev1.SecretTypeOpaque,
			StringData: map[string]string{
				"index-cache.yaml": string(indexCacheConfigYaml),
			},
		},
		{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "v1",
				Kind:       "Secret",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      bucketCacheName,
				Namespace: namespace,
				Labels: map[string]string{
					"app.kubernetes.io/name": bucketCacheName,
				},
			},
			Type: corev1.SecretTypeOpaque,
			StringData: map[string]string{
				"bucket-cache.yaml": string(bucketCacheConfigYaml),
			},
		},
	}
}

// thanosObjectStoreSecretTemplate creates a templated version of the Thanos object store secret
func thanosObjectStoreSecretTemplate() *corev1.Secret {
	config := client.BucketConfig{
		Type: client.S3,
		Config: s3.Config{
			Bucket:    "${S3_BUCKET_NAME}",
			Region:    "${S3_BUCKET_REGION}",
			AccessKey: "${ACCESS_KEY_ID}",
			SecretKey: "${SECRET_ACCESS_KEY}",
			Endpoint:  "${S3_BUCKET_ENDPOINT}",
		},
	}
	b, err := yaml.Marshal(config)
	if err != nil {
		panic(err)
	}

	return &corev1.Secret{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "Secret",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "${SECRET_NAME}",
			Namespace: "${NAMESPACE}",
			Labels: map[string]string{
				"app.kubernetes.io/name": "${SECRET_NAME}",
			},
		},
		Type: corev1.SecretTypeOpaque,
		StringData: map[string]string{
			"thanos.yaml": string(b),
		},
	}
}

// thanosObjectStoreTemplate creates a templated version for stage environment
func thanosObjectStoreSecret(name, namespace string) *corev1.Secret {
	config := client.BucketConfig{
		Type: client.S3,
		Config: s3.Config{
			Bucket:    "${S3_BUCKET_NAME}",
			Region:    "${S3_BUCKET_REGION}",
			AccessKey: "${ACCESS_KEY_ID}",
			SecretKey: "${SECRET_ACCESS_KEY}",
			Endpoint:  "${S3_BUCKET_ENDPOINT}",
		},
	}

	b, err := yaml.Marshal(config)
	if err != nil {
		panic(err)
	}

	return &corev1.Secret{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "Secret",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      name,
			Namespace: namespace,
			Labels: map[string]string{
				"app.kubernetes.io/name": name,
			},
		},
		Type: corev1.SecretTypeOpaque,
		StringData: map[string]string{
			"thanos.yaml": string(b),
		},
	}
}

func memcachedCacheSecrets(namespace string) []*corev1.Secret {
	indexCacheConfig := storecache.IndexCacheConfig{
		Type: storecache.MEMCACHED,
		Config: cacheutil.MemcachedClientConfig{
			Addresses: []string{
				"dnssrv+_client._tcp.thanos-index-cache." + namespace + ".svc",
			},
			DNSProviderUpdateInterval: 10 * time.Second,
			MaxAsyncBufferSize:        2500000,
			MaxAsyncConcurrency:       1000,
			MaxGetMultiBatchSize:      100000,
			MaxGetMultiConcurrency:    1000,
			MaxIdleConnections:        2500,
			MaxItemSize:               model.Bytes(5 * 1024 * 1024),
			Timeout:                   2 * time.Second,
		},
	}

	indexCacheConfigYaml, err := yaml.Marshal(indexCacheConfig)
	if err != nil {
		panic(err)
	}

	bucketCacheConfig := storecache.CachingWithBackendConfig{
		Type: storecache.MemcachedBucketCacheProvider,
		BackendConfig: cacheutil.MemcachedClientConfig{
			Addresses: []string{
				"dnssrv+_client._tcp.thanos-bucket-cache." + namespace + ".svc",
			},
			DNSProviderUpdateInterval: 10 * time.Second,
			MaxAsyncBufferSize:        25000,
			MaxAsyncConcurrency:       50,
			MaxGetMultiBatchSize:      100,
			MaxGetMultiConcurrency:    1000,
			MaxIdleConnections:        1100,
			MaxItemSize:               model.Bytes(1 * 1024 * 1024),
			Timeout:                   2 * time.Second,
		},
		ChunkSubrangeSize:         16000,
		ChunkObjectAttrsTTL:       24 * time.Hour,
		ChunkSubrangeTTL:          24 * time.Hour,
		MaxChunksGetRangeRequests: 3,
		MetafileMaxSize:           model.Bytes(1 * 1024 * 1024),
		MetafileExistsTTL:         2 * time.Hour,
		MetafileDoesntExistTTL:    15 * time.Minute,
		MetafileContentTTL:        24 * time.Hour,
	}

	bucketCacheConfigYaml, err := yaml.Marshal(bucketCacheConfig)
	if err != nil {
		panic(err)
	}

	queryRangeCacheConfig := queryfrontend.CacheProviderConfig{
		Type: queryfrontend.MEMCACHED,
		Config: queryfrontend.MemcachedResponseCacheConfig{
			Memcached: cacheutil.MemcachedClientConfig{
				Addresses: []string{
					"dnssrv+_client._tcp.thanos-query-range-cache." + namespace + ".svc",
				},
				DNSProviderUpdateInterval: 30 * time.Second,
				MaxAsyncBufferSize:        1000000,
				MaxAsyncConcurrency:       100,
				MaxGetMultiBatchSize:      500,
				MaxGetMultiConcurrency:    100,
				MaxIdleConnections:        500,
				MaxItemSize:               model.Bytes(100 * 1024 * 1024),
				Timeout:                   5 * time.Second,
			},
		},
	}

	queryRangeCacheConfigYaml, err := yaml.Marshal(queryRangeCacheConfig)
	if err != nil {
		panic(err)
	}

	return []*corev1.Secret{
		{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "v1",
				Kind:       "Secret",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-index-cache-memcached",
				Namespace: namespace,
				Labels: map[string]string{
					"app.kubernetes.io/name": "thanos-index-cache-memcached",
				},
			},
			Type: corev1.SecretTypeOpaque,
			StringData: map[string]string{
				"thanos.yaml": string(indexCacheConfigYaml),
			},
		},
		{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "v1",
				Kind:       "Secret",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-bucket-cache-memcached",
				Namespace: namespace,
				Labels: map[string]string{
					"app.kubernetes.io/name": "thanos-bucket-cache-memcached",
				},
			},
			Type: corev1.SecretTypeOpaque,
			StringData: map[string]string{
				"thanos.yaml": string(bucketCacheConfigYaml),
			},
		},
		{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "v1",
				Kind:       "Secret",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-query-range-cache-memcached",
				Namespace: namespace,
				Labels: map[string]string{
					"app.kubernetes.io/name": "thanos-query-range-cache-memcached",
				},
			},
			Type: corev1.SecretTypeOpaque,
			StringData: map[string]string{
				"thanos.yaml": string(queryRangeCacheConfigYaml),
			},
		},
	}
}

// localThanosObjectStore creates a non-templated version with Minio credentials for local environment
func localThanosObjectStore(secretName, namespace string) *corev1.Secret {
	config := client.BucketConfig{
		Type: client.S3,
		Config: s3.Config{
			Bucket:    "thanos",
			Region:    "us-east-1",
			AccessKey: "minio",
			SecretKey: "minio123",
			Endpoint:  "minio.observatorium-minio.svc:9000",
		},
	}

	b, err := yaml.Marshal(config)
	if err != nil {
		panic(err)
	}

	return &corev1.Secret{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "Secret",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      secretName,
			Namespace: namespace,
			Labels: map[string]string{
				"app.kubernetes.io/name": secretName,
			},
		},
		Type: corev1.SecretTypeOpaque,
		StringData: map[string]string{
			"thanos.yaml": string(b),
		},
	}
}
