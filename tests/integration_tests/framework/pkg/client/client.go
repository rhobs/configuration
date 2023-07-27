package client

import (
	"github.com/rhobs/configuration/tests/integration_tests/framework/pkg/logger"

	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

func client(kubeconfig string) *kubernetes.Clientset {
	var (
		config *rest.Config
		err    error
	)
	// If no kubeconfig file specified, then use in-cluster config
	if kubeconfig == "" {
		config, err = rest.InClusterConfig()
		if err != nil {
			logger.AppLog.LogFatal("Error getting in-cluster config: %v\n", err)
		}
	} else {
		// If kubeconfig file is specified, then use it
		config, err = clientcmd.BuildConfigFromFlags("", kubeconfig)
		if err != nil {
			logger.AppLog.LogFatal("Error building kubeconfig from file %s: %v\n", kubeconfig, err)
		}
	}
	// Create Kubernetes clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		logger.AppLog.LogFatal("Error creating Kubernetes clientset: %v\n", err)
	}
	return clientset
}
func GetClient(kubeconfig string) *kubernetes.Clientset {
	return client(kubeconfig)
}
