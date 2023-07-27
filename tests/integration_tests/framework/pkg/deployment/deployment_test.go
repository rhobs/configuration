package deployment

import (
	"testing"
	"time"

	"github.com/rhobs/configuration/tests/integration_tests/framework/pkg/logger"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/kubernetes/fake"
)

var (
	testNS      = "test-namespace"
	testDep     = "test-deployment"
	testLabels  = make(map[string]string)
	testDepList = appsv1.DeploymentList{
		Items: []appsv1.Deployment{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      testDep,
					Namespace: testNS,
				},
				Spec: appsv1.DeploymentSpec{
					Selector: &metav1.LabelSelector{
						MatchLabels: testLabels,
					},
				},
			},
		},
	}
)

// Limitation: Since retry.RetryOnConflict only works on a running Kubernetes cluster.
// we use fake to build client we have to agument the way retryOnConflict works.
// TODO: Come up with good way to handle this

type mockRetryer struct {
	err error
}

func (m *mockRetryer) RetryOnConflict(backoff wait.Backoff, fn func() error) error {
	return m.err
}

func TestGetDeployment(t *testing.T) {
	clienset := fake.NewSimpleClientset(&testDepList)
	logger.NewLogger(logger.LevelInfo)
	dep, err := getDeployment(testNS, clienset)
	if err != nil {
		t.Fatalf("expected nil got: %v", err)
	}
	if len(dep.Items) != 1 {
		t.Errorf("expected 1 deployment, got: %v", len(dep.Items))
	}
}

func TestGetDeploymentNoDeployment(t *testing.T) {
	clientset := fake.NewSimpleClientset()
	logger.NewLogger(logger.LevelInfo)
	_, err := getDeployment(testNS, clientset)
	if err != ErrNoDeployment {
		t.Fatalf("expected ErrNoDeployment, got: %v", err)
	}
}

func TestStoreDeploymentsByNamespace(t *testing.T) {
	clientset := fake.NewSimpleClientset(&testDepList)
	namespaces := []string{testNS}
	deploymentsByNamespace, err := storeDeploymentsByNamespace(namespaces, clientset)
	if err != nil {
		t.Fatalf("expected nil, got: %v", err)
	}
	if len(deploymentsByNamespace) != 1 {
		t.Errorf("expected 1 deployment, got: %v", len(deploymentsByNamespace))
	}
}

func TestStoreDeploymentsByNamespaceNoNamespace(t *testing.T) {
	clientset := fake.NewSimpleClientset(&testDepList)
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{}
	_, err := storeDeploymentsByNamespace(namespaces, clientset)
	if err != ErrNoNamespace {
		t.Fatalf("expected ErrNoNamespace, got: %v", err)
	}
}

func TestStoreDeploymentsByNamespaceNoDeployments(t *testing.T) {
	clientset := fake.NewSimpleClientset()
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	_, err := storeDeploymentsByNamespace(namespaces, clientset)
	if err != ErrNoDeployment {
		t.Fatalf("expected ErrNoDeployment, got: %v", err)
	}
}

func TestCheckDeploymentStatus(t *testing.T) {
	clientset := fake.NewSimpleClientset(&testDepList)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: nil}
	logger.NewLogger(logger.LevelInfo)
	err := checkDeploymentStatus(testNS, testDepList.Items[0], clientset)
	if err != nil {
		t.Fatalf("expected nil, got: %v", err)
	}
}

func TestCheckDeploymentStatusNotHealthy(t *testing.T) {
	faultyDep := appsv1.DeploymentList{
		Items: []appsv1.Deployment{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      testDep,
					Namespace: testNS,
				},
				Status: appsv1.DeploymentStatus{
					AvailableReplicas: 0,
				},
			},
		},
	}
	clientset := fake.NewSimpleClientset(&faultyDep)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: ErrDeploymentsNotHealthy}
	logger.NewLogger(logger.LevelInfo)
	err := checkDeploymentStatus(testNS, faultyDep.Items[0], clientset)
	if err != ErrDeploymentsNotHealthy {
		t.Fatalf("expected ErrDeploymentsNotHealthy, got: %v", err)
	}
}

func TestValidateDeploymentsByNamespace(t *testing.T) {
	testLabels["app"] = "test-app"
	testPods := corev1.PodList{
		Items: []corev1.Pod{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "testPod",
					Namespace: testNS,
					Labels:    testLabels,
				},
				Status: corev1.PodStatus{
					Phase: corev1.PodRunning,
				},
			},
		},
	}
	clientset := fake.NewSimpleClientset(&testDepList, &testPods)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: nil}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	deploymentsByNamepace := make(map[string][]appsv1.Deployment)
	deploymentsByNamepace[testNS] = testDepList.Items
	interval := 1 * time.Second
	timeout := 5 * time.Second
	err := validateDeploymentsByNamespace(namespaces, deploymentsByNamepace, clientset, interval, timeout)
	if err != nil {
		t.Fatalf("expected nil, got: %v", err)
	}
}

func TestValidateDeploymentsByNamespaceNoNamespace(t *testing.T) {
	testLabels["app"] = "test-app"
	testPods := corev1.PodList{
		Items: []corev1.Pod{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "testPod",
					Namespace: testNS,
					Labels:    testLabels,
				},
				Status: corev1.PodStatus{
					Phase: corev1.PodRunning,
				},
			},
		},
	}
	clientset := fake.NewSimpleClientset(&testDepList, &testPods)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: nil}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{}
	deploymentsByNamepace := make(map[string][]appsv1.Deployment)
	interval := 1 * time.Second
	timeout := 5 * time.Second
	err := validateDeploymentsByNamespace(namespaces, deploymentsByNamepace, clientset, interval, timeout)
	if err != ErrNamespaceEmpty {
		t.Fatalf("expected ErrNamespaceEmpty, got: %v", err)
	}

}

func TestValidateDeploymentsByNamespaceInvalidInterval(t *testing.T) {
	testLabels["app"] = "test-app"
	testPods := corev1.PodList{
		Items: []corev1.Pod{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "testPod",
					Namespace: testNS,
					Labels:    testLabels,
				},
				Status: corev1.PodStatus{
					Phase: corev1.PodRunning,
				},
			},
		},
	}
	clientset := fake.NewSimpleClientset(&testDepList, &testPods)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: nil}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	deploymentsByNamepace := make(map[string][]appsv1.Deployment)
	deploymentsByNamepace[testNS] = testDepList.Items
	interval := -1 * time.Second
	timeout := -5 * time.Second
	err := validateDeploymentsByNamespace(namespaces, deploymentsByNamepace, clientset, interval, timeout)
	if err != ErrInvalidInterval {
		t.Fatalf("expected ErrInvalidInterval, got: %v", err)
	}
}

func TestValidateDeploymentsByNamespaceNoDeploymentsByNamespace(t *testing.T) {
	clientset := fake.NewSimpleClientset()
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: nil}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	deploymentsByNamepace := make(map[string][]appsv1.Deployment)
	interval := 1 * time.Second
	timeout := 5 * time.Second
	err := validateDeploymentsByNamespace(namespaces, deploymentsByNamepace, clientset, interval, timeout)
	if err != ErrNoDeployment {
		t.Fatalf("expected ErrNoDeployment, got: %v", err)
	}
}

func TestValidateDeploymentsByNamespaceDeploymentFailed(t *testing.T) {
	testLabels["app"] = "test-app"
	faultyPods := corev1.PodList{
		Items: []corev1.Pod{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "testPod",
					Namespace: testNS,
					Labels:    testLabels,
				},
				Status: corev1.PodStatus{
					Phase: corev1.PodUnknown,
				},
			},
		},
	}
	faultyDep := appsv1.DeploymentList{
		Items: []appsv1.Deployment{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      testDep,
					Namespace: testNS,
				},
				Spec: appsv1.DeploymentSpec{
					Selector: &metav1.LabelSelector{
						MatchLabels: testLabels,
					},
				},
				Status: appsv1.DeploymentStatus{
					AvailableReplicas: 0,
				},
			},
		},
	}

	clientset := fake.NewSimpleClientset(&faultyDep, &faultyPods)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: ErrDeploymentsNotHealthy}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	deploymentsByNamepace := make(map[string][]appsv1.Deployment)
	deploymentsByNamepace[testNS] = faultyDep.Items
	interval := 1 * time.Second
	timeout := 5 * time.Second
	err := validateDeploymentsByNamespace(namespaces, deploymentsByNamepace, clientset, interval, timeout)
	if err != ErrDeploymentFailed {
		t.Fatalf("expected ErrDeploymentFailed, got: %v", err)
	}
}

func TestValidateDeploymentsByNamespacePodFailed(t *testing.T) {
	testLabels["app"] = "test-app"
	faultyPods := corev1.PodList{
		Items: []corev1.Pod{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "testPod",
					Namespace: testNS,
					Labels:    testLabels,
				},
				Status: corev1.PodStatus{
					Phase: corev1.PodUnknown,
				},
			},
		},
	}

	clientset := fake.NewSimpleClientset(&testDepList, &faultyPods)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: nil}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	deploymentsByNamepace := make(map[string][]appsv1.Deployment)
	deploymentsByNamepace[testNS] = testDepList.Items
	interval := 1 * time.Second
	timeout := 5 * time.Second
	err := validateDeploymentsByNamespace(namespaces, deploymentsByNamepace, clientset, interval, timeout)
	if err != ErrDeploymentFailed {
		t.Fatalf("expected ErrDeploymentFailed, got: %v", err)
	}
}

func TestCheckDeployments(t *testing.T) {
	testLabels["app"] = "test-app"
	testPods := corev1.PodList{
		Items: []corev1.Pod{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "testPod",
					Namespace: testNS,
					Labels:    testLabels,
				},
				Status: corev1.PodStatus{
					Phase: corev1.PodRunning,
				},
			},
		},
	}
	clientset := fake.NewSimpleClientset(&testDepList, &testPods)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: nil}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	interval := 1 * time.Second
	timeout := 5 * time.Second
	err := CheckDeployments(namespaces, clientset, interval, timeout)
	if err != nil {
		t.Fatalf("expected nil, got: %v", err)
	}
}

func TestCheckDeploymentsNoNamespace(t *testing.T) {
	clientset := fake.NewSimpleClientset(&testDepList)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: nil}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{}
	interval := 1 * time.Second
	timeout := 5 * time.Second
	err := CheckDeployments(namespaces, clientset, interval, timeout)
	if err != ErrNoNamespace {
		t.Fatalf("expected ErrNoNamespace, got: %v", err)
	}
}
