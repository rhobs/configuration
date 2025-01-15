package main

import (
	"fmt"
	"maps"
	"time"

	"github.com/observatorium/observatorium/configuration_go/abstr/kubernetes/alertmanager"
	kghelpers "github.com/observatorium/observatorium/configuration_go/kubegen/helpers"
	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	"github.com/observatorium/observatorium/configuration_go/kubegen/workload"
	routev1 "github.com/openshift/api/route/v1"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic/encoding"
	monv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	"github.com/rhobs/configuration/services_go/observatorium"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/intstr"
)

const (
	alertManagerName     = "alertmanager"
	alertmanagerTemplate = "alertmanager-template.yaml"

	defaultAlertmanagerReplicas = 2

	defaultAlertManagerImage    = "quay.io/prometheus/alertmanager"
	defaultAlertManagerImageTag = "v0.26.0"

	alertmanagerConfigSecretName = "alertmanager-config"
	alertmanagerConfigSecretKey  = "alertmanager.yaml"
	alertmanagerTLSSecret        = "alertmanager-tls"

	defaultAlertmanagerCPURequest    = "100m"
	defaultAlertmanagerCPULimit      = "5"
	defaultAlertmanagerMemoryRequest = "256Mi"
	defaultAlertmanagerMemoryLimit   = "5Gi"
)

// Alertmanager Generates the Alertmanager configuration for the stage environment.
func (s Stage) Alertmanager() {
	gen := s.generator(alertManagerName)

	const (
		alertManagerImageTag = defaultAlertManagerImageTag

		cpuRequest = defaultAlertmanagerCPURequest
		cpuLimit   = defaultAlertmanagerCPULimit
		memRequest = defaultAlertmanagerMemoryRequest
		memLimit   = defaultAlertmanagerMemoryLimit
	)

	k8s := alertmanagerKubernetes(alertManagerOptions(), manifestOptions{
		image:    defaultAlertManagerImage,
		imageTag: alertManagerImageTag,
		resourceRequirements: resourceRequirements{
			cpuRequest:    cpuRequest,
			cpuLimit:      cpuLimit,
			memoryRequest: memRequest,
			memoryLimit:   memLimit,
		},
	})
	manifests := k8s.Objects()
	enc := alertmanagerPostProcess(manifests)
	gen.Add(alertmanagerTemplate, enc)
	gen.Generate()

}

// Alertmanager Generates the Alertmanager configuration for the production environment.
func (Production) Alertmanager() {
	// todo
}

func alertManagerOptions() *alertmanager.AlertManagerOptions {
	o := alertmanager.NewDefaultOptions()
	o.ConfigFile = alertmanager.NewConfigFile(nil).
		WithExistingResource(alertmanagerConfigSecretName, alertmanagerConfigSecretKey).AsSecret()
	o.ClusterReconnectTimeout = 5 * time.Minute
	return o
}

func alertmanagerKubernetes(opts *alertmanager.AlertManagerOptions, options manifestOptions) *alertmanager.AlertManagerStatefulSet {
	alertmanSts := alertmanager.NewAlertManager(opts, namespace, options.imageTag)
	alertmanSts.Image = options.image
	alertmanSts.Replicas = defaultAlertmanagerReplicas
	alertmanSts.Name = alertManagerName
	alertmanSts.VolumeSize = "1Gi"
	alertmanSts.VolumeType = "gp2"
	alertmanSts.ContainerResources = kghelpers.NewResourcesRequirements(options.cpuRequest, options.cpuLimit, options.memoryRequest, options.memoryLimit)
	alertmanSts.Sidecars = []workload.ContainerProvider{
		makeOauthProxy(9093, namespace, alertmanSts.Name, alertmanagerTLSSecret),
	}

	headlessServiceName := alertmanSts.Name + "-cluster"
	if alertmanSts.Replicas > 1 {
		for i := 0; i < int(alertmanSts.Replicas); i++ {
			opts.ClusterPeer = append(opts.ClusterPeer,
				fmt.Sprintf("%s-%d.%s.%s.svc.cluster.local:9094", alertmanSts.Name, i, headlessServiceName, namespace))
		}
	}
	return alertmanSts
}

func alertmanagerPostProcess(manifests []runtime.Object) encoding.Encoder {
	postProcessServiceMonitor(kghelpers.GetObject[*monv1.ServiceMonitor](manifests, ""), namespace)
	service := kghelpers.GetObject[*corev1.Service](manifests, alertManagerName)
	service.ObjectMeta.Annotations[servingCertSecretNameAnnotation] = alertmanagerTLSSecret
	// Add annotations for openshift oauth so that the route to access the query ui works
	serviceAccount := kghelpers.GetObject[*corev1.ServiceAccount](manifests, "")
	if serviceAccount.Annotations == nil {
		serviceAccount.Annotations = map[string]string{}
	}
	serviceAccount.Annotations[serviceRedirectAnnotation] = fmt.Sprintf(`{"kind":"OAuthRedirectReference","apiVersion":"v1","reference":{"kind":"Route","name":"%s"}}`, alertManagerName)

	// Add route for oauth-proxy
	manifests = append(manifests, &routev1.Route{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Route",
			APIVersion: routev1.SchemeGroupVersion.String(),
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      alertManagerName,
			Namespace: namespace,
			Labels:    maps.Clone(kghelpers.GetObject[*appsv1.StatefulSet](manifests, "").ObjectMeta.Labels),
			Annotations: map[string]string{
				"cert-manager.io/issuer-kind": "ClusterIssuer",
				"cert-manager.io/issuer-name": "letsencrypt-prod-http",
			},
		},
		Spec: routev1.RouteSpec{
			Port: &routev1.RoutePort{
				TargetPort: intstr.FromString("https"),
			},
			TLS: &routev1.TLSConfig{
				Termination:                   routev1.TLSTerminationReencrypt,
				InsecureEdgeTerminationPolicy: routev1.InsecureEdgeTerminationPolicyRedirect,
			},
			To: routev1.RouteTargetReference{
				Kind: "Service",
				Name: alertManagerName,
			},
		},
	})

	// Set encoders and template params
	params := []templatev1.Parameter{}
	params = append(params, templatev1.Parameter{
		Name:     "OAUTH_PROXY_COOKIE_SECRET",
		Generate: "expression",
		From:     "[a-zA-Z0-9]{40}",
	})
	alertEncoder := observatorium.NewStdTemplateYAML(alertManagerName, "ALERTMANAGER").WithLogLevel()
	params = append(params, alertEncoder.TemplateParams()...)
	template := openshift.WrapInTemplate(manifests, metav1.ObjectMeta{
		Name: alertManagerName,
	}, sortTemplateParams(params))
	return alertEncoder.Wrap(encoding.GhodssYAML(template))
}
