package main

import (
	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic/encoding"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

// Secrets generates the secrets for both Stage and Local environments
func (s Stage) Secrets() {
	templateDir := "objstore"
	gen := s.generator(templateDir)

	gen.Add("thanos-telemeter-secret.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			[]runtime.Object{thanosObjectStoreSecret("thanos-objectstorage", s.namespace())},
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
			[]runtime.Object{thanosObjectStoreSecret("observatorium-mst-thanos-objectstorage", s.namespace())},
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
