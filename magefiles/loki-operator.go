package main

import (
	"fmt"

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

const (
	lokiOperatorImage = "quay.io/redhat-user-workloads/obs-logging-tenant/loki-operator-v6-3"
	lokiRef           = "ab233daeab6b9808a6c216c75cc5db449486f87e"
)

// LokiOperatorCRDS Generates the CRDs for the Loki operator.
// This is synced from the ref lokiRef at https://gitlab.cee.redhat.com/openshift-logging/konflux-log-storage
func (b Build) LokiOperatorCRDS(config clusters.ClusterConfig) error {
	gen := b.generator(config, "loki-operator-crds")
	return lokiCRD(gen, clusters.ProductionMaps)
}

func lokiCRD(gen *mimic.Generator, templates clusters.TemplateMaps) error {
	repoURL := "https://gitlab.cee.redhat.com/openshift-logging/konflux-log-storage"
	submodulePath := "loki-operator"
	yamlPATH := "operator/config/crd/bases"

	// Use the Info struct and Parse method from fetch.go
	info := submodule.Info{
		Commit:        lokiRef,
		SubmodulePath: submodulePath,
		URL:           repoURL,
		PathToYAMLS:   yamlPATH,
	}

	objs, err := info.FetchYAMLs()
	if err != nil {
		return fmt.Errorf("Error fetching YAML files: %v\n", err)
	}

	fmt.Printf("Successfully fetched %d CRD objects\n", len(objs))

	gen.Add("crds.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			objs,
			metav1.ObjectMeta{Name: "loki-operator-crds"},
			[]templatev1.Parameter{},
		),
	))
	gen.Generate()
	return nil
}

func (b Build) LokiOperator(config clusters.ClusterConfig) {
	gen := b.generator(config, "loki-operator")

	objs := lokiOperatorResources(config.Namespace)

	gen.Add("loki-operator.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(objs, metav1.ObjectMeta{Name: "loki-operator-manager"}, []templatev1.Parameter{}),
	))
	gen.Generate()
}

func lokiOperatorResources(namespace string) []runtime.Object {
	objs := []runtime.Object{
		NewControllerManagerDeployment(namespace),
		NewServiceAccountControllerManager(namespace),
		NewClusterRoleLokiStackManager(),
		NewClusterRoleBindingLokiStackManager(namespace),
		NewLokiStackEditorClusterRole(),
		NewLokiStackViewerClusterRole(),
		NewRulerConfigViewerClusterRole(),
		NewRulerConfigEditorClusterRole(),
		NewRecordingRuleViewerClusterRole(),
		NewRecordingRuleEditorClusterRole(),
		NewAlertingRuleViewerClusterRole(),
		NewAlertingRuleEditorClusterRole(),
		NewPrometheusRole(namespace),
		NewPrometheusRoleBinding(namespace),
		NewLeaderElectionRole(namespace),
		NewLeaderElectionRoleBinding(namespace),
		NewAuthProxyClientServiceAccount(namespace),
		NewAuthProxyClientClusterRole(),
		NewAuthProxyClientClusterRoleBinding(namespace),
		NewAuthProxyRole(),
		NewAuthProxyRoleBinding(namespace),
		NewAuthProxyService(namespace),
	}
	return objs
}

// NewControllerManagerDeployment returns the Deployment for the operator controller-manager.
// Corresponds to manager.yaml.
func NewControllerManagerDeployment(namespace string) *appsv1.Deployment {
	return &appsv1.Deployment{
		TypeMeta: metav1.TypeMeta{
			APIVersion: appsv1.SchemeGroupVersion.String(),
			Kind:       "Deployment",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "loki-operator",
			Namespace: namespace,
			Labels:    map[string]string{"control-plane": "controller-manager"},
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: ptr.To(int32(1)),
			Selector: &metav1.LabelSelector{MatchLabels: map[string]string{"name": "loki-operator-controller-manager"}},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Annotations: map[string]string{"kubectl.kubernetes.io/default-container": "manager"},
					Labels:      map[string]string{"name": "loki-operator-controller-manager"},
				},
				Spec: corev1.PodSpec{
					ServiceAccountName: "loki-controller-manager",
					NodeSelector:       map[string]string{"kubernetes.io/os": "linux"},
					Containers: []corev1.Container{{
						Name:            "manager",
						Image:           fmt.Sprintf("%s:%s", lokiOperatorImage, lokiRef),
						ImagePullPolicy: corev1.PullIfNotPresent,
						Command:         []string{"/manager"},
						Ports:           []corev1.ContainerPort{{Name: "metrics", ContainerPort: 8080}},
					}},
					TerminationGracePeriodSeconds: ptr.To(int64(10)),
				},
			},
		},
	}
}

// NewServiceAccountControllerManager returns the ServiceAccount for the controller-manager.
// Corresponds to serviceaccount.yaml.
func NewServiceAccountControllerManager(namespace string) *corev1.ServiceAccount {
	return &corev1.ServiceAccount{
		TypeMeta: metav1.TypeMeta{
			APIVersion: corev1.SchemeGroupVersion.String(),
			Kind:       "ServiceAccount",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "loki-controller-manager",
			Namespace: namespace,
		},
	}
}

// NewClusterRoleLokiStackManager returns the ClusterRole for lokistack-manager.
// Corresponds to role.yaml.
func NewClusterRoleLokiStackManager() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRole",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "loki-lokistack-manager",
		},
		Rules: []rbacv1.PolicyRule{
			{
				NonResourceURLs: []string{"/api/v2/alerts"},
				Verbs:           []string{"create"},
			},
			// Core Kubernetes resources
			{
				APIGroups: []string{""},
				Resources: []string{
					"configmaps",
					"endpoints",
					"nodes",
					"serviceaccounts",
					"services",
					"secrets",
					"pods",
					"namespaces",
				},
				Verbs: []string{"get", "list", "watch", "create", "update", "patch", "delete"},
			},
			// Core Kubernetes resources finalizers
			{
				APIGroups: []string{""},
				Resources: []string{
					"configmaps/finalizers",
					"serviceaccounts/finalizers",
					"services/finalizers",
					"secrets/finalizers",
				},
				Verbs: []string{"update"},
			},
			// Apps resources
			{
				APIGroups: []string{"apps"},
				Resources: []string{"deployments", "statefulsets"},
				Verbs:     []string{"get", "list", "watch", "create", "update", "patch", "delete"},
			},
			// Apps resources finalizers
			{
				APIGroups: []string{"apps"},
				Resources: []string{"deployments/finalizers", "statefulsets/finalizers"},
				Verbs:     []string{"update"},
			},
			// RBAC resources
			{
				APIGroups: []string{"rbac.authorization.k8s.io"},
				Resources: []string{"roles", "rolebindings", "clusterroles", "clusterrolebindings"},
				Verbs:     []string{"get", "list", "watch", "create", "update", "patch", "delete"},
			},
			// RBAC resources finalizers
			{
				APIGroups: []string{"rbac.authorization.k8s.io"},
				Resources: []string{"roles/finalizers", "rolebindings/finalizers", "clusterroles/finalizers", "clusterrolebindings/finalizers"},
				Verbs:     []string{"update"},
			},
			// Networking resources
			{
				APIGroups: []string{"networking.k8s.io"},
				Resources: []string{"ingresses"},
				Verbs:     []string{"get", "list", "watch", "create", "update", "patch", "delete"},
			},
			// Networking resources finalizers
			{
				APIGroups: []string{"networking.k8s.io"},
				Resources: []string{"ingresses/finalizers"},
				Verbs:     []string{"update"},
			},
			// PodDisruptionBudgets
			{
				APIGroups: []string{"policy"},
				Resources: []string{"poddisruptionbudgets"},
				Verbs:     []string{"get", "list", "watch", "create", "update", "patch", "delete"},
			},
			// OpenShift route resources
			{
				APIGroups: []string{"route.openshift.io"},
				Resources: []string{"routes"},
				Verbs:     []string{"create", "delete", "get", "list", "update", "watch"},
			},
			// Loki custom resources
			{
				APIGroups: []string{"loki.grafana.com"},
				Resources: []string{
					"lokistacks",
					"rulerconfigs",
					"recordingrules",
					"alertingrules",
				},
				Verbs: []string{"get", "list", "watch", "create", "update", "patch", "delete"},
			},
			// Loki custom resources status
			{
				APIGroups: []string{"loki.grafana.com"},
				Resources: []string{
					"lokistacks/status",
					"rulerconfigs/status",
					"recordingrules/status",
					"alertingrules/status",
				},
				Verbs: []string{"get", "update", "patch"},
			},
			// Loki custom resources finalizers
			{
				APIGroups: []string{"loki.grafana.com"},
				Resources: []string{
					"lokistacks/finalizers",
					"rulerconfigs/finalizers",
					"recordingrules/finalizers",
					"alertingrules/finalizers",
				},
				Verbs: []string{"update"},
			},
		},
	}
}

// NewClusterRoleBindingLokiStackManager returns the ClusterRoleBinding for lokistack-manager.
// Corresponds to role_binding.yaml.
func NewClusterRoleBindingLokiStackManager(namespace string) *rbacv1.ClusterRoleBinding {
	return &rbacv1.ClusterRoleBinding{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRoleBinding",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "loki-lokistack-manager",
		},
		Subjects: []rbacv1.Subject{{
			Kind:      "ServiceAccount",
			Name:      "loki-controller-manager",
			Namespace: namespace,
		}},
		RoleRef: rbacv1.RoleRef{
			APIGroup: rbacv1.SchemeGroupVersion.Group,
			Kind:     "ClusterRole",
			Name:     "loki-lokistack-manager",
		},
	}
}

// NewLokiStackEditorClusterRole returns the ClusterRole for lokistack-editor-role.
// Corresponds to lokistack_editor_role.yaml.
func NewLokiStackEditorClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRole",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "loki-lokistack-editor-role",
		},
		Rules: []rbacv1.PolicyRule{
			{
				APIGroups: []string{"loki.grafana.com"},
				Resources: []string{"lokistacks"},
				Verbs:     []string{"create", "delete", "get", "list", "patch", "update", "watch"},
			},
			{
				APIGroups: []string{"loki.grafana.com"},
				Resources: []string{"lokistacks/status"},
				Verbs:     []string{"get"},
			},
		},
	}
}

// NewLokiStackViewerClusterRole returns the ClusterRole for lokistack-viewer-role.
// Corresponds to lokistack_viewer_role.yaml.
func NewLokiStackViewerClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRole",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "loki-lokistack-viewer-role",
		},
		Rules: []rbacv1.PolicyRule{
			{
				APIGroups: []string{"loki.grafana.com"},
				Resources: []string{"lokistacks"},
				Verbs:     []string{"get", "list", "watch"},
			},
			{
				APIGroups: []string{"loki.grafana.com"},
				Resources: []string{"lokistacks/status"},
				Verbs:     []string{"get"},
			},
		},
	}
}

// NewRulerConfigViewerClusterRole returns the ClusterRole for rulerconfig-viewer-role.
// Corresponds to rulerconfig_viewer_role.yaml.
func NewRulerConfigViewerClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRole",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "loki-rulerconfig-viewer-role",
		},
		Rules: []rbacv1.PolicyRule{
			{
				APIGroups: []string{"loki.grafana.com"},
				Resources: []string{"rulerconfigs"},
				Verbs:     []string{"get", "list", "watch"},
			},
			{
				APIGroups: []string{"loki.grafana.com"},
				Resources: []string{"rulerconfigs/status"},
				Verbs:     []string{"get"},
			},
		},
	}
}

// NewRulerConfigEditorClusterRole returns the ClusterRole for rulerconfig-editor-role.
// Corresponds to rulerconfig_editor_role.yaml.
func NewRulerConfigEditorClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRole",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "loki-rulerconfig-editor-role",
		},
		Rules: []rbacv1.PolicyRule{
			{
				APIGroups: []string{"loki.grafana.com"},
				Resources: []string{"rulerconfigs"},
				Verbs:     []string{"create", "delete", "get", "list", "patch", "update", "watch"},
			},
			{
				APIGroups: []string{"loki.grafana.com"},
				Resources: []string{"rulerconfigs/status"},
				Verbs:     []string{"get"},
			},
		},
	}
}

// NewRecordingRuleViewerClusterRole returns the ClusterRole for recordingrule-viewer-role.
// Corresponds to recordingrule_viewer_role.yaml.
func NewRecordingRuleViewerClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRole",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "loki-recordingrule-viewer-role",
		},
		Rules: []rbacv1.PolicyRule{
			{
				APIGroups: []string{"loki.grafana.com"},
				Resources: []string{"recordingrules"},
				Verbs:     []string{"get", "list", "watch"},
			},
			{
				APIGroups: []string{"loki.grafana.com"},
				Resources: []string{"recordingrules/status"},
				Verbs:     []string{"get"},
			},
		},
	}
}

// NewRecordingRuleEditorClusterRole returns the ClusterRole for recordingrule-editor-role.
// Corresponds to recordingrule_editor_role.yaml.
func NewRecordingRuleEditorClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(),
			Kind:       "ClusterRole",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name: "loki-recordingrule-editor-role",
		},
		Rules: []rbacv1.PolicyRule{
			{
				APIGroups: []string{"loki.grafana.com"},
				Resources: []string{"recordingrules"},
				Verbs:     []string{"create", "delete", "get", "list", "patch", "update", "watch"},
			},
			{
				APIGroups: []string{"loki.grafana.com"},
				Resources: []string{"recordingrules/status"},
				Verbs:     []string{"get"},
			},
		},
	}
}

// NewAlertingRuleViewerClusterRole returns the ClusterRole for alertingrule-viewer-role.
// Corresponds to alertingrule_viewer_role.yaml.
func NewAlertingRuleViewerClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta: metav1.TypeMeta{
			APIVersion: rbacv1.SchemeGroupVersion.String(), Kind: "ClusterRole"},
		ObjectMeta: metav1.ObjectMeta{Name: "loki-alertingrule-viewer-role"},
		Rules: []rbacv1.PolicyRule{
			{APIGroups: []string{"loki.grafana.com"}, Resources: []string{"alertingrules"}, Verbs: []string{"get", "list", "watch"}},
			{APIGroups: []string{"loki.grafana.com"}, Resources: []string{"alertingrules/status"}, Verbs: []string{"get"}},
		},
	}
}

// NewAlertingRuleEditorClusterRole returns the ClusterRole for alertingrule-editor-role.
// Corresponds to alertingrule_editor_role.yaml.
func NewAlertingRuleEditorClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta:   metav1.TypeMeta{APIVersion: rbacv1.SchemeGroupVersion.String(), Kind: "ClusterRole"},
		ObjectMeta: metav1.ObjectMeta{Name: "loki-alertingrule-editor-role"},
		Rules: []rbacv1.PolicyRule{
			{APIGroups: []string{"loki.grafana.com"}, Resources: []string{"alertingrules"}, Verbs: []string{"create", "delete", "get", "list", "patch", "update", "watch"}},
			{APIGroups: []string{"loki.grafana.com"}, Resources: []string{"alertingrules/status"}, Verbs: []string{"get"}},
		},
	}
}

// NewPrometheusRole returns the Role for prometheus.
// Corresponds to prometheus_role.yaml.
func NewPrometheusRole(namespace string) *rbacv1.Role {
	return &rbacv1.Role{
		TypeMeta: metav1.TypeMeta{APIVersion: rbacv1.SchemeGroupVersion.String(), Kind: "Role"},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "loki-prometheus",
			Namespace: namespace,
			Annotations: map[string]string{
				"include.release.openshift.io/self-managed-high-availability": "true",
				"include.release.openshift.io/single-node-developer":          "true",
			},
		},
		Rules: []rbacv1.PolicyRule{{APIGroups: []string{""}, Resources: []string{"services", "endpoints", "pods"}, Verbs: []string{"get", "list", "watch"}}},
	}
}

// NewPrometheusRoleBinding returns the RoleBinding for prometheus.
// Corresponds to prometheus_role_binding.yaml.
func NewPrometheusRoleBinding(namespace string) *rbacv1.RoleBinding {
	return &rbacv1.RoleBinding{
		TypeMeta: metav1.TypeMeta{APIVersion: rbacv1.SchemeGroupVersion.String(), Kind: "RoleBinding"},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "loki-prometheus",
			Namespace: namespace,
			Annotations: map[string]string{
				"include.release.openshift.io/self-managed-high-availability": "true",
				"include.release.openshift.io/single-node-developer":          "true",
			},
		},
		Subjects: []rbacv1.Subject{{Kind: "ServiceAccount", Name: "prometheus-k8s", Namespace: "openshift-monitoring"}},
		RoleRef:  rbacv1.RoleRef{APIGroup: rbacv1.SchemeGroupVersion.Group, Kind: "Role", Name: "loki-prometheus"},
	}
}

// NewLeaderElectionRole returns the Role for leader-election.
// Corresponds to leader_election_role.yaml.
func NewLeaderElectionRole(namespace string) *rbacv1.Role {
	return &rbacv1.Role{
		TypeMeta:   metav1.TypeMeta{APIVersion: rbacv1.SchemeGroupVersion.String(), Kind: "Role"},
		ObjectMeta: metav1.ObjectMeta{Name: "loki-leader-election-role", Namespace: namespace},
		Rules: []rbacv1.PolicyRule{
			{APIGroups: []string{"", "coordination.k8s.io"}, Resources: []string{"configmaps", "leases"}, Verbs: []string{"get", "list", "watch", "create", "update", "patch", "delete"}},
			{APIGroups: []string{""}, Resources: []string{"events"}, Verbs: []string{"create", "patch"}},
		},
	}
}

// NewLeaderElectionRoleBinding returns the RoleBinding for leader-election.
// Corresponds to leader_election_role_binding.yaml.
func NewLeaderElectionRoleBinding(namespace string) *rbacv1.RoleBinding {
	return &rbacv1.RoleBinding{
		TypeMeta:   metav1.TypeMeta{APIVersion: rbacv1.SchemeGroupVersion.String(), Kind: "RoleBinding"},
		ObjectMeta: metav1.ObjectMeta{Name: "loki-leader-election-rolebinding", Namespace: namespace},
		Subjects:   []rbacv1.Subject{{Kind: "ServiceAccount", Name: "loki-controller-manager", Namespace: namespace}},
		RoleRef:    rbacv1.RoleRef{APIGroup: rbacv1.SchemeGroupVersion.Group, Kind: "Role", Name: "loki-leader-election-role"},
	}
}

// NewAuthProxyClientServiceAccount returns the ServiceAccount for controller-manager-metrics-reader.
// Corresponds to auth_proxy_client_serviceaccount.yaml.
func NewAuthProxyClientServiceAccount(namespace string) *corev1.ServiceAccount {
	return &corev1.ServiceAccount{
		TypeMeta:   metav1.TypeMeta{APIVersion: corev1.SchemeGroupVersion.String(), Kind: "ServiceAccount"},
		ObjectMeta: metav1.ObjectMeta{Name: "loki-controller-manager-metrics-reader", Namespace: namespace},
	}
}

// NewAuthProxyClientClusterRole returns the ClusterRole for metrics-reader.
// Corresponds to auth_proxy_client_clusterrole.yaml.
func NewAuthProxyClientClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta:   metav1.TypeMeta{APIVersion: rbacv1.SchemeGroupVersion.String(), Kind: "ClusterRole"},
		ObjectMeta: metav1.ObjectMeta{Name: "loki-metrics-reader"},
		Rules:      []rbacv1.PolicyRule{{NonResourceURLs: []string{"/metrics"}, Verbs: []string{"get"}}},
	}
}

// NewAuthProxyClientClusterRoleBinding returns the ClusterRoleBinding for controller-manager-read-metrics.
// Corresponds to auth_proxy_client_clusterrolebinding.yaml.
func NewAuthProxyClientClusterRoleBinding(namespace string) *rbacv1.ClusterRoleBinding {
	return &rbacv1.ClusterRoleBinding{
		TypeMeta:   metav1.TypeMeta{APIVersion: rbacv1.SchemeGroupVersion.String(), Kind: "ClusterRoleBinding"},
		ObjectMeta: metav1.ObjectMeta{Name: "loki-controller-manager-read-metrics", Namespace: namespace},
		Subjects:   []rbacv1.Subject{{Kind: "ServiceAccount", Name: "loki-controller-manager-metrics-reader", Namespace: namespace}},
		RoleRef:    rbacv1.RoleRef{APIGroup: rbacv1.SchemeGroupVersion.Group, Kind: "ClusterRole", Name: "loki-metrics-reader"},
	}
}

// NewAuthProxyRole returns the ClusterRole for proxy-role.
// Corresponds to auth_proxy_role.yaml.
func NewAuthProxyRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta:   metav1.TypeMeta{APIVersion: rbacv1.SchemeGroupVersion.String(), Kind: "ClusterRole"},
		ObjectMeta: metav1.ObjectMeta{Name: "loki-proxy-role"},
		Rules: []rbacv1.PolicyRule{
			{APIGroups: []string{"authentication.k8s.io"}, Resources: []string{"tokenreviews"}, Verbs: []string{"create"}},
			{APIGroups: []string{"authorization.k8s.io"}, Resources: []string{"subjectaccessreviews"}, Verbs: []string{"create"}},
		},
	}
}

// NewAuthProxyRoleBinding returns the ClusterRoleBinding for proxy-rolebinding.
// Corresponds to auth_proxy_role_binding.yaml.
func NewAuthProxyRoleBinding(namespace string) *rbacv1.ClusterRoleBinding {
	return &rbacv1.ClusterRoleBinding{
		TypeMeta:   metav1.TypeMeta{APIVersion: rbacv1.SchemeGroupVersion.String(), Kind: "ClusterRoleBinding"},
		ObjectMeta: metav1.ObjectMeta{Name: "loki-proxy-rolebinding", Namespace: namespace},
		Subjects:   []rbacv1.Subject{{Kind: "ServiceAccount", Name: "loki-controller-manager", Namespace: namespace}},
		RoleRef:    rbacv1.RoleRef{APIGroup: rbacv1.SchemeGroupVersion.Group, Kind: "ClusterRole", Name: "loki-proxy-role"},
	}
}

// NewAuthProxyService returns the Service for controller-manager-metrics-service.
// Corresponds to auth_proxy_service.yaml.
func NewAuthProxyService(namespace string) *corev1.Service {
	return &corev1.Service{
		TypeMeta: metav1.TypeMeta{APIVersion: corev1.SchemeGroupVersion.String(), Kind: "Service"},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "loki-controller-manager-metrics-service",
			Namespace: namespace,
			Labels:    map[string]string{"app.kubernetes.io/component": "metrics"},
		},
		Spec: corev1.ServiceSpec{
			Selector: map[string]string{"name": "loki-operator-controller-manager"},
			Ports: []corev1.ServicePort{
				{Name: "https", Protocol: corev1.ProtocolTCP, Port: 8443, TargetPort: intstr.FromString("https")},
			},
		},
	}
}
