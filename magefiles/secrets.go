package main

import (
	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic"
	"github.com/philipgough/mimic/encoding"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

const (
	objStoreSecretsTemplateDir = "objstore"
	cacheTemplatesDir          = "redis"
)

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

const (
	indexCacheName  = "thanos-index-cache"
	bucketCacheName = "thanos-bucket-cache"
)

func cacheSecretsStage(namespace string) []*corev1.Secret {
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
				"index-cache.yaml": `type: REDIS
config:
  addr: ${INDEX_CACHE_ADDR}:${INDEX_CACHE_PORT}
  password: ${INDEX_CACHE_AUTH_TOKEN}
  db: 0
  max_item_size: 12428800 # 10 MiB
  ttl: 24h
  max_ascent_ttl: 24h
  max_size: 0 # Unlimited
  tls_enabled: true`,
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
				"bucket-cache.yaml": `type: REDIS
config:
  addr: ${BUCKET_CACHE_ADDR}:${BUCKET_CACHE_PORT}
  password: ${BUCKET_CACHE_AUTH_TOKEN}
  db: 0
  max_item_size: 12428800 # 10 MiB
  ttl: 24h
  max_ascent_ttl: 24h
  max_size: 0 # Unlimited
  tls_enabled: true`,
			},
		},
	}
}

// thanosObjectStoreTemplate creates a templated version for stage environment
func thanosObjectStoreSecret(name, namespace string) *corev1.Secret {
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
			"thanos.yaml": `type: S3
config:
  bucket: ${S3_BUCKET_NAME}
  region: ${S3_BUCKET_REGION}
  access_key: ${ACCESS_KEY_ID}
  secret_key: ${SECRET_ACCESS_KEY}
  endpoint: ${S3_BUCKET_ENDPOINT}`,
		},
	}
}

// localThanosObjectStore creates a non-templated version with Minio credentials for local environment
func localThanosObjectStore(secretName, namespace string) *corev1.Secret {
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
			"thanos.yaml": `type: S3
config:
  bucket: thanos
  region: us-east-1
  access_key: minio
  secret_key: minio123
  endpoint: minio.observatorium-minio.svc:9000
  insecure: true`,
		},
	}
}
