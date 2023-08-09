package deployment

import (
	"context"
	"time"

	"errors"

	"github.com/rhobs/configuration/tests/integration_tests/framework/pkg/logger"
	"github.com/rhobs/configuration/tests/integration_tests/framework/pkg/pod"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/util/retry"
)

// TODO: Come up with better solution
// This is done so that unit test can work fine as retry.RetryOnConflict only works on real Kubernetes cluster
// we are using fake to build up mock client for UT
type Retryer interface {
	RetryOnConflict(backoff wait.Backoff, fn func() error) error
}

type DefaultRetryer struct{}

func (r *DefaultRetryer) RetryOnConflict(backoff wait.Backoff, fn func() error) error {
	return retry.RetryOnConflict(backoff, fn)
}

var (
	retryer Retryer = &DefaultRetryer{}
)

var (
	ErrListingDeployment     = errors.New("error listing deployments in namespace")
	ErrNoDeployment          = errors.New("error no deployments found inside namespace")
	ErrNoNamespace           = errors.New("error no namespace provided")
	ErrDeploymentsNotHealthy = errors.New("error deployment not in healthy state")
	ErrNamespaceEmpty        = errors.New("error namespace list empty")
	ErrInvalidInterval       = errors.New("error interval or timeout is invalid")
	ErrDeploymentFailed      = errors.New("error deployment test validation failed")
)

func getDeployment(namespace string, clientset kubernetes.Interface) (*appsv1.DeploymentList, error) {
	deployment, err := clientset.AppsV1().Deployments(namespace).List(context.Background(), metav1.ListOptions{})
	if err != nil {
		return nil, ErrListingDeployment
	}
	if len(deployment.Items) <= 0 {
		return nil, ErrNoDeployment
	}
	return deployment, nil
}
func storeDeploymentsByNamespace(namespaces []string, clientset kubernetes.Interface) (map[string][]appsv1.Deployment, error) {
	if len(namespaces) <= 0 {
		logger.AppLog.LogWarning("no namespace provided")
		return nil, ErrNoNamespace
	}
	deploymentsByNamespace := make(map[string][]appsv1.Deployment)
	for _, namespace := range namespaces {
		logger.AppLog.LogInfo("Checking Deployments status inside namespace %s\n", namespace)
		// If namespace name is invalid
		if namespace != "" {
			deploymentList, err := getDeployment(namespace, clientset)
			// unable to get deployments
			if err != nil {
				return nil, err
			}
			deploymentsByNamespace[namespace] = deploymentList.Items
		} else {
			logger.AppLog.LogError("invalid namespace provided: %s\n", namespace)
		}

	}
	if len(deploymentsByNamespace) <= 0 {
		logger.AppLog.LogWarning("there is no deployment in provided namespaces: %v\n", namespaces)
		return nil, ErrNoDeployment
	}
	return deploymentsByNamespace, nil
}
func checkDeploymentStatus(namespace string, deployment appsv1.Deployment, clientset kubernetes.Interface) error {
	err := retryer.RetryOnConflict(retry.DefaultRetry, func() error {
		updatedDeployment, err := clientset.AppsV1().Deployments(namespace).Get(context.Background(), deployment.Name, metav1.GetOptions{})
		if err != nil {
			return err
		}
		if updatedDeployment.Status.UpdatedReplicas == *deployment.Spec.Replicas &&
			updatedDeployment.Status.Replicas == *deployment.Spec.Replicas &&
			updatedDeployment.Status.AvailableReplicas == *deployment.Spec.Replicas &&
			updatedDeployment.Status.ObservedGeneration >= deployment.Generation {
			logger.AppLog.LogInfo("deployment %s is available in namespace %s\n", deployment.Name, namespace)
			return nil
		} else {
			logger.AppLog.LogWarning("deployment %s is not available in namespace %s. Checking condition\n", deployment.Name, namespace)
			for _, condition := range updatedDeployment.Status.Conditions {
				if condition.Type == appsv1.DeploymentAvailable && condition.Status == corev1.ConditionFalse {
					logger.AppLog.LogError("reason: %v\n", condition.Reason)
					break
				}
			}
		}
		logger.AppLog.LogWarning("waiting for deployment %s to be available in namespace %s\n", deployment.Name, namespace)
		logger.AppLog.LogWarning("deployment %v is not in healthy state inside namespace %v\n", deployment.Name, namespace)
		return ErrDeploymentsNotHealthy
	})
	return err
}
func validateDeploymentsByNamespace(namespaces []string, deploymentsByNamespace map[string][]appsv1.Deployment, clientset kubernetes.Interface, interval, timeout time.Duration) error {
	var depErrList []error
	var podErrList []error
	if len(namespaces) <= 0 {
		logger.AppLog.LogError("namespace list empty %v. no namespace provided. please provide atleast one namespace\n", namespaces)
		return ErrNamespaceEmpty
	}
	if len(deploymentsByNamespace) <= 0 {
		return ErrNoDeployment
	}
	if interval.Seconds() <= 0 || timeout.Seconds() <= 0 {
		logger.AppLog.LogError("interval or timeout is invalid. please provide the valid interval or timeout duration\n")
		return ErrInvalidInterval
		// fmt.Errorf("interval or timeout is invalid. please provide the valid interval or timeout duration\n")
	}
	for _, namespace := range namespaces {
		for _, deployment := range deploymentsByNamespace[namespace] {
			err := wait.PollUntilContextTimeout(context.TODO(), interval, timeout, false, func(context.Context) (bool, error) {
				err := checkDeploymentStatus(namespace, deployment, clientset)
				if err != nil {
					return false, err
				}
				return true, nil

			})
			if err != nil {
				logger.AppLog.LogError("error checking the deployment %s in namespace %s reason: %v\n", deployment.Name, namespace, err)
				depErrList = append(depErrList, err)
			}
			err = wait.PollUntilContextTimeout(context.TODO(), interval, timeout, false, func(context.Context) (bool, error) {
				err := pod.GetPodStatus(namespace, labels.SelectorFromSet(deployment.Spec.Selector.MatchLabels), clientset)
				if err != nil {
					return false, err
				}
				return true, nil
			})
			if err != nil {
				logger.AppLog.LogError("error checking the pod logs of deployment %s in namespace %s, reason: %v\n", deployment.Name, namespace, err)
				podErrList = append(podErrList, err)
			}

		}
	}
	if len(depErrList) != 0 || len(podErrList) != 0 {
		logger.AppLog.LogError("to many errors. deployment validation test's failed\n")
		return ErrDeploymentFailed
	}
	return nil
}
func CheckDeployments(namespace []string, clientset kubernetes.Interface, interval, timeout time.Duration) error {
	logger.AppLog.LogInfo("Begin Deployment validation")
	deploymentsByNamespace, err := storeDeploymentsByNamespace(namespace, clientset)
	if err != nil {
		if errors.Is(err, ErrNoDeployment) {
			logger.AppLog.LogWarning("no deployment found in namespace, skipping deployment validations\n")
			return nil
		}
		return err
	}
	err = validateDeploymentsByNamespace(namespace, deploymentsByNamespace, clientset, interval, timeout)
	if err != nil {
		return err
	}
	logger.AppLog.LogInfo("End Deployment validation")
	return nil
}
