package statefulset

import (
	"context"
	"errors"
	"time"

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
	ErrListingStatefulSet    = errors.New("error listing statefulsets in namespace")
	ErrNoStatefulSet         = errors.New("error no statefulset found inside namespace")
	ErrNoNamespace           = errors.New("error no namespace provided")
	ErrStatefulSetNotHealthy = errors.New("error statefulset not in healthy state")
	ErrNamespaceEmpty        = errors.New("error namespace list empty")
	ErrInvalidInterval       = errors.New("error interval or timeout is invalid")
	ErrStatefulSetFailed     = errors.New("error statefulset test validation failed")
)

func getStatefulSet(namespace string, clientset kubernetes.Interface) (*appsv1.StatefulSetList, error) {
	statefulset, err := clientset.AppsV1().StatefulSets(namespace).List(context.Background(), metav1.ListOptions{})
	if err != nil {
		return nil, ErrListingStatefulSet
	}
	if len(statefulset.Items) <= 0 {
		return nil, ErrNoStatefulSet
	}
	return statefulset, nil
}
func storeStatefulSetsByNamespace(namespaces []string, clientset kubernetes.Interface) (map[string][]appsv1.StatefulSet, error) {
	if len(namespaces) <= 0 {
		logger.AppLog.LogWarning("no namespace provided")
		return nil, ErrNoNamespace
	}
	statefulsetsByNamespace := make(map[string][]appsv1.StatefulSet)
	for _, namespace := range namespaces {
		logger.AppLog.LogInfo("Checking StatefulSets status inside namespace %s\n", namespace)
		// If namespace name is invalid
		if namespace != "" {
			statefulSetList, err := getStatefulSet(namespace, clientset)
			// unable to get the statefulsets
			if err != nil {
				if errors.Is(err, ErrNoStatefulSet) {
					continue
				}
				return nil, err
			}
			// Store the statefulsets by namespace in the map
			statefulsetsByNamespace[namespace] = statefulSetList.Items
		} else {
			logger.AppLog.LogError("invalid namespace provided: %s\n", namespace)
		}
	}
	if len(statefulsetsByNamespace) <= 0 {
		logger.AppLog.LogWarning("there is no statefulset in provided namespace: %v\n", namespaces)
		return nil, ErrNoStatefulSet
	}
	return statefulsetsByNamespace, nil
}

func checkStatefulSetStatus(namespace string, statefulset appsv1.StatefulSet, clientset kubernetes.Interface) error {
	err := retryer.RetryOnConflict(retry.DefaultRetry, func() error {
		updatedStatefulSet, err := clientset.AppsV1().StatefulSets(namespace).Get(context.Background(), statefulset.Name, metav1.GetOptions{})
		if err != nil {
			return err
		}
		if updatedStatefulSet.Status.UpdatedReplicas == *statefulset.Spec.Replicas &&
			updatedStatefulSet.Status.Replicas == *statefulset.Spec.Replicas &&
			updatedStatefulSet.Status.CurrentReplicas == *statefulset.Spec.Replicas &&
			updatedStatefulSet.Status.ObservedGeneration >= statefulset.Generation {
			logger.AppLog.LogInfo("statefulset %s is available in namespace %s\n", statefulset.Name, namespace)
			return nil
		} else {
			logger.AppLog.LogWarning("statefulset %s is not available in namespace %s. checking condition\n", statefulset.Name, namespace)
			for _, condition := range updatedStatefulSet.Status.Conditions {
				if condition.Type == "StatefulSetReplicasReady" && condition.Status == corev1.ConditionFalse {
					logger.AppLog.LogError("reason: %v\n", condition.Reason)
					break
				}
			}
		}
		logger.AppLog.LogWarning("waiting for statefulset %s to be available in namespace %s\n", statefulset.Name, namespace)
		logger.AppLog.LogWarning("statefulset %s is not in healthy state inside namespace %s\n", statefulset.Name, namespace)
		return ErrStatefulSetNotHealthy
	})
	return err
}
func validateStatefulSetsByNamespace(namespaces []string, statefulsetsByNamespace map[string][]appsv1.StatefulSet, clientset kubernetes.Interface, interval, timeout time.Duration) error {
	var stsErrorList []error
	var podErrList []error
	if len(namespaces) <= 0 {
		logger.AppLog.LogError("namespace list empty %v. no namespace provided. please provide atleast one namespace\n", namespaces)
		return ErrNamespaceEmpty
	}
	if len(statefulsetsByNamespace) <= 0 {
		return ErrNoStatefulSet
	}
	if interval.Seconds() <= 0 || timeout.Seconds() <= 0 {
		logger.AppLog.LogError("interval or timeout is invalid. please provide the valid interval or timeout duration\n")
		return ErrInvalidInterval
	}
	for _, namespace := range namespaces {
		for _, statefulset := range statefulsetsByNamespace[namespace] {
			err := wait.PollUntilContextTimeout(context.TODO(), interval, timeout, false, func(context.Context) (bool, error) {
				err := checkStatefulSetStatus(namespace, statefulset, clientset)
				if err != nil {
					return false, err
				}
				return true, nil
			})
			if err != nil {
				logger.AppLog.LogError("error checking the statefulset %s in namespace %s reason: %v\n", statefulset.Name, namespace, err)
				stsErrorList = append(stsErrorList, err)
			}
			err = wait.PollUntilContextTimeout(context.TODO(), interval, timeout, false, func(context.Context) (bool, error) {
				err := pod.GetPodStatus(namespace, labels.SelectorFromSet(statefulset.Spec.Selector.MatchLabels), clientset)
				if err != nil {
					return false, err
				}
				return true, nil
			})
			if err != nil {
				logger.AppLog.LogError("error checking the pod logs for statefulset %s in namespace %s, reason: %v\n", statefulset.Name, namespace, err)
				podErrList = append(podErrList, err)
			}

		}
	}
	if len(stsErrorList) != 0 || len(podErrList) != 0 {
		logger.AppLog.LogError("to many errors. statefulsets validation test's failed\n")
		return ErrStatefulSetFailed
	}
	return nil
}
func CheckStatefulSets(namespace []string, clientset kubernetes.Interface, interval, timeout time.Duration) error {
	logger.AppLog.LogInfo("Begin StatefulSet validation")
	statefulsetsByNamespace, err := storeStatefulSetsByNamespace(namespace, clientset)
	if err != nil {
		if errors.Is(err, ErrNoStatefulSet) {
			logger.AppLog.LogWarning("no statefulset found in namespace. skipping statefulset validations\n")
			return nil
		}
		return err
	}
	err = validateStatefulSetsByNamespace(namespace, statefulsetsByNamespace, clientset, interval, timeout)
	if err != nil {
		return err
	}
	logger.AppLog.LogInfo("End StatefulSet validation")
	return nil
}
