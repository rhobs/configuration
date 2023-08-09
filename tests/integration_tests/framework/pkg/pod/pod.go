package pod

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/rhobs/configuration/tests/integration_tests/framework/pkg/logger"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/client-go/kubernetes"
)

var (
	ErrFetchLogs     = errors.New("error cannot fetch container logs inside pod")
	ErrNoNamespace   = errors.New("error no namespace provided")
	ErrListingPods   = errors.New("error listing pods in namespace")
	ErrPodNotRunning = errors.New("error pod is not running in namespace")
	ErrNoPod         = errors.New("error cannot find pod in namespace")
)

func getPodLogs(namespace string, clientset kubernetes.Interface, pod corev1.Pod) error {
	tailline := int64(10)
	seconds := int64(300)
	for _, container := range pod.Spec.Containers {
		logs, err := clientset.CoreV1().Pods(namespace).GetLogs(pod.Name, &corev1.PodLogOptions{Container: container.Name, SinceSeconds: &seconds, TailLines: &tailline}).Do(context.Background()).Raw()
		if err != nil {
			logger.AppLog.LogError("cannot fetch container: %s log's inside pod: %s error: %v\n", container.Name, pod.Name, err)
			return ErrFetchLogs
		}
		for _, line := range strings.Split(string(logs), "\\n") {
			if strings.Contains(line, "error") || strings.Contains(line, "Error") || strings.Contains(line, "Exception") || strings.Contains(line, "exception") {
				logger.AppLog.LogError("container: %s inside pod: %s has errors in logs:", container.Name, pod.Name)
				logger.AppLog.LogSeperator()
				logger.AppLog.LogError("Log Line: %s", line)
				logger.AppLog.LogSeperator()
			} else {
				logger.AppLog.LogDebug("container: %s inside pod: %s has no errors in logs\n", container.Name, pod.Name)
			}
		}
	}
	return nil
}

func checkPodHealth(namespace string, labels labels.Selector, clientset kubernetes.Interface) error {

	if len(namespace) <= 0 {
		return ErrNoNamespace
	}
	podList, err := clientset.CoreV1().Pods(namespace).List(context.Background(), metav1.ListOptions{LabelSelector: labels.String()})
	if err != nil {
		logger.AppLog.LogError("cannot list pods inside namespace %s, err: %v\n", namespace, err)
		return ErrListingPods
	}
	err = checkPodStatus(namespace, *podList, clientset)
	if err != nil {
		return err
	}
	logger.AppLog.LogInfo("Checking for error's/exception's in pod logs")
	for _, pod := range podList.Items {
		if pod.Status.Phase != "Running" {
			logger.AppLog.LogInfo("pod: %s is not running inside namespace: %s\n", pod.Name, namespace)
			return ErrPodNotRunning
		}
		err = getPodLogs(namespace, clientset, pod)
		if err != nil {
			logger.AppLog.LogError("error checking pod logs in namespace %s\n", namespace)
			return err
		}
	}
	return nil
}
func checkPodStatus(namespace string, podList corev1.PodList, clientset kubernetes.Interface) error {
	if len(namespace) <= 0 {
		return ErrNoNamespace
	}
	if len(podList.Items) <= 0 {
		return ErrNoPod
	}

	for _, pod := range podList.Items {
		logger.AppLog.LogDebug("pod name: %s", pod.Name)
		if pod.Status.Phase != "Running" {
			logger.AppLog.LogError("pod: %s is not running inside namespace: %s\n", pod.Name, namespace)
			return ErrPodNotRunning

		}
		for _, container := range pod.Status.ContainerStatuses {
			if container.RestartCount >= 1 && container.State.Waiting != nil && container.LastTerminationState.Terminated != nil {
				err := getPodLogs(namespace, clientset, pod)
				if err != nil {
					return err
				}
				return fmt.Errorf("pod: %s has restart count: %d\ncurrent state: message: %s, reason: %s \nlast state: message: %s, reason: %s\n", container.Name, container.RestartCount, container.State.Waiting.Message, container.State.Waiting.Reason, container.LastTerminationState.Terminated.Message, container.LastTerminationState.Terminated.Reason)
			}
		}
	}
	return nil
}
func GetPodStatus(namespace string, labels labels.Selector, clientset kubernetes.Interface) error {
	logger.AppLog.LogInfo("Checking pod status")
	return checkPodHealth(namespace, labels, clientset)
}
