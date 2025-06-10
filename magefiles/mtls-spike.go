//go:build mage
// +build mage

package main

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"fmt"
	"math/big"
	"os"
	"path/filepath"
	"time"

	"github.com/magefile/mage/sh"
	"github.com/thanos-community/thanos-operator/test/utils"
)

const (
	namespace    = "rhobs-production"
	projectImage = "quay.io/thanos/thanos-operator"
)

// GenerateCA creates a Root CA and two Intermediate CAs (server/client), plus CA bundles.
func GenerateCA() error {
	dir := "/tmp/mtls-cas"
	os.MkdirAll(dir, 0755)

	// ===== Root CA =====
	rootKey, _ := rsa.GenerateKey(rand.Reader, 4096)
	rootTemplate := x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject: pkix.Name{
			Country:      []string{"US"},
			Organization: []string{"ExampleOrg"},
			CommonName:   "ExampleRootCA",
		},
		NotBefore:             time.Now(),
		NotAfter:              time.Now().AddDate(10, 0, 0),
		KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageCRLSign,
		BasicConstraintsValid: true,
		IsCA:                  true,
	}

	rootCertDER, _ := x509.CreateCertificate(rand.Reader, &rootTemplate, &rootTemplate, &rootKey.PublicKey, rootKey)
	rootCertPath := filepath.Join(dir, "root-ca.crt")
	rootKeyPath := filepath.Join(dir, "root-ca.key")
	writePem(rootCertPath, "CERTIFICATE", rootCertDER)
	writePem(rootKeyPath, "RSA PRIVATE KEY", x509.MarshalPKCS1PrivateKey(rootKey))

	// Helper to create intermediate CA
	createIntermediate := func(name, cn string, serial int64) (certPath, keyPath string) {
		key, _ := rsa.GenerateKey(rand.Reader, 4096)
		template := x509.Certificate{
			SerialNumber:          big.NewInt(serial),
			Subject:               pkix.Name{Country: []string{"US"}, Organization: []string{"ExampleOrg"}, CommonName: cn},
			NotBefore:             time.Now(),
			NotAfter:              time.Now().AddDate(5, 0, 0),
			KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageDigitalSignature | x509.KeyUsageCRLSign,
			BasicConstraintsValid: true,
			IsCA:                  true,
			MaxPathLen:            0,
		}
		certDER, _ := x509.CreateCertificate(rand.Reader, &template, &rootTemplate, &key.PublicKey, rootKey)
		certPath = filepath.Join(dir, fmt.Sprintf("intermediate-%s.crt", name))
		keyPath = filepath.Join(dir, fmt.Sprintf("intermediate-%s.key", name))
		writePem(certPath, "CERTIFICATE", certDER)
		writePem(keyPath, "RSA PRIVATE KEY", x509.MarshalPKCS1PrivateKey(key))
		return certPath, keyPath
	}

	// Generate both intermediates
	serverCert, _ := createIntermediate("server", "IntermediateCA-Server", 2)
	clientCert, _ := createIntermediate("client", "IntermediateCA-Client", 3)

	// Generate CA bundles
	createBundle := func(bundlePath string, chainCertPaths ...string) {
		out, err := os.Create(bundlePath)
		if err != nil {
			panic(err)
		}
		defer out.Close()
		for _, path := range chainCertPaths {
			data, err := os.ReadFile(path)
			if err != nil {
				panic(err)
			}
			out.Write(data)
		}
	}

	createBundle(filepath.Join(dir, "server-ca-bundle.pem"), serverCert, rootCertPath)
	createBundle(filepath.Join(dir, "client-ca-bundle.pem"), clientCert, rootCertPath)

	fmt.Println("✅ All certs, keys, and CA bundles written to", dir)
	return nil
}

func writePem(path, typ string, der []byte) {
	f, err := os.Create(path)
	if err != nil {
		panic(err)
	}
	defer f.Close()
	if err := pem.Encode(f, &pem.Block{Type: typ, Bytes: der}); err != nil {
		panic(err)
	}
}

func ClientCluster() error {
	if err := kind(); err != nil {
		return err
	}

	if err := CertManager(); err != nil {
		return err
	}
	if err := PromOperator(); err != nil {
		return err
	}

	if err := sh.Run("kubectl", "create", "namespace", "test-tenant"); err != nil {
		return err
	}

	if err := setUpPrometheus(); err != nil {
		return err
	}

	return nil
}

func kind() error {
	return sh.Run("kind", "create", "cluster", "--name", "kind")
}

func PromOperator() error {
	return utils.InstallPrometheusOperator()
}

func CertManager() error {
	return utils.InstallCertManager()
}

func setUpPrometheus() error {
	content := `
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/metrics
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources:
  - configmaps
  verbs: ["get"]
- apiGroups:
  - discovery.k8s.io
  resources:
  - endpointslices
  verbs: ["get", "list", "watch"]
- apiGroups:
  - networking.k8s.io
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: test-tenant
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: example-app
  template:
    metadata:
      labels:
        app: example-app
    spec:
      containers:
      - name: example-app
        image: quay.io/brancz/prometheus-example-app:v0.5.0
        ports:
        - name: web
          containerPort: 8080
---
kind: Service
apiVersion: v1
metadata:
  name: example-app
  labels:
    app: example-app
spec:
  selector:
    app: example-app
  ports:
  - name: web
    port: 8080
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: example-app
  labels:
    team: frontend
spec:
  selector:
    matchLabels:
      app: example-app
  endpoints:
  - port: web
`
	_, err := applyNamespacedKubeResources(content, "test-tenant")
	return err
}

func RunPrometheus() error {
	content := `
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/metrics
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources:
  - configmaps
  verbs: ["get"]
- apiGroups:
  - discovery.k8s.io
  resources:
  - endpointslices
  verbs: ["get", "list", "watch"]
- apiGroups:
  - networking.k8s.io
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: default
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: example-app
  template:
    metadata:
      labels:
        app: example-app
    spec:
      containers:
      - name: example-app
        image: quay.io/brancz/prometheus-example-app:v0.5.0
        ports:
        - name: web
          containerPort: 8080
---
kind: Service
apiVersion: v1
metadata:
  name: example-app
  labels:
    app: example-app
spec:
  selector:
    app: example-app
  ports:
  - name: web
    port: 8080
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: example-app
  labels:
    team: frontend
spec:
  selector:
    matchLabels:
      app: example-app
  endpoints:
  - port: web
---
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: prometheus-dev
spec:
  secrets: ['dev-client-secret']
  serviceAccountName: prometheus
  externalLabels:
    env: dev
  serviceMonitorSelector:
    matchLabels:
      team: frontend
  remoteWrite:
    - url: https://thanos-gateway-test.thanos-operator-system.svc.cluster.local:8081/api/v1/receive
      name: thanos-receive-router
      tlsConfig:
        caFile: /etc/prometheus/secrets/dev-client-secret/ca.crt
        certFile: /etc/prometheus/secrets/dev-client-secret/tls.crt
        keyFile: /etc/prometheus/secrets/dev-client-secret/tls.key

`
	_, err := applyNamespacedKubeResources(content, "test-tenant")
	return err
}

func applyKubeResources(resources string, withArgs ...string) (string, error) {
	in := []byte(resources)
	dir, err := os.MkdirTemp("", "resources")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(dir)
	file := filepath.Join(dir, "tmpfile")
	if err := os.WriteFile(file, in, 0666); err != nil {
		return "", err
	}
	args := append([]string{"apply", "-f", file}, withArgs...)
	return sh.Output("kubectl", args...)
}

func applyNamespacedKubeResources(resources, namespace string) (string, error) {
	in := []byte(resources)
	dir, err := os.MkdirTemp("", "resources")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(dir)
	file := filepath.Join(dir, "tmpfile")
	if err := os.WriteFile(file, in, 0666); err != nil {
		return "", err
	}
	return sh.Output("kubectl", "-n", namespace, "apply", "-f", file)
}
