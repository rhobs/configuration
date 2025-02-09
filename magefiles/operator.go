package main

import (
	"fmt"
	"net/http"

	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic/encoding"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	v1 "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/intstr"
	"k8s.io/apimachinery/pkg/util/yaml"
	"k8s.io/utils/ptr"
)

const (
	CRDMain     = "refs/heads/main"
	CRDRefStage = "e676d81ea0bb8252dd8985e0fe03038a2a7e2c30"
)

// CRDS Generates the CRDs for the Thanos operator.
// This is synced from the latest upstream main at:
// https://github.com/thanos-community/thanos-operator/tree/main/config/crd/bases
func (s Stage) CRDS() error {
	const (
		templateDir = "bundle"
	)
	gen := s.generator(templateDir)

	objs, err := crds(CRDRefStage)
	if err != nil {
		return err
	}

	template := openshift.WrapInTemplate(objs, metav1.ObjectMeta{Name: "thanos-operator-crds"}, []templatev1.Parameter{})
	encoder := encoding.GhodssYAML(template)
	gen.Add("thanos-operator-crds.yaml", encoder)
	gen.Generate()
	return nil
}

// CRDS Generates the CRDs for the Thanos operator for a local environment.
// This is synced from the latest upstream main at:
// https://github.com/thanos-community/thanos-operator/tree/main/config/crd/bases
func (l Local) CRDS() error {
	const (
		templateDir = "bundle"
	)
	gen := l.generator(templateDir)

	objs, err := crds(CRDRefStage)
	if err != nil {
		return err
	}

	encoder := encoding.GhodssYAML(objs[0], objs[1], objs[2], objs[3], objs[4])
	gen.Add("thanos-operator-crds.yaml", encoder)
	gen.Generate()
	return nil
}

func crds(ref string) ([]runtime.Object, error) {
	const (
		compact   = "thanoscompacts.yaml"
		queries   = "thanosqueries.yaml"
		receivers = "thanosreceives.yaml"
		rulers    = "thanosrulers.yaml"
		stores    = "thanosstores.yaml"
	)

	base := "https://raw.githubusercontent.com/thanos-community/thanos-operator/" + ref + "/config/crd/bases/monitoring.thanos.io_"

	var objs []runtime.Object
	for _, component := range []string{compact, queries, receivers, rulers, stores} {
		manifest := base + component
		resp, err := http.Get(manifest)
		if err != nil {
			return nil, fmt.Errorf("failed to fetch %s: %w", manifest, err)
		}

		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("failed to fetch %s: %s", manifest, resp.Status)
		}

		var obj v1.CustomResourceDefinition
		decoder := yaml.NewYAMLOrJSONDecoder(resp.Body, 100000)
		err = decoder.Decode(&obj)
		if err != nil {
			return nil, fmt.Errorf("failed to decode %s: %w", manifest, err)
		}

		objs = append(objs, &obj)
		resp.Body.Close()
	}

	return objs, nil
}

// Operator Generates the Thanos Operator Manager resources.
func (s Stage) Operator() {
	templateDir := "bundle"

	gen := s.generator(templateDir)

	gen.Add("operator.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			operatorResources(s.namespace(), StageMaps),
			metav1.ObjectMeta{Name: "thanos-operator-manager"},
			[]templatev1.Parameter{},
		),
	))

	gen.Generate()
}

// Operator Generates the Thanos Operator Manager resources for a local environment.
func (l Local) Operator() {
	templateDir := "bundle"

	gen := l.generator(templateDir)

	objs := operatorResources(l.namespace(), LocalMaps)

	// Create namespace object
	namespace := &corev1.Namespace{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "Namespace",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: l.namespace(),
		},
	}

	// Create object storage secrets
	defaultObjStore := &corev1.Secret{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "Secret",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "default-objectstorage",
			Namespace: l.namespace(),
		},
		StringData: map[string]string{
			"thanos.yaml": `type: s3
config:
  bucket: thanos
  endpoint: minio:9000
  insecure: true
  access_key: minio
  secret_key: minio123`,
		},
	}

	telemeterObjStore := &corev1.Secret{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "Secret",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "telemeter-objectstorage",
			Namespace: l.namespace(),
		},
		StringData: map[string]string{
			"thanos.yaml": `type: s3
config:
  bucket: telemeter
  endpoint: minio:9000
  insecure: true
  access_key: minio
  secret_key: minio123`,
		},
	}

	// Add all resources to the generator
	gen.Add("operator.yaml", encoding.GhodssYAML(
		namespace,
		defaultObjStore,
		telemeterObjStore,
		objs[0], objs[1], objs[2], objs[3], objs[4], objs[5],
		objs[6], objs[7], objs[8], objs[9], objs[10], objs[11],
		objs[12], objs[13],
	))

	gen.Generate()
}

func operatorResources(namespace string, m TemplateMaps) []runtime.Object {
	return []runtime.Object{
		&corev1.ServiceAccount{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "v1",
				Kind:       "ServiceAccount",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-operator-controller-manager",
				Namespace: namespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "rbac",
					"app.kubernetes.io/created-by": "thanos-operator",
					"app.kubernetes.io/instance":   "controller-manager-sa",
					"app.kubernetes.io/managed-by": "rhobs",
					"app.kubernetes.io/name":       "serviceaccount",
					"app.kubernetes.io/part-of":    "thanos-operator",
				},
			},
		},

		// Leader Election Role
		&rbacv1.Role{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "rbac.authorization.k8s.io/v1",
				Kind:       "Role",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-operator-leader-election-role",
				Namespace: namespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "rbac",
					"app.kubernetes.io/created-by": "thanos-operator",
					"app.kubernetes.io/instance":   "leader-election-role",
					"app.kubernetes.io/managed-by": "rhobs",
					"app.kubernetes.io/name":       "role",
					"app.kubernetes.io/part-of":    "thanos-operator",
				},
			},
			Rules: []rbacv1.PolicyRule{
				{
					APIGroups: []string{""},
					Resources: []string{"configmaps"},
					Verbs:     []string{"get", "list", "watch", "create", "update", "patch", "delete"},
				},
				{
					APIGroups: []string{"coordination.k8s.io"},
					Resources: []string{"leases"},
					Verbs:     []string{"get", "list", "watch", "create", "update", "patch", "delete"},
				},
				{
					APIGroups: []string{""},
					Resources: []string{"events"},
					Verbs:     []string{"create", "patch"},
				},
			},
		},

		// Manager ClusterRole
		&rbacv1.ClusterRole{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "rbac.authorization.k8s.io/v1",
				Kind:       "ClusterRole",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name: "thanos-operator-manager-role",
			},
			Rules: []rbacv1.PolicyRule{
				{
					APIGroups: []string{""},
					Resources: []string{"configmaps", "serviceaccounts", "services"},
					Verbs:     []string{"create", "delete", "get", "list", "patch", "update", "watch"},
				},
				{
					APIGroups: []string{"apps"},
					Resources: []string{"deployments", "statefulsets"},
					Verbs:     []string{"create", "delete", "get", "list", "patch", "update", "watch"},
				},
				{
					APIGroups: []string{"discovery.k8s.io"},
					Resources: []string{"endpointslices"},
					Verbs:     []string{"get", "list", "watch"},
				},
				{
					APIGroups: []string{"monitoring.coreos.com"},
					Resources: []string{"prometheusrules"},
					Verbs:     []string{"get", "list", "watch"},
				},
				{
					APIGroups: []string{"monitoring.coreos.com"},
					Resources: []string{"servicemonitors"},
					Verbs:     []string{"create", "delete", "get", "list", "patch", "update", "watch"},
				},
				{
					APIGroups: []string{"monitoring.thanos.io"},
					Resources: []string{"thanoscompacts", "thanosqueries", "thanosreceives", "thanosrulers", "thanosstores"},
					Verbs:     []string{"create", "delete", "get", "list", "patch", "update", "watch"},
				},
				{
					APIGroups: []string{"monitoring.thanos.io"},
					Resources: []string{
						"thanoscompacts/finalizers",
						"thanosqueries/finalizers",
						"thanosreceives/finalizers",
						"thanosrulers/finalizers",
						"thanosstores/finalizers",
					},
					Verbs: []string{"update"},
				},
				{
					APIGroups: []string{"monitoring.thanos.io"},
					Resources: []string{
						"thanoscompacts/status",
						"thanosqueries/status",
						"thanosreceives/status",
						"thanosrulers/status",
						"thanosstores/status",
					},
					Verbs: []string{"get", "patch", "update"},
				},
				{
					APIGroups: []string{"policy"},
					Resources: []string{"poddisruptionbudgets"},
					Verbs:     []string{"create", "get", "list", "update", "watch"},
				},
			},
		},

		// Metrics Reader ClusterRole
		&rbacv1.ClusterRole{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "rbac.authorization.k8s.io/v1",
				Kind:       "ClusterRole",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name: "thanos-operator-metrics-reader",
				Labels: map[string]string{
					"app.kubernetes.io/component":  "kube-rbac-proxy",
					"app.kubernetes.io/created-by": "thanos-operator",
					"app.kubernetes.io/instance":   "metrics-reader",
					"app.kubernetes.io/managed-by": "rhobs",
					"app.kubernetes.io/name":       "clusterrole",
					"app.kubernetes.io/part-of":    "thanos-operator",
				},
			},
			Rules: []rbacv1.PolicyRule{
				{
					NonResourceURLs: []string{"/metrics"},
					Verbs:           []string{"get"},
				},
			},
		},

		// Proxy ClusterRole
		&rbacv1.ClusterRole{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "rbac.authorization.k8s.io/v1",
				Kind:       "ClusterRole",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name: "thanos-operator-proxy-role",
				Labels: map[string]string{
					"app.kubernetes.io/component":  "kube-rbac-proxy",
					"app.kubernetes.io/created-by": "thanos-operator",
					"app.kubernetes.io/instance":   "proxy-role",
					"app.kubernetes.io/managed-by": "rhobs",
					"app.kubernetes.io/name":       "clusterrole",
					"app.kubernetes.io/part-of":    "thanos-operator",
				},
			},
			Rules: []rbacv1.PolicyRule{
				{
					APIGroups: []string{"authentication.k8s.io"},
					Resources: []string{"tokenreviews"},
					Verbs:     []string{"create"},
				},
				{
					APIGroups: []string{"authorization.k8s.io"},
					Resources: []string{"subjectaccessreviews"},
					Verbs:     []string{"create"},
				},
			},
		},

		// Thanos Compact Editor ClusterRole
		&rbacv1.ClusterRole{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "rbac.authorization.k8s.io/v1",
				Kind:       "ClusterRole",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name: "thanos-operator-thanoscompact-editor-role",
				Labels: map[string]string{
					"app.kubernetes.io/managed-by": "rhobs",
					"app.kubernetes.io/name":       "thanos-operator",
				},
			},
			Rules: []rbacv1.PolicyRule{
				{
					APIGroups: []string{"monitoring.thanos.io"},
					Resources: []string{"thanoscompacts"},
					Verbs:     []string{"create", "delete", "get", "list", "patch", "update", "watch"},
				},
				{
					APIGroups: []string{"monitoring.thanos.io"},
					Resources: []string{"thanoscompacts/status"},
					Verbs:     []string{"get"},
				},
			},
		},

		// Thanos Compact Viewer ClusterRole
		&rbacv1.ClusterRole{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "rbac.authorization.k8s.io/v1",
				Kind:       "ClusterRole",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name: "thanos-operator-thanoscompact-viewer-role",
				Labels: map[string]string{
					"app.kubernetes.io/managed-by": "rhobs",
					"app.kubernetes.io/name":       "thanos-operator",
				},
			},
			Rules: []rbacv1.PolicyRule{
				{
					APIGroups: []string{"monitoring.thanos.io"},
					Resources: []string{"thanoscompacts"},
					Verbs:     []string{"get", "list", "watch"},
				},
				{
					APIGroups: []string{"monitoring.thanos.io"},
					Resources: []string{"thanoscompacts/status"},
					Verbs:     []string{"get"},
				},
			},
		},

		// Thanos Receive Editor ClusterRole
		&rbacv1.ClusterRole{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "rbac.authorization.k8s.io/v1",
				Kind:       "ClusterRole",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name: "thanos-operator-thanosreceive-editor-role",
				Labels: map[string]string{
					"app.kubernetes.io/managed-by": "rhobs",
					"app.kubernetes.io/name":       "thanos-operator",
				},
			},
			Rules: []rbacv1.PolicyRule{
				{
					APIGroups: []string{"monitoring.thanos.io"},
					Resources: []string{"thanosreceives"},
					Verbs:     []string{"create", "delete", "get", "list", "patch", "update", "watch"},
				},
				{
					APIGroups: []string{"monitoring.thanos.io"},
					Resources: []string{"thanosreceives/status"},
					Verbs:     []string{"get"},
				},
			},
		},

		// Thanos Receive Viewer ClusterRole
		&rbacv1.ClusterRole{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "rbac.authorization.k8s.io/v1",
				Kind:       "ClusterRole",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name: "thanos-operator-thanosreceive-viewer-role",
				Labels: map[string]string{
					"app.kubernetes.io/managed-by": "rhobs",
					"app.kubernetes.io/name":       "thanos-operator",
				},
			},
			Rules: []rbacv1.PolicyRule{
				{
					APIGroups: []string{"monitoring.thanos.io"},
					Resources: []string{"thanosreceives"},
					Verbs:     []string{"get", "list", "watch"},
				},
				{
					APIGroups: []string{"monitoring.thanos.io"},
					Resources: []string{"thanosreceives/status"},
					Verbs:     []string{"get"},
				},
			},
		},

		// Leader Election RoleBinding
		&rbacv1.RoleBinding{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "rbac.authorization.k8s.io/v1",
				Kind:       "RoleBinding",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-operator-leader-election-rolebinding",
				Namespace: namespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "rbac",
					"app.kubernetes.io/created-by": "thanos-operator",
					"app.kubernetes.io/instance":   "leader-election-rolebinding",
					"app.kubernetes.io/managed-by": "rhobs",
					"app.kubernetes.io/name":       "rolebinding",
					"app.kubernetes.io/part-of":    "thanos-operator",
				},
			},
			RoleRef: rbacv1.RoleRef{
				APIGroup: "rbac.authorization.k8s.io",
				Kind:     "Role",
				Name:     "thanos-operator-leader-election-role",
			},
			Subjects: []rbacv1.Subject{
				{
					Kind:      "ServiceAccount",
					Name:      "thanos-operator-controller-manager",
					Namespace: namespace,
				},
			},
		},

		// Metrics Service
		&corev1.Service{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "v1",
				Kind:       "Service",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-operator-controller-manager-metrics-service",
				Namespace: namespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "kube-rbac-proxy",
					"app.kubernetes.io/created-by": "thanos-operator",
					"app.kubernetes.io/instance":   "controller-manager-metrics-service",
					"app.kubernetes.io/managed-by": "rhobs",
					"app.kubernetes.io/name":       "service",
					"app.kubernetes.io/part-of":    "thanos-operator",
					"control-plane":                "controller-manager",
				},
			},
			Spec: corev1.ServiceSpec{
				Ports: []corev1.ServicePort{
					{
						Name:       "https",
						Port:       8443,
						Protocol:   corev1.ProtocolTCP,
						TargetPort: intstr.FromString("https"),
					},
				},
				Selector: map[string]string{
					"control-plane": "controller-manager",
				},
			},
		},

		// Manager RoleBinding
		&rbacv1.ClusterRoleBinding{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "rbac.authorization.k8s.io/v1",
				Kind:       "ClusterRoleBinding",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-operator-manager-rolebinding",
				Namespace: namespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "rbac",
					"app.kubernetes.io/created-by": "thanos-operator",
					"app.kubernetes.io/instance":   "manager-rolebinding",
					"app.kubernetes.io/managed-by": "rhobs",
					"app.kubernetes.io/name":       "clusterrolebinding",
					"app.kubernetes.io/part-of":    "thanos-operator",
				},
			},
			RoleRef: rbacv1.RoleRef{
				APIGroup: "rbac.authorization.k8s.io",
				Kind:     "ClusterRole",
				Name:     "thanos-operator-manager-role",
			},
			Subjects: []rbacv1.Subject{
				{
					Kind:      "ServiceAccount",
					Name:      "thanos-operator-controller-manager",
					Namespace: namespace,
				},
			},
		},

		// Proxy RoleBinding
		&rbacv1.ClusterRoleBinding{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "rbac.authorization.k8s.io/v1",
				Kind:       "ClusterRoleBinding",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      "thanos-operator-proxy-rolebinding",
				Namespace: namespace,
				Labels: map[string]string{
					"app.kubernetes.io/component":  "kube-rbac-proxy",
					"app.kubernetes.io/created-by": "thanos-operator",
					"app.kubernetes.io/instance":   "proxy-rolebinding",
					"app.kubernetes.io/managed-by": "rhobs",
					"app.kubernetes.io/name":       "clusterrolebinding",
					"app.kubernetes.io/part-of":    "thanos-operator",
				},
			},
			RoleRef: rbacv1.RoleRef{
				APIGroup: "rbac.authorization.k8s.io",
				Kind:     "ClusterRole",
				Name:     "thanos-operator-proxy-role",
			},
			Subjects: []rbacv1.Subject{
				{
					Kind:      "ServiceAccount",
					Name:      "thanos-operator-controller-manager",
					Namespace: namespace,
				},
			},
		},

		// Deployment
		operatorDeployment(namespace, m),
	}
}

func operatorDeployment(namespace string, m TemplateMaps) *appsv1.Deployment {
	return &appsv1.Deployment{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "apps/v1",
			Kind:       "Deployment",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "thanos-operator-controller-manager",
			Namespace: namespace,
			Labels: map[string]string{
				"app.kubernetes.io/component":  "manager",
				"app.kubernetes.io/created-by": "thanos-operator",
				"app.kubernetes.io/instance":   "controller-manager",
				"app.kubernetes.io/managed-by": "rhobs",
				"app.kubernetes.io/name":       "deployment",
				"app.kubernetes.io/part-of":    "thanos-operator",
				"control-plane":                "controller-manager",
			},
		},
		Spec: appsv1.DeploymentSpec{
			Replicas:             ptr.To(int32(1)),
			RevisionHistoryLimit: ptr.To(int32(10)),
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"control-plane": "controller-manager",
				},
			},
			Strategy: appsv1.DeploymentStrategy{
				Type: appsv1.RollingUpdateDeploymentStrategyType,
				RollingUpdate: &appsv1.RollingUpdateDeployment{
					MaxSurge:       &intstr.IntOrString{Type: intstr.String, StrVal: "25%"},
					MaxUnavailable: &intstr.IntOrString{Type: intstr.String, StrVal: "25%"},
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"control-plane": "controller-manager",
					},
					Annotations: map[string]string{
						"kubectl.kubernetes.io/default-container": "manager",
					},
				},
				Spec: corev1.PodSpec{
					SecurityContext: &corev1.PodSecurityContext{
						RunAsNonRoot: ptr.To(true),
					},
					Containers: []corev1.Container{
						{
							Name:            "kube-rbac-proxy",
							Image:           TemplateFn("KUBE_RBAC_PROXY", m.Images),
							ImagePullPolicy: corev1.PullIfNotPresent,
							Args: []string{
								"--secure-listen-address=0.0.0.0:8443",
								"--upstream=http://127.0.0.1:8080/",
								"--logtostderr=true",
								"--v=0",
							},
							Ports: []corev1.ContainerPort{
								{
									ContainerPort: 8443,
									Name:          "https",
									Protocol:      corev1.ProtocolTCP,
								},
							},
							Resources: TemplateFn("KUBE_RBAC_PROXY", m.ResourceRequirements),
							SecurityContext: &corev1.SecurityContext{
								AllowPrivilegeEscalation: ptr.To(false),
								Capabilities: &corev1.Capabilities{
									Drop: []corev1.Capability{"ALL"},
								},
							},
						},
						{
							Name:            "manager",
							Image:           TemplateFn("THANOS_OPERATOR", m.Images),
							ImagePullPolicy: corev1.PullIfNotPresent,
							Command:         []string{"/manager"},
							Args: []string{
								"--health-probe-bind-address=:8081",
								"--metrics-bind-address=127.0.0.1:8080",
								"--leader-elect",
								"--zap-encoder=console",
								"--zap-log-level=debug",
							},
							LivenessProbe: &corev1.Probe{
								ProbeHandler: corev1.ProbeHandler{
									HTTPGet: &corev1.HTTPGetAction{
										Path:   "/healthz",
										Port:   intstr.FromInt(8081),
										Scheme: corev1.URISchemeHTTP,
									},
								},
								InitialDelaySeconds: 15,
								PeriodSeconds:       20,
								TimeoutSeconds:      1,
								FailureThreshold:    3,
								SuccessThreshold:    1,
							},
							ReadinessProbe: &corev1.Probe{
								ProbeHandler: corev1.ProbeHandler{
									HTTPGet: &corev1.HTTPGetAction{
										Path:   "/readyz",
										Port:   intstr.FromInt(8081),
										Scheme: corev1.URISchemeHTTP,
									},
								},
								InitialDelaySeconds: 5,
								PeriodSeconds:       10,
								TimeoutSeconds:      1,
								FailureThreshold:    3,
								SuccessThreshold:    1,
							},
							Resources: TemplateFn("MANAGER", m.ResourceRequirements),
							SecurityContext: &corev1.SecurityContext{
								AllowPrivilegeEscalation: ptr.To(false),
								Capabilities: &corev1.Capabilities{
									Drop: []corev1.Capability{"ALL"},
								},
							},
						},
					},
					ServiceAccountName:            "thanos-operator-controller-manager",
					TerminationGracePeriodSeconds: ptr.To(int64(10)),
				},
			},
		},
	}
}
