package main

import (
	"fmt"
	"os"

	"github.com/go-kit/log"
	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic"
	"github.com/philipgough/mimic/encoding"
	"github.com/rhobs/configuration/clusters"
	"github.com/rhobs/configuration/internal/submodule"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/intstr"
	"k8s.io/utils/ptr"
)

// PersesOperatorCRDS Generates the CRDs for the Perses operator.
// This is synced from the ref persesOperatorRef at https://gitlab.cee.redhat.com/openshift-logging/konflux-log-storage
func (b Build) PersesOperatorCRDS(config clusters.ClusterConfig) error {
	gen := b.generator(config, "perses-operator-crds")
	return persesCRD(gen, clusters.ProductionMaps)
}

func persesCRD(gen *mimic.Generator, templates clusters.TemplateMaps) error {
	const (
		repoURL       = "https://github.com/rhobs/rhobs-konflux-perses"
		submodulePath = "perses-operator"
		yamlPATH      = "config/crd/bases"
	)

	// Use the Info struct and Parse method from fetch.go
	info := submodule.Info{
		Commit:        clusters.TemplateFn(clusters.PersesOperator, templates.Versions),
		SubmodulePath: submodulePath,
		URL:           repoURL,
		PathToYAMLS:   yamlPATH,
	}

	objs, err := info.FetchYAMLs()
	if err != nil {
		return fmt.Errorf("Error fetching YAML files: %v\n", err)
	}

	logger := log.NewLogfmtLogger(log.NewSyncWriter(os.Stdout))
	_ = logger.Log("msg", "Successfully fetched CRD objects", "count", len(objs))

	gen.Add("crds.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			objs,
			metav1.ObjectMeta{Name: "perses-operator-crds"},
			[]templatev1.Parameter{},
		),
	))
	gen.Generate()
	return nil
}

func (b Build) PersesOperator(config clusters.ClusterConfig) {
	gen := b.generator(config, "perses-operator")

	objs := persesOperatorResources(config.Namespace, clusters.ProductionMaps)

	gen.Add("perses-operator.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(objs, metav1.ObjectMeta{Name: "perses-operator-manager"}, []templatev1.Parameter{}),
	))
	gen.Generate()
}

func persesOperatorResources(namespace string, m clusters.TemplateMaps) []runtime.Object {
	objs := []runtime.Object{
		NewPersesControllerManagerDeployment(namespace, m),
		NewPersesOperatorMetricsService(namespace),
		NewPersesServiceAccountControllerManager(namespace),
		NewPersesOperatorManagerClusterRole(),
		NewPersesMetricsReaderClusterRole(),
		NewPersesProxyClusterRole(),
		NewPersesManagerClusterRoleBinding(namespace),
		NewPersesProxyClusterRoleBinding(namespace),
		NewPersesLeaderElectionRole(namespace),
		NewPersesLeaderElectionRoleBinding(namespace),
		NewPersesPersesEditorClusterRole(),
		NewPersesPersesViewerClusterRole(),
		NewPersesDashboardEditorClusterRole(),
		NewPersesDashboardViewerClusterRole(),
		NewPersesDatasourceEditorClusterRole(),
		NewPersesDatasourceViewerClusterRole(),
	}
	return objs
}

// NewControllerManagerDeployment returns the Deployment for the operator controller-manager.
// Corresponds to manager.yaml.
func NewPersesControllerManagerDeployment(namespace string, m clusters.TemplateMaps) *appsv1.Deployment {
	return &appsv1.Deployment{
		TypeMeta: metav1.TypeMeta{
			APIVersion: appsv1.SchemeGroupVersion.String(),
			Kind:       "Deployment",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "perses-operator-controller-manager",
			Namespace: namespace,
			Labels: map[string]string{
				"app.kubernetes.io/component":  "manager",
				"app.kubernetes.io/created-by": "perses-operator",
				"app.kubernetes.io/instance":   "controller-manager",
				"app.kubernetes.io/name":       "deployment",
				"app.kubernetes.io/part-of":    "perses-operator",
				"control-plane":                "controller-manager",
			},
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: ptr.To(clusters.TemplateFn(clusters.PersesOperator, m.Replicas)),
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"control-plane": "controller-manager",
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Annotations: map[string]string{
						"kubectl.kubernetes.io/default-container": "manager",
					},
					Labels: map[string]string{
						"control-plane": "controller-manager",
					},
				},
				Spec: corev1.PodSpec{
					ServiceAccountName:            "perses-operator-controller-manager",
					TerminationGracePeriodSeconds: ptr.To(int64(10)),
					Affinity: &corev1.Affinity{
						NodeAffinity: &corev1.NodeAffinity{
							RequiredDuringSchedulingIgnoredDuringExecution: &corev1.NodeSelector{
								NodeSelectorTerms: []corev1.NodeSelectorTerm{
									{
										MatchExpressions: []corev1.NodeSelectorRequirement{
											{
												Key:      "kubernetes.io/arch",
												Operator: corev1.NodeSelectorOpIn,
												Values:   []string{"amd64", "arm64", "ppc64le", "s390x"},
											},
											{
												Key:      "kubernetes.io/os",
												Operator: corev1.NodeSelectorOpIn,
												Values:   []string{"linux"},
											},
										},
									},
								},
							},
						},
					},
					Containers: []corev1.Container{
						{
							Name:  "kube-rbac-proxy",
							Image: clusters.TemplateFn(clusters.KubeRbacProxy, m.Images),
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
							Resources: clusters.TemplateFn(clusters.KubeRbacProxy, m.ResourceRequirements),
							SecurityContext: &corev1.SecurityContext{
								AllowPrivilegeEscalation: ptr.To(false),
								Capabilities: &corev1.Capabilities{
									Drop: []corev1.Capability{"ALL"},
								},
							},
						},
						{
							Name:            "manager",
							Image:           clusters.TemplateFn(clusters.PersesOperator, m.Images),
							ImagePullPolicy: corev1.PullAlways,
							Args: []string{
								"--health-probe-bind-address=:8081",
								"--metrics-bind-address=127.0.0.1:8082",
								"--leader-elect",
							},
							LivenessProbe: &corev1.Probe{
								ProbeHandler: corev1.ProbeHandler{
									HTTPGet: &corev1.HTTPGetAction{
										Path: "/healthz",
										Port: intstr.FromInt(8081),
									},
								},
								InitialDelaySeconds: 15,
								PeriodSeconds:       20,
							},
							ReadinessProbe: &corev1.Probe{
								ProbeHandler: corev1.ProbeHandler{
									HTTPGet: &corev1.HTTPGetAction{
										Path: "/readyz",
										Port: intstr.FromInt(8081),
									},
								},
								InitialDelaySeconds: 5,
								PeriodSeconds:       10,
							},
							Resources: clusters.TemplateFn(clusters.PersesOperator, m.ResourceRequirements),
							SecurityContext: &corev1.SecurityContext{
								AllowPrivilegeEscalation: ptr.To(false),
								Capabilities: &corev1.Capabilities{
									Drop: []corev1.Capability{"ALL"},
								},
							},
						},
					},
				},
			},
		},
	}
}

func NewPersesOperatorMetricsService(namespace string) *corev1.Service {
	return &corev1.Service{
		TypeMeta: metav1.TypeMeta{
			APIVersion: corev1.SchemeGroupVersion.String(),
			Kind:       "Service",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "perses-operator-controller-manager-metrics-service",
			Namespace: namespace,
			Labels: map[string]string{
				"app.kubernetes.io/component":  "kube-rbac-proxy",
				"app.kubernetes.io/created-by": "perses-operator",
				"app.kubernetes.io/instance":   "controller-manager-metrics-service",
				"app.kubernetes.io/name":       "service",
				"app.kubernetes.io/part-of":    "perses-operator",
				"control-plane":                "controller-manager",
			},
		},
		Spec: corev1.ServiceSpec{
			Selector: map[string]string{
				"control-plane": "controller-manager",
			},
			Ports: []corev1.ServicePort{
				{
					Name:       "https",
					Port:       8443,
					Protocol:   corev1.ProtocolTCP,
					TargetPort: intstr.FromInt(8443),
				},
			},
		},
	}
}

// NewServiceAccountControllerManager returns the ServiceAccount for the controller-manager.
// Corresponds to serviceaccount.yaml.
func NewPersesServiceAccountControllerManager(namespace string) *corev1.ServiceAccount {
	return &corev1.ServiceAccount{
		TypeMeta: metav1.TypeMeta{
			APIVersion: corev1.SchemeGroupVersion.String(),
			Kind:       "ServiceAccount",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "perses-operator-controller-manager",
			Namespace: namespace,
			Labels: map[string]string{
				"app.kubernetes.io/component":  "rbac",
				"app.kubernetes.io/created-by": "perses-operator",
				"app.kubernetes.io/instance":   "controller-manager",
				"app.kubernetes.io/name":       "serviceaccount",
				"app.kubernetes.io/part-of":    "perses-operator",
			},
		},
	}
}

// NewPersesOperatorManagerClusterRole returns the ClusterRole for perses-operator-manager.
// Corresponds to role.yaml.
func NewPersesOperatorManagerClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRole",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "perses-operator-manager-role",
		},
		Rules: []rbacv1.PolicyRule{
			{
				APIGroups: []string{"apps"},
				Resources: []string{"deployments", "statefulsets"},
				Verbs:     []string{"create", "delete", "get", "list", "patch", "update", "watch"},
			},
			{
				APIGroups: []string{""},
				Resources: []string{"events"},
				Verbs:     []string{"create", "patch"},
			},
			{
				APIGroups: []string{""},
				Resources: []string{"services", "configmaps", "secrets"},
				Verbs:     []string{"get", "patch", "update", "create", "delete", "list", "watch"},
			},
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"perses"},
				Verbs:     []string{"create", "delete", "get", "list", "patch", "update", "watch"},
			},
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"perses/finalizers"},
				Verbs:     []string{"update"},
			},
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"perses/status"},
				Verbs:     []string{"get", "patch", "update"},
			},
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"persesdashboards"},
				Verbs:     []string{"create", "delete", "get", "list", "patch", "update", "watch"},
			},
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"persesdashboards/finalizers"},
				Verbs:     []string{"update"},
			},
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"persesdashboards/status"},
				Verbs:     []string{"get", "patch", "update"},
			},
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"persesdatasources"},
				Verbs:     []string{"create", "delete", "get", "list", "patch", "update", "watch"},
			},
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"persesdatasources/finalizers"},
				Verbs:     []string{"update"},
			},
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"persesdatasources/status"},
				Verbs:     []string{"get", "patch", "update"},
			},
		},
	}
}

// NewPersesMetricsReaderClusterRole returns the ClusterRoleBinding for perses-metrics-reader.
func NewPersesMetricsReaderClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRole",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "perses-operator-metrics-reader",
			Labels: map[string]string{
				"app.kubernetes.io/component":  "kube-rbac-proxy",
				"app.kubernetes.io/created-by": "perses-operator",
				"app.kubernetes.io/instance":   "metrics-reader",
				"app.kubernetes.io/name":       "clusterrole",
				"app.kubernetes.io/part-of":    "perses-operator",
			},
		},
		Rules: []rbacv1.PolicyRule{
			{
				NonResourceURLs: []string{"/metrics"},
				Verbs:           []string{"get"},
			},
		},
	}
}

// NewPersesProxyClusterRole returns the ClusterRole for perses-proxy.
func NewPersesProxyClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRole",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "perses-operator-proxy-role",
			Labels: map[string]string{
				"app.kubernetes.io/component":  "kube-rbac-proxy",
				"app.kubernetes.io/created-by": "perses-operator",
				"app.kubernetes.io/instance":   "proxy-role",
				"app.kubernetes.io/name":       "clusterrole",
				"app.kubernetes.io/part-of":    "perses-operator",
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
	}
}

// NewPersesManagerClusterRoleBinding returns the ClusterRoleBinding for perses-manager.
func NewPersesManagerClusterRoleBinding(namespace string) *rbacv1.ClusterRoleBinding {
	return &rbacv1.ClusterRoleBinding{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRoleBinding",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "perses-operator-manager-rolebinding",
			Labels: map[string]string{
				"app.kubernetes.io/component":  "rbac",
				"app.kubernetes.io/created-by": "perses-operator",
				"app.kubernetes.io/instance":   "manager-rolebinding",
				"app.kubernetes.io/name":       "clusterrolebinding",
				"app.kubernetes.io/part-of":    "perses-operator",
			},
		},
		RoleRef: rbacv1.RoleRef{
			APIGroup: rbacv1.SchemeGroupVersion.Group,
			Kind:     "ClusterRole",
			Name:     "perses-operator-manager-role",
		},
		Subjects: []rbacv1.Subject{
			{
				Kind:      "ServiceAccount",
				Name:      "perses-operator-controller-manager",
				Namespace: namespace,
			},
		},
	}
}

// NewPersesManagerClusterRoleBinding returns the ClusterRoleBinding for perses-manager.
func NewPersesProxyClusterRoleBinding(namespace string) *rbacv1.ClusterRoleBinding {
	return &rbacv1.ClusterRoleBinding{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRoleBinding",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "perses-operator-proxy-rolebinding",
			Labels: map[string]string{
				"app.kubernetes.io/component":  "rbac",
				"app.kubernetes.io/created-by": "perses-operator",
				"app.kubernetes.io/instance":   "manager-rolebinding",
				"app.kubernetes.io/name":       "clusterrolebinding",
				"app.kubernetes.io/part-of":    "perses-operator",
			},
		},
		RoleRef: rbacv1.RoleRef{
			APIGroup: rbacv1.SchemeGroupVersion.Group,
			Kind:     "ClusterRole",
			Name:     "perses-operator-proxy-role",
		},
		Subjects: []rbacv1.Subject{
			{
				Kind:      "ServiceAccount",
				Name:      "perses-operator-controller-manager",
				Namespace: namespace,
			},
		},
	}
}

func NewPersesLeaderElectionRole(namespace string) *rbacv1.Role {
	return &rbacv1.Role{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "Role",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "perses-operator-leader-election-role",
			Namespace: namespace,
			Labels: map[string]string{
				"app.kubernetes.io/component":  "rbac",
				"app.kubernetes.io/created-by": "perses-operator",
				"app.kubernetes.io/instance":   "leader-election-role",
				"app.kubernetes.io/name":       "role",
				"app.kubernetes.io/part-of":    "perses-operator",
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
	}
}

func NewPersesLeaderElectionRoleBinding(namespace string) *rbacv1.RoleBinding {
	return &rbacv1.RoleBinding{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "RoleBinding",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "perses-operator-leader-election-rolebinding",
			Namespace: namespace,
			Labels: map[string]string{
				"app.kubernetes.io/component":  "rbac",
				"app.kubernetes.io/created-by": "perses-operator",
				"app.kubernetes.io/instance":   "leader-election-rolebinding",
				"app.kubernetes.io/name":       "rolebinding",
				"app.kubernetes.io/part-of":    "perses-operator",
			},
		},
		RoleRef: rbacv1.RoleRef{
			APIGroup: rbacv1.SchemeGroupVersion.Group,
			Kind:     "Role",
			Name:     "perses-operator-leader-election-role",
		},
		Subjects: []rbacv1.Subject{
			{
				Kind:      "ServiceAccount",
				Name:      "perses-operator-controller-manager",
				Namespace: namespace,
			},
		},
	}
}

func NewPersesPersesEditorClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRole",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "perses-operator-perses-editor-role",
			Labels: map[string]string{
				"app.kubernetes.io/component":  "rbac",
				"app.kubernetes.io/created-by": "perses-operator",
				"app.kubernetes.io/instance":   "perses-editor-role",
				"app.kubernetes.io/name":       "clusterrole",
				"app.kubernetes.io/part-of":    "perses-operator",
			},
		},
		Rules: []rbacv1.PolicyRule{
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"perses"},
				Verbs:     []string{"create", "delete", "get", "list", "patch", "update", "watch"},
			},
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"perses/status"},
				Verbs:     []string{"get"},
			},
		},
	}
}

func NewPersesPersesViewerClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRole",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "perses-operator-perses-viewer-role",
			Labels: map[string]string{
				"app.kubernetes.io/component":  "rbac",
				"app.kubernetes.io/created-by": "perses-operator",
				"app.kubernetes.io/instance":   "perses-viewer-role",
				"app.kubernetes.io/name":       "clusterrole",
				"app.kubernetes.io/part-of":    "perses-operator",
			},
		},
		Rules: []rbacv1.PolicyRule{
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"perses"},
				Verbs:     []string{"get", "list", "watch"},
			},
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"perses/status"},
				Verbs:     []string{"get"},
			},
		},
	}
}

func NewPersesDashboardEditorClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRole",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "perses-operator-persesdashboard-editor-role",
			Labels: map[string]string{
				"app.kubernetes.io/component":  "rbac",
				"app.kubernetes.io/created-by": "perses-operator",
				"app.kubernetes.io/instance":   "persesdashboard-editor-role",
				"app.kubernetes.io/name":       "clusterrole",
				"app.kubernetes.io/part-of":    "perses-operator",
			},
		},
		Rules: []rbacv1.PolicyRule{
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"persesdashboards"},
				Verbs:     []string{"create", "delete", "get", "list", "patch", "update", "watch"},
			},
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"persesdashboards/status"},
				Verbs:     []string{"get"},
			},
		},
	}
}

func NewPersesDashboardViewerClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRole",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "perses-operator-persesdashboard-viewer-role",
			Labels: map[string]string{
				"app.kubernetes.io/component":  "rbac",
				"app.kubernetes.io/created-by": "perses-operator",
				"app.kubernetes.io/instance":   "persesdashboard-viewer-role",
				"app.kubernetes.io/name":       "clusterrole",
				"app.kubernetes.io/part-of":    "perses-operator",
			},
		},
		Rules: []rbacv1.PolicyRule{
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"persesdashboards"},
				Verbs:     []string{"get", "list", "watch"},
			},
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"persesdashboards/status"},
				Verbs:     []string{"get"},
			},
		},
	}
}

func NewPersesDatasourceEditorClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRole",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "perses-operator-persesdatasource-editor-role",
			Labels: map[string]string{
				"app.kubernetes.io/component":  "rbac",
				"app.kubernetes.io/created-by": "perses-operator",
				"app.kubernetes.io/instance":   "persesdatasource-editor-role",
				"app.kubernetes.io/name":       "clusterrole",
				"app.kubernetes.io/part-of":    "perses-operator",
			},
		},
		Rules: []rbacv1.PolicyRule{
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"persesdatasources"},
				Verbs:     []string{"create", "delete", "get", "list", "patch", "update", "watch"},
			},
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"persesdatasources/status"},
				Verbs:     []string{"get"},
			},
		},
	}
}

func NewPersesDatasourceViewerClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRole",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "perses-operator-persesdatasource-viewer-role",
			Labels: map[string]string{
				"app.kubernetes.io/component":  "rbac",
				"app.kubernetes.io/created-by": "perses-operator",
				"app.kubernetes.io/instance":   "persesdatasource-viewer-role",
				"app.kubernetes.io/name":       "clusterrole",
				"app.kubernetes.io/part-of":    "perses-operator",
			},
		},
		Rules: []rbacv1.PolicyRule{
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"persesdatasources"},
				Verbs:     []string{"get", "list", "watch"},
			},
			{
				APIGroups: []string{"perses.dev"},
				Resources: []string{"persesdatasources/status"},
				Verbs:     []string{"get"},
			},
		},
	}
}
