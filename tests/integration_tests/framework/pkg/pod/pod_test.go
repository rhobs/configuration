package pod

import (
	"testing"

	"github.com/rhobs/configuration/tests/integration_tests/framework/pkg/logger"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/client-go/kubernetes/fake"
)

var (
	testNS        = "test-namespace"
	testPod       = "test-pod"
	testContainer = "test-container"
	testImage     = "quay.io/foo/bar:latest"
	testLabels    = make(map[string]string)
	testPodList   = corev1.PodList{
		Items: []corev1.Pod{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      testPod,
					Namespace: testNS,
					Labels:    testLabels,
				},
				Status: corev1.PodStatus{
					Phase: corev1.PodRunning,
					ContainerStatuses: []corev1.ContainerStatus{
						{
							RestartCount: 0,
							State: corev1.ContainerState{
								Running: &corev1.ContainerStateRunning{
									StartedAt: metav1.Now(),
								},
							},
						},
					},
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  testContainer,
							Image: testImage,
						},
					},
				},
			},
		},
	}
)

func TestCheckPodStatus(t *testing.T) {
	clientset := fake.NewSimpleClientset(&testPodList)
	logger.NewLogger(logger.LevelInfo)
	err := checkPodStatus(testNS, testPodList, clientset)
	if err != nil {
		t.Fatalf("expected nil got: %v", err)
	}
}
func TestCheckPodStatusNoNamespace(t *testing.T) {
	clientset := fake.NewSimpleClientset(&testPodList)
	logger.NewLogger(logger.LevelInfo)
	err := checkPodStatus("", testPodList, clientset)
	if err != ErrNoNamespace {
		t.Fatalf("expected ErrNoNamespace, got: %v", err)
	}
}
func TestCheckPodStatusNoPod(t *testing.T) {
	podList := corev1.PodList{}
	clientset := fake.NewSimpleClientset()
	logger.NewLogger(logger.LevelInfo)
	err := checkPodStatus(testNS, podList, clientset)
	if err != ErrNoPod {
		t.Fatalf("expected ErrNoPod, got: %v", err)
	}
}
func TestCheckPodStatusNoRunningPod(t *testing.T) {
	faultyPodList := corev1.PodList{
		Items: []corev1.Pod{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      testPod,
					Namespace: testNS,
				},
				Status: corev1.PodStatus{
					Phase: corev1.PodPending,
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  testContainer,
							Image: testImage,
						},
					},
				},
			},
		},
	}
	clientset := fake.NewSimpleClientset(&faultyPodList)
	logger.NewLogger(logger.LevelInfo)
	err := checkPodStatus(testNS, faultyPodList, clientset)
	if err != ErrPodNotRunning {
		t.Fatalf("expected ErrPodNotRunning. got: %v", err)
	}
}

func TestCheckPodHealth(t *testing.T) {
	testLabels["app"] = "test-app"
	logger.NewLogger(logger.LevelInfo)
	ls := labels.SelectorFromSet(testLabels)
	clientset := fake.NewSimpleClientset(&testPodList)
	err := checkPodHealth(testNS, ls, clientset)
	if err != nil {
		t.Fatalf("expected nil, got: %v", err)
	}
}
func TestCheckPodHealthNoNamespace(t *testing.T) {
	testLabels["app"] = "test-app"
	logger.NewLogger(logger.LevelInfo)
	ls := labels.SelectorFromSet(testLabels)
	clientset := fake.NewSimpleClientset(&testPodList)
	err := checkPodHealth("", ls, clientset)
	if err != ErrNoNamespace {
		t.Fatalf("expected ErrNoNamespace, got: %v", err)
	}
}

func TestCheckPodHealthNoPod(t *testing.T) {
	logger.NewLogger(logger.LevelInfo)
	ls := labels.SelectorFromSet(testLabels)
	clientset := fake.NewSimpleClientset(&testPodList)
	err := checkPodHealth("testNS", ls, clientset)
	if err != ErrNoPod {
		t.Fatalf("expected ErrNoPod, got: %v", err)
	}
}
func TestCheckPodHealthNoRunningPod(t *testing.T) {
	testLabels["app"] = "test-app"
	faultyPodList := corev1.PodList{
		Items: []corev1.Pod{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      testPod,
					Namespace: testNS,
					Labels:    testLabels,
				},
				Status: corev1.PodStatus{
					Phase: corev1.PodPending,
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  testContainer,
							Image: testImage,
						},
					},
				},
			},
		},
	}

	clientset := fake.NewSimpleClientset(&faultyPodList)
	logger.NewLogger(logger.LevelInfo)
	ls := labels.SelectorFromSet(testLabels)
	err := checkPodHealth(testNS, ls, clientset)
	if err != ErrPodNotRunning {
		t.Fatalf("expected ErrPodNotRunning, got: %v", err)
	}

}
func TestCheckPodHealthWithRestartingContainer(t *testing.T) {
	faultyPodList := corev1.PodList{
		Items: []corev1.Pod{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      testPod,
					Namespace: testNS,
					Labels:    testLabels,
				},
				Status: corev1.PodStatus{
					Phase: corev1.PodRunning,
					ContainerStatuses: []corev1.ContainerStatus{
						{
							RestartCount: 1,
							State: corev1.ContainerState{
								Waiting: &corev1.ContainerStateWaiting{
									Reason: "CrashLoopBackOff",
								},
							},
							LastTerminationState: corev1.ContainerState{
								Terminated: &corev1.ContainerStateTerminated{
									Reason: "error",
								},
							},
						},
					},
				},
			},
		},
	}
	clientset := fake.NewSimpleClientset(&faultyPodList)
	logger.NewLogger(logger.LevelInfo)
	ls := labels.SelectorFromSet(testLabels)
	err := checkPodHealth(testNS, ls, clientset)
	if err == nil {
		t.Errorf("expected an error due to restarting container, got: %v", err)
	}
}

func TestGetPodStatus(t *testing.T) {
	ls := labels.SelectorFromSet(testLabels)
	clientset := fake.NewSimpleClientset(&testPodList)
	logger.NewLogger(logger.LevelInfo)
	err := GetPodStatus(testNS, ls, clientset)
	if err != nil {
		t.Fatalf("expected nil, got: %v", err)
	}
}
func TestGetPodStatusNoNamespace(t *testing.T) {
	ls := labels.SelectorFromSet(testLabels)
	clientset := fake.NewSimpleClientset(&testPodList)
	logger.NewLogger(logger.LevelInfo)
	err := GetPodStatus("", ls, clientset)
	if err != ErrNoNamespace {
		t.Fatalf("expected ErrNoNamespace, got: %v", err)
	}
}
