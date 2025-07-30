//go:build mage

package main

import (
	"fmt"
	"os"

	"github.com/go-kit/log"
	"github.com/magefile/mage/mg"
	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic"
	"github.com/philipgough/mimic/encoding"
	"github.com/rhobs/configuration/internal/submodule"

	lokiv1 "github.com/grafana/loki/operator/apis/loki/v1"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/intstr"
	"k8s.io/utils/ptr"
)

var (
	operatorImage    = "quay.io/redhat-user-workloads/obs-logging-tenant/loki-operator-v6-3"
	operatorImageTag = "ab233daeab6b9808a6c216c75cc5db449486f87e"
)

type (
	Logs mg.Namespace
)

const (
	templatePath         = "resources"
	templateServicesPath = "services"
	namePrefix           = "loki-"
)

func addLokiPrefix(name string) string {
	return namePrefix + name
}

func generator(component string) *mimic.Generator {
	gen := &mimic.Generator{}
	gen = gen.With(templatePath, templateServicesPath, component, "staging")
	gen.Logger = log.NewLogfmtLogger(log.NewSyncWriter(os.Stdout))
	return gen
}

func (l Logs) Operator() {
	tag := operatorImageTag
	crds(tag)
	operator(tag)
}

func (l Logs) LokiStack() {
	lokiStack()
}

func crds(tag string) {
	repoURL := "https://gitlab.cee.redhat.com/openshift-logging/konflux-log-storage"
	submodulePath := "loki-operator"

	// Use the Info struct and Parse method from fetch.go
	info := submodule.Info{
		Commit:        tag,
		SubmodulePath: submodulePath,
		URL:           repoURL,
		PathToYAMLS:   "operator/config/crd/bases",
	}

	fmt.Printf("Fetching CRDs from: %s, commit: %s, submodule: %s, path: %s\n", repoURL, tag, submodulePath, "operator/config/crd/bases")

	objs, err := info.FetchYAMLs()
	if err != nil {
		fmt.Printf("Error fetching YAML files: %v\n", err)
		return
	}

	fmt.Printf("Successfully fetched %d CRD objects\n", len(objs))

	gen := generator("loki-operator-crds")
	gen.Add("crds.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			objs,
			metav1.ObjectMeta{Name: "loki-operator-crds"},
			[]templatev1.Parameter{},
		),
	))
	gen.Generate()
}

func operator(tag string) {
	namespace := "rhobs-stage"
	gen := generator("loki-operator")
	gen.Add("operator.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			operatorResources(namespace, tag),
			metav1.ObjectMeta{Name: "loki-operator-manager"},
			[]templatev1.Parameter{},
		),
	))

	gen.Generate()
}

func lokiStack() {
	namespace := "rhobs-stage"
	gen := generator("loki-stack")

	lokiStackResources := []runtime.Object{
		NewLokiStackStorageSecret(namespace),
		NewLokiStack(namespace),
	}

	gen.Add("lokistack.yaml", encoding.GhodssYAML(
		openshift.WrapInTemplate(
			lokiStackResources,
			metav1.ObjectMeta{Name: "loki-stack"},
			[]templatev1.Parameter{
				{Name: "LOKI_SIZE", DisplayName: "LokiStack Size", Value: "1x.medium", Required: true},
				{Name: "LOKI_STORAGE_CLASS", DisplayName: "Storage Class", Value: "gp2", Required: true},
				{Name: "LOKI_TENANT_MODE", DisplayName: "Tenant Mode", Value: "openshift-logging", Required: true},
				{Name: "LOKI_STORAGE_SECRET_NAME", DisplayName: "Storage Secret Name", Value: "loki-storage", Required: true},
				{Name: "LOKI_STORAGE_SECRET_TYPE", DisplayName: "Storage Secret Type", Value: "s3", Required: true},
				{Name: "ACCESS_KEY_ID", DisplayName: "S3 Access Key ID", Required: true},
				{Name: "SECRET_ACCESS_KEY", DisplayName: "S3 Secret Access Key", Required: true},
				{Name: "S3_BUCKET_NAME", DisplayName: "S3 Bucket Name", Required: true},
				{Name: "S3_BUCKET_ENDPOINT", DisplayName: "S3 Bucket Endpoint", Required: true},
				{Name: "S3_BUCKET_REGION", DisplayName: "S3 Bucket Region", Value: "us-east-1", Required: true},
			},
		),
	))
	gen.Generate()
}

func operatorResources(namespace, tag string) []runtime.Object {
	objs := []runtime.Object{
		NewControllerManagerDeployment(namespace, tag),
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
func NewControllerManagerDeployment(namespace, tag string) *appsv1.Deployment {
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
					ServiceAccountName: addLokiPrefix("controller-manager"),
					NodeSelector:       map[string]string{"kubernetes.io/os": "linux"},
					Containers: []corev1.Container{{
						Name:            "manager",
						Image:           fmt.Sprintf("%s:%s", operatorImage, tag),
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
			Name:      addLokiPrefix("controller-manager"),
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
			Name: addLokiPrefix("lokistack-manager"),
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
			Name: addLokiPrefix("lokistack-manager"),
		},
		Subjects: []rbacv1.Subject{{
			Kind:      "ServiceAccount",
			Name:      addLokiPrefix("controller-manager"),
			Namespace: namespace,
		}},
		RoleRef: rbacv1.RoleRef{
			APIGroup: rbacv1.SchemeGroupVersion.Group,
			Kind:     "ClusterRole",
			Name:     addLokiPrefix("lokistack-manager"),
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
			Name: addLokiPrefix("lokistack-editor-role"),
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
			Name: addLokiPrefix("lokistack-viewer-role"),
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
			Name: addLokiPrefix("rulerconfig-viewer-role"),
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
			Name: addLokiPrefix("rulerconfig-editor-role"),
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
			Name: addLokiPrefix("recordingrule-viewer-role"),
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
			Name: addLokiPrefix("recordingrule-editor-role"),
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
		ObjectMeta: metav1.ObjectMeta{Name: addLokiPrefix("alertingrule-viewer-role")},
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
		ObjectMeta: metav1.ObjectMeta{Name: addLokiPrefix("alertingrule-editor-role")},
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
			Name:      addLokiPrefix("prometheus"),
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
			Name:      addLokiPrefix("prometheus"),
			Namespace: namespace,
			Annotations: map[string]string{
				"include.release.openshift.io/self-managed-high-availability": "true",
				"include.release.openshift.io/single-node-developer":          "true",
			},
		},
		Subjects: []rbacv1.Subject{{Kind: "ServiceAccount", Name: "prometheus-k8s", Namespace: "openshift-monitoring"}},
		RoleRef:  rbacv1.RoleRef{APIGroup: rbacv1.SchemeGroupVersion.Group, Kind: "Role", Name: addLokiPrefix("prometheus")},
	}
}

// NewLeaderElectionRole returns the Role for leader-election.
// Corresponds to leader_election_role.yaml.
func NewLeaderElectionRole(namespace string) *rbacv1.Role {
	return &rbacv1.Role{
		TypeMeta:   metav1.TypeMeta{APIVersion: rbacv1.SchemeGroupVersion.String(), Kind: "Role"},
		ObjectMeta: metav1.ObjectMeta{Name: addLokiPrefix("leader-election-role"), Namespace: namespace},
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
		ObjectMeta: metav1.ObjectMeta{Name: addLokiPrefix("leader-election-rolebinding"), Namespace: namespace},
		Subjects:   []rbacv1.Subject{{Kind: "ServiceAccount", Name: addLokiPrefix("controller-manager"), Namespace: namespace}},
		RoleRef:    rbacv1.RoleRef{APIGroup: rbacv1.SchemeGroupVersion.Group, Kind: "Role", Name: addLokiPrefix("leader-election-role")},
	}
}

// NewAuthProxyClientServiceAccount returns the ServiceAccount for controller-manager-metrics-reader.
// Corresponds to auth_proxy_client_serviceaccount.yaml.
func NewAuthProxyClientServiceAccount(namespace string) *corev1.ServiceAccount {
	return &corev1.ServiceAccount{
		TypeMeta:   metav1.TypeMeta{APIVersion: corev1.SchemeGroupVersion.String(), Kind: "ServiceAccount"},
		ObjectMeta: metav1.ObjectMeta{Name: addLokiPrefix("controller-manager-metrics-reader"), Namespace: namespace},
	}
}

// NewAuthProxyClientClusterRole returns the ClusterRole for metrics-reader.
// Corresponds to auth_proxy_client_clusterrole.yaml.
func NewAuthProxyClientClusterRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta:   metav1.TypeMeta{APIVersion: rbacv1.SchemeGroupVersion.String(), Kind: "ClusterRole"},
		ObjectMeta: metav1.ObjectMeta{Name: addLokiPrefix("metrics-reader")},
		Rules:      []rbacv1.PolicyRule{{NonResourceURLs: []string{"/metrics"}, Verbs: []string{"get"}}},
	}
}

// NewAuthProxyClientClusterRoleBinding returns the ClusterRoleBinding for controller-manager-read-metrics.
// Corresponds to auth_proxy_client_clusterrolebinding.yaml.
func NewAuthProxyClientClusterRoleBinding(namespace string) *rbacv1.ClusterRoleBinding {
	return &rbacv1.ClusterRoleBinding{
		TypeMeta:   metav1.TypeMeta{APIVersion: rbacv1.SchemeGroupVersion.String(), Kind: "ClusterRoleBinding"},
		ObjectMeta: metav1.ObjectMeta{Name: addLokiPrefix("controller-manager-read-metrics"), Namespace: namespace},
		Subjects:   []rbacv1.Subject{{Kind: "ServiceAccount", Name: addLokiPrefix("controller-manager-metrics-reader"), Namespace: namespace}},
		RoleRef:    rbacv1.RoleRef{APIGroup: rbacv1.SchemeGroupVersion.Group, Kind: "ClusterRole", Name: addLokiPrefix("metrics-reader")},
	}
}

// NewAuthProxyRole returns the ClusterRole for proxy-role.
// Corresponds to auth_proxy_role.yaml.
func NewAuthProxyRole() *rbacv1.ClusterRole {
	return &rbacv1.ClusterRole{
		TypeMeta:   metav1.TypeMeta{APIVersion: rbacv1.SchemeGroupVersion.String(), Kind: "ClusterRole"},
		ObjectMeta: metav1.ObjectMeta{Name: addLokiPrefix("proxy-role")},
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
		ObjectMeta: metav1.ObjectMeta{Name: addLokiPrefix("proxy-rolebinding"), Namespace: namespace},
		Subjects:   []rbacv1.Subject{{Kind: "ServiceAccount", Name: addLokiPrefix("controller-manager"), Namespace: namespace}},
		RoleRef:    rbacv1.RoleRef{APIGroup: rbacv1.SchemeGroupVersion.Group, Kind: "ClusterRole", Name: addLokiPrefix("proxy-role")},
	}
}

// NewAuthProxyService returns the Service for controller-manager-metrics-service.
// Corresponds to auth_proxy_service.yaml.
func NewAuthProxyService(namespace string) *corev1.Service {
	return &corev1.Service{
		TypeMeta: metav1.TypeMeta{APIVersion: corev1.SchemeGroupVersion.String(), Kind: "Service"},
		ObjectMeta: metav1.ObjectMeta{
			Name:      addLokiPrefix("controller-manager-metrics-service"),
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

// NewLokiStackStorageSecret returns the Secret for Loki storage configuration
func NewLokiStackStorageSecret(namespace string) *corev1.Secret {
	return &corev1.Secret{
		TypeMeta: metav1.TypeMeta{
			APIVersion: corev1.SchemeGroupVersion.String(),
			Kind:       "Secret",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "${LOKI_STORAGE_SECRET_NAME}",
			Namespace: namespace,
		},
		Type: corev1.SecretTypeOpaque,
		StringData: map[string]string{
			"access_key_id":     "${ACCESS_KEY_ID}",
			"access_key_secret": "${SECRET_ACCESS_KEY}",
			"bucketnames":       "${S3_BUCKET_NAME}",
			"endpoint":          "https://${S3_BUCKET_ENDPOINT}",
			"region":            "${S3_BUCKET_REGION}",
		},
	}
}

// NewLokiStack returns a LokiStack custom resource
func NewLokiStack(namespace string) *lokiv1.LokiStack {
	return &lokiv1.LokiStack{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "loki.grafana.com/v1",
			Kind:       "LokiStack",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "observatorium-lokistack",
			Namespace: namespace,
		},
		Spec: lokiv1.LokiStackSpec{
			ManagementState: lokiv1.ManagementStateManaged,
			Size:            lokiv1.LokiStackSizeType("${LOKI_SIZE}"),
			Storage: lokiv1.ObjectStorageSpec{
				Schemas: []lokiv1.ObjectStorageSchema{
					{
						EffectiveDate: "2025-06-06",
						Version:       lokiv1.ObjectStorageSchemaV13,
					},
				},
				Secret: lokiv1.ObjectStorageSecretSpec{
					Name: "${LOKI_STORAGE_SECRET_NAME}",
					Type: lokiv1.ObjectStorageSecretType("${LOKI_STORAGE_SECRET_TYPE}"),
				},
			},
			StorageClassName: "${LOKI_STORAGE_CLASS}",
			Tenants: &lokiv1.TenantsSpec{
				Mode: lokiv1.ModeType("${LOKI_TENANT_MODE}"),
			},
		},
	}
}
