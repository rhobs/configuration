package service

import (
	"testing"
	"time"

	"github.com/rhobs/configuration/tests/integration_tests/framework/pkg/logger"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes/fake"
)

var (
	testNS      = "test-namespace"
	testSvc     = "test-service"
	testSvcList = corev1.ServiceList{
		Items: []corev1.Service{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      testSvc,
					Namespace: testNS,
				},
				Spec: corev1.ServiceSpec{
					Type: corev1.ServiceTypeClusterIP,
					Ports: []corev1.ServicePort{
						{
							Protocol: corev1.ProtocolTCP,
							Port:     9090,
							Name:     "TCP",
						},
					},
				},
			},
		},
	}
	testEndpointList = corev1.EndpointsList{
		Items: []corev1.Endpoints{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      testSvc,
					Namespace: testNS,
				},
				Subsets: []corev1.EndpointSubset{
					{
						Ports: []corev1.EndpointPort{
							{
								Name: "TCP",
								Port: 9090,
							},
						},
						Addresses: []corev1.EndpointAddress{
							{
								IP:       "127.0.0.1",
								Hostname: "host1",
							},
						},
					},
				},
			},
		},
	}
)

func TestGetService(t *testing.T) {
	clientset := fake.NewSimpleClientset(&testSvcList)
	logger.NewLogger(logger.LevelInfo)
	svc, err := getService(testNS, clientset)
	if err != nil {
		t.Fatalf("expected nil, got: %v", err)
	}
	if len(svc.Items) != 1 {
		t.Errorf("expected 1 service, got: %v", len(svc.Items))
	}

}
func TestGetServiceNoNamespace(t *testing.T) {
	clientset := fake.NewSimpleClientset(&testSvcList)
	logger.NewLogger(logger.LevelInfo)
	_, err := getService("", clientset)
	if err != ErrNoNamespace {
		t.Fatalf("expected ErrNoNamespace, got: %v", err)
	}
}
func TestGetServiceNoService(t *testing.T) {
	clienset := fake.NewSimpleClientset()
	logger.NewLogger(logger.LevelInfo)
	_, err := getService(testNS, clienset)
	if err != ErrNoService {
		t.Fatalf("expected ErrNoService, got: %v", err)
	}

}
func TestStoreServicesByNamespace(t *testing.T) {
	namespaces := []string{testNS}
	clienset := fake.NewSimpleClientset(&testSvcList)
	logger.NewLogger(logger.LevelInfo)
	serviceByNamespace, err := storeServicesByNamespace(namespaces, clienset)
	if err != nil {
		t.Fatalf("expected nil, got: %v", err)
	}
	if len(serviceByNamespace) != 1 {
		t.Errorf("expected 1 service got: %v", len(serviceByNamespace))
	}
}
func TestStoreServicesByNamespaceNoNamespace(t *testing.T) {
	namespaces := []string{}
	clientset := fake.NewSimpleClientset(&testSvcList)
	logger.NewLogger(logger.LevelInfo)
	_, err := storeServicesByNamespace(namespaces, clientset)
	if err != ErrNoNamespace {
		t.Fatalf("expected ErrNoNamespace, got: %v", err)
	}
}
func TestStoreServicesByNamespaceNoService(t *testing.T) {
	namespace := []string{testNS}
	clientset := fake.NewSimpleClientset()
	logger.NewLogger(logger.LevelInfo)
	_, err := storeServicesByNamespace(namespace, clientset)
	if err != ErrNoService {
		t.Fatalf("expected ErrNoService, got: %v", err)
	}
}
func TestCheckServiceStatus(t *testing.T) {
	logger.NewLogger(logger.LevelInfo)
	clientset := fake.NewSimpleClientset(&testSvcList, &testEndpointList)
	err := checkServiceStatus(testNS, testSvcList.Items[0], clientset)
	if err != nil {
		t.Fatalf("expected nil, got: %v", err)
	}
}
func TestCheckServiceStatusNotHealthy(t *testing.T) {
	faultyEndpointList := corev1.EndpointsList{
		Items: []corev1.Endpoints{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      testSvc,
					Namespace: testNS,
				},
				Subsets: []corev1.EndpointSubset{
					{
						Ports: []corev1.EndpointPort{
							{
								Name: "TCP",
								Port: 9091,
							},
						},
						Addresses: []corev1.EndpointAddress{
							{
								IP:       "127.0.0.1",
								Hostname: "host1",
							},
						},
					},
				},
			},
		},
	}
	logger.NewLogger(logger.LevelInfo)
	clientset := fake.NewSimpleClientset(&testSvcList, &faultyEndpointList)
	err := checkServiceStatus(testNS, testSvcList.Items[0], clientset)
	if err != ErrServiceNotHealthy {
		t.Fatalf("expected ErrServiceNotHealthy, got: %v", err)
	}
}

func TestValidateServiceByNamespace(t *testing.T) {
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	serviceByNamespace := make(map[string][]corev1.Service)
	serviceByNamespace[testNS] = testSvcList.Items
	interval := 1 * time.Second
	timeout := 5 * time.Second
	clientset := fake.NewSimpleClientset(&testSvcList, &testEndpointList)
	err := validateServicesByNamespace(namespaces, serviceByNamespace, clientset, interval, timeout)
	if err != nil {
		t.Fatalf("expected nil, got: %v", err)
	}
}

func TestValidateServiceByNamespaceNoNamespace(t *testing.T) {
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{}
	serviceByNamespace := make(map[string][]corev1.Service)
	serviceByNamespace[testNS] = testSvcList.Items
	interval := 1 * time.Second
	timeout := 5 * time.Second
	clientset := fake.NewSimpleClientset(&testSvcList, &testEndpointList)
	err := validateServicesByNamespace(namespaces, serviceByNamespace, clientset, interval, timeout)
	if err != ErrNamespaceEmpty {
		t.Fatalf("expected ErrNamespaceEmpty, got: %v", err)
	}
}

func TestValidateServiceByNamespaceNoServiceByNamespace(t *testing.T) {
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	serviceByNamespace := make(map[string][]corev1.Service)
	interval := 1 * time.Second
	timeout := 5 * time.Second
	clientset := fake.NewSimpleClientset(&testSvcList, &testEndpointList)
	err := validateServicesByNamespace(namespaces, serviceByNamespace, clientset, interval, timeout)
	if err != ErrNoService {
		t.Fatalf("expected ErrNoService, got: %v", err)
	}

}

func TestValidateServiceByNamespaceInvalidInterval(t *testing.T) {
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	serviceByNamespace := make(map[string][]corev1.Service)
	serviceByNamespace[testNS] = testSvcList.Items
	interval := -1 * time.Second
	timeout := -5 * time.Second
	clientset := fake.NewSimpleClientset(&testSvcList, &testEndpointList)
	err := validateServicesByNamespace(namespaces, serviceByNamespace, clientset, interval, timeout)
	if err != ErrInvalidInterval {
		t.Fatalf("expected ErrInvalidInterval, got: %v", err)
	}
}

func TestValidateServiceByNamespaceServiceFailed(t *testing.T) {
	faultyEndpointList := corev1.EndpointsList{
		Items: []corev1.Endpoints{
			{
				ObjectMeta: metav1.ObjectMeta{
					Name:      testSvc,
					Namespace: testNS,
				},
				Subsets: []corev1.EndpointSubset{
					{
						Ports: []corev1.EndpointPort{
							{
								Name: "TCP",
								Port: 9091,
							},
						},
						Addresses: []corev1.EndpointAddress{
							{
								IP:       "127.0.0.1",
								Hostname: "host1",
							},
						},
					},
				},
			},
		},
	}
	logger.NewLogger(logger.LevelInfo)
	namespaces := []string{testNS}
	serviceByNamespace := make(map[string][]corev1.Service)
	serviceByNamespace[testNS] = testSvcList.Items
	interval := 1 * time.Second
	timeout := 5 * time.Second
	clientset := fake.NewSimpleClientset(&testSvcList, &faultyEndpointList)
	err := validateServicesByNamespace(namespaces, serviceByNamespace, clientset, interval, timeout)
	if err != ErrServiceFailed {
		t.Fatalf("expected ErrServiceFailed, got: %v", err)
	}

}
func TestCheckServices(t *testing.T) {
	namespaces := []string{testNS}
	logger.NewLogger(logger.LevelInfo)
	interval := 1 * time.Second
	timeout := 5 * time.Second
	clientset := fake.NewSimpleClientset(&testSvcList, &testEndpointList)
	err := CheckServices(namespaces, clientset, interval, timeout)
	if err != nil {
		t.Fatalf("expected nil, got: %v", err)
	}

}
func TestCheckServicesNoNamespace(t *testing.T) {
	namespaces := []string{}
	logger.NewLogger(logger.LevelInfo)
	interval := 1 * time.Second
	timeout := 5 * time.Second
	clientset := fake.NewSimpleClientset(&testSvcList, &testEndpointList)
	err := CheckServices(namespaces, clientset, interval, timeout)
	if err != ErrNoNamespace {
		t.Fatalf("expected ErrNoNamespace, got: %v", err)
	}
}
