package statefulset

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
	testNS     = "test-namespace"
	testStset  = "test-statefulset"
	testLabels = make(map[string]string)
	testSSList = appsv1.StatefulSetList{
		Items: []appsv1.StatefulSet{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      testStset,
					Namespace: testNS,
				},
				Spec: appsv1.StatefulSetSpec{
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

func TestGetStatefulSet(t *testing.T) {
	clienset := fake.NewSimpleClientset(&testSSList)
	logger.NewLogger(logger.LevelInfo)
	sts, err := getStatefulSet(testNS, clienset)
	if err != nil {
		t.Fatalf("expected nil got: %v", err)
	}
	if len(sts.Items) != 1 {
		t.Errorf("expected 1 statefulset, got: %v", len(sts.Items))
	}
}

func TestGetStatefulSetNoStatefulSet(t *testing.T) {
	clientset := fake.NewSimpleClientset()
	logger.NewLogger(logger.LevelInfo)
	_, err := getStatefulSet(testNS, clientset)
	if err != ErrNoStatefulSet {
		t.Fatalf("expected ErrNoStatefulSet, got: %v", err)
	}
}

func TestStoreStatefulSetsByNamespace(t *testing.T) {
	clientset := fake.NewSimpleClientset(&testSSList)
	namespaces := []string{testNS}
	statefulsetsByNamespace, err := storeStatefulSetsByNamespace(namespaces, clientset)
	if err != nil {
		t.Fatalf("expected nil, got: %v", err)
	}
	if len(statefulsetsByNamespace) != 1 {
		t.Errorf("expected 1 statefulset, got: %v", len(statefulsetsByNamespace))
	}
}

func TestStoreStatefulSetsByNamespaceNoNamespace(t *testing.T) {
	clientset := fake.NewSimpleClientset(&testSSList)
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{}
	_, err := storeStatefulSetsByNamespace(namespaces, clientset)
	if err != ErrNoNamespace {
		t.Fatalf("expected ErrNoNamespace, got: %v", err)
	}
}

func TestStoreStatefulSetsByNamespaceNoStatefulSets(t *testing.T) {
	clientset := fake.NewSimpleClientset()
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	_, err := storeStatefulSetsByNamespace(namespaces, clientset)
	if err != ErrNoStatefulSet {
		t.Fatalf("expected ErrNoStatefulSet, got: %v", err)
	}
}

func TestCheckStatefulSetStatus(t *testing.T) {
	clientset := fake.NewSimpleClientset(&testSSList)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: nil}
	logger.NewLogger(logger.LevelInfo)
	err := checkStatefulSetStatus(testNS, testSSList.Items[0], clientset)
	if err != nil {
		t.Fatalf("expected nil, got: %v", err)
	}
}

func TestCheckStatefulSetStatusNotHealthy(t *testing.T) {
	faultySS := appsv1.StatefulSetList{
		Items: []appsv1.StatefulSet{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      testStset,
					Namespace: testNS,
				},
				Status: appsv1.StatefulSetStatus{
					AvailableReplicas: 0,
				},
			},
		},
	}
	clientset := fake.NewSimpleClientset(&faultySS)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: ErrStatefulSetNotHealthy}
	logger.NewLogger(logger.LevelInfo)
	err := checkStatefulSetStatus(testNS, faultySS.Items[0], clientset)
	if err != ErrStatefulSetNotHealthy {
		t.Fatalf("expected ErrStatefulSetNotHealthy, got: %v", err)
	}
}

func TestValidateStatefulSetsByNamespace(t *testing.T) {
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
	clientset := fake.NewSimpleClientset(&testSSList, &testPods)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: nil}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	statefulsetsByNamespace := make(map[string][]appsv1.StatefulSet)
	statefulsetsByNamespace[testNS] = testSSList.Items
	interval := 1 * time.Second
	timeout := 5 * time.Second
	err := validateStatefulSetsByNamespace(namespaces, statefulsetsByNamespace, clientset, interval, timeout)
	if err != nil {
		t.Fatalf("expected nil, got: %v", err)
	}
}

func TestValidateStatefulSetsByNamespaceNoNamespace(t *testing.T) {
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
	clientset := fake.NewSimpleClientset(&testSSList, &testPods)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: nil}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{}
	statefulsetsByNamespace := make(map[string][]appsv1.StatefulSet)
	interval := 1 * time.Second
	timeout := 5 * time.Second
	err := validateStatefulSetsByNamespace(namespaces, statefulsetsByNamespace, clientset, interval, timeout)
	if err != ErrNamespaceEmpty {
		t.Fatalf("expected ErrNamespaceEmpty, got: %v", err)
	}

}

func TestValidateStatefulSetsByNamespaceInvalidInterval(t *testing.T) {
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
	clientset := fake.NewSimpleClientset(&testSSList, &testPods)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: nil}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	statefulsetsByNamespace := make(map[string][]appsv1.StatefulSet)
	statefulsetsByNamespace[testNS] = testSSList.Items
	interval := -1 * time.Second
	timeout := -5 * time.Second
	err := validateStatefulSetsByNamespace(namespaces, statefulsetsByNamespace, clientset, interval, timeout)
	if err != ErrInvalidInterval {
		t.Fatalf("expected ErrInvalidInterval, got: %v", err)
	}
}

func TestValidateStatefulSetsByNamespaceNoStatefulSetByNamespace(t *testing.T) {
	clientset := fake.NewSimpleClientset()
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: nil}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	statefulsetsByNamespace := make(map[string][]appsv1.StatefulSet)
	interval := 1 * time.Second
	timeout := 5 * time.Second
	err := validateStatefulSetsByNamespace(namespaces, statefulsetsByNamespace, clientset, interval, timeout)
	if err != ErrNoStatefulSet {
		t.Fatalf("expected ErrNoStatefulSet, got: %v", err)
	}
}

func TestValidateStatefulSetsByNamespaceStatefulSetFailed(t *testing.T) {
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
	faultySS := appsv1.StatefulSetList{
		Items: []appsv1.StatefulSet{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      testStset,
					Namespace: testNS,
				},
				Spec: appsv1.StatefulSetSpec{
					Selector: &metav1.LabelSelector{
						MatchLabels: testLabels,
					},
				},
				Status: appsv1.StatefulSetStatus{
					AvailableReplicas: 0,
				},
			},
		},
	}

	clientset := fake.NewSimpleClientset(&faultySS, &faultyPods)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: ErrStatefulSetNotHealthy}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	statefulsetsByNamespace := make(map[string][]appsv1.StatefulSet)
	statefulsetsByNamespace[testNS] = faultySS.Items
	interval := 1 * time.Second
	timeout := 5 * time.Second
	err := validateStatefulSetsByNamespace(namespaces, statefulsetsByNamespace, clientset, interval, timeout)
	if err != ErrStatefulSetFailed {
		t.Fatalf("expected ErrStatefulSetFailed, got: %v", err)
	}
}

func TestValidateStatefulSetsByNamespacePodFailed(t *testing.T) {
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

	clientset := fake.NewSimpleClientset(&testSSList, &faultyPods)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: nil}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	statefulsetsByNamespace := make(map[string][]appsv1.StatefulSet)
	statefulsetsByNamespace[testNS] = testSSList.Items
	interval := 1 * time.Second
	timeout := 5 * time.Second
	err := validateStatefulSetsByNamespace(namespaces, statefulsetsByNamespace, clientset, interval, timeout)
	if err != ErrStatefulSetFailed {
		t.Fatalf("expected ErrStatefulSetFailed, got: %v", err)
	}
}

func TestCheckStatefulSets(t *testing.T) {
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
	clientset := fake.NewSimpleClientset(&testSSList, &testPods)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: nil}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	interval := 1 * time.Second
	timeout := 5 * time.Second
	err := CheckStatefulSets(namespaces, clientset, interval, timeout)
	if err != nil {
		t.Fatalf("expected nil, got: %v", err)
	}
}

func TestCheckStatefulSetsNoNamespace(t *testing.T) {
	clientset := fake.NewSimpleClientset(&testSSList)
	// TODO: Come up with good way to write this
	retryer = &mockRetryer{err: nil}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{}
	interval := 1 * time.Second
	timeout := 5 * time.Second
	err := CheckStatefulSets(namespaces, clientset, interval, timeout)
	if err != ErrNoNamespace {
		t.Fatalf("expected ErrNoNamespace, got: %v", err)
	}
}
