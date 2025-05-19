package main

import (
	"encoding/json"
	"fmt"

	"github.com/ghodss/yaml"
	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic"
	"github.com/philipgough/mimic/encoding"
	monitoringv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	cfgobservatorium "github.com/rhobs/configuration/configuration/observatorium"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/intstr"
)

const (
	gatewayName     = "observatorium-api"
	gatewayTemplate = "observatorium-api-template.yaml"

	componentOPAAMS      = "opa-ams"
	componentJaegerAgent = "jaeger-agent"

	qfeService    = "thanos-query-frontend-rhobs"
	routerService = "thanos-receive-router-rhobs"
)

type gatewayConfig struct {
	namespace string
	generator func(component string) *mimic.Generator
	tenants   *corev1.Secret
	amsURL    string
	m         TemplateMaps
}

// Gateway Generates the Observatorium API Gateway configuration for the stage environment.
func (s Stage) Gateway() error {
	conf := gatewayConfig{
		namespace: s.namespace(),
		generator: s.generator,
		amsURL:    "https://api.stage.openshift.com",
		m:         StageMaps,
		tenants:   stageGatewayTenants(StageMaps, s.namespace()),
	}
	return gateway(conf)
}

// Gateway Generates the Observatorium API Gateway configuration for the production environment.
func (p Production) Gateway() error {
	conf := gatewayConfig{
		namespace: p.namespace(),
		generator: p.generator,
		amsURL:    "https://api.openshift.com",
		m:         ProductionMaps,
		tenants:   prodGatewayTenants(ProductionMaps, p.namespace()),
	}
	return gateway(conf)
}

func gateway(c gatewayConfig) error {
	ns := c.namespace
	b, err := json.Marshal(cfgobservatorium.GenerateRBAC())
	if err != nil {
		return fmt.Errorf("failed to marshal RBAC configuration: %w", err)
	}
	rbacYAML, err := yaml.JSONToYAML(b)
	if err != nil {
		return fmt.Errorf("failed to convert RBAC configuration to YAML: %w", err)
	}

	objs := []runtime.Object{
		gatewayRBAC(StageMaps, ns, string(rbacYAML)),
		gatewayDeployment(StageMaps, ns, c.amsURL),
		createGatewayService(StageMaps, ns),
		c.tenants,
	}
	gen := c.generator(gatewayName)
	template := openshift.WrapInTemplate(objs, metav1.ObjectMeta{
		Name: gatewayName,
	}, gatewayTemplateParams)
	enc := encoding.GhodssYAML(template)
	gen.Add(gatewayTemplate, enc)
	gen.Generate()

	sms := []runtime.Object{
		gatewayServiceMonitor(StageMaps, ns),
	}
	gen = c.generator(gatewayName)
	template = openshift.WrapInTemplate(sms, metav1.ObjectMeta{
		Name: gatewayName + "-service-monitor",
	}, nil)
	gen.Add("service-monitor-"+gatewayTemplate, encoding.GhodssYAML(template))
	gen.Generate()

	return nil
}

func gatewayLabels(m TemplateMaps) (labels map[string]string, selectorLabels map[string]string) {
	selectorLabels = map[string]string{
		"app.kubernetes.io/component": "api",
		"app.kubernetes.io/instance":  "rhobs",
		"app.kubernetes.io/name":      gatewayName,
		"app.kubernetes.io/part-of":   "rhobs",
	}

	metaLabels := deepCopyMap(selectorLabels)
	metaLabels["app.kubernetes.io/version"] = m.Versions[observatoriumAPI]
	return metaLabels, selectorLabels
}

func gatewayDeployment(m TemplateMaps, namespace, amsURL string) *appsv1.Deployment {
	metaLabels, selectorLabels := gatewayLabels(m)
	replicas := m.Replicas[observatoriumAPI]
	return &appsv1.Deployment{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Deployment",
			APIVersion: "apps/v1",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      gatewayName,
			Namespace: namespace,
			Labels:    metaLabels,
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: &replicas,
			Selector: &metav1.LabelSelector{
				MatchLabels: selectorLabels,
			},
			Strategy: appsv1.DeploymentStrategy{
				Type: appsv1.RollingUpdateDeploymentStrategyType,
				RollingUpdate: &appsv1.RollingUpdateDeployment{
					MaxUnavailable: &intstr.IntOrString{Type: intstr.Int, IntVal: 1},
					MaxSurge:       &intstr.IntOrString{Type: intstr.Int, IntVal: 0},
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: metaLabels,
				},
				Spec: corev1.PodSpec{
					ServiceAccountName: gatewayName,
					Volumes: []corev1.Volume{
						{
							Name: "rbac",
							VolumeSource: corev1.VolumeSource{
								ConfigMap: &corev1.ConfigMapVolumeSource{
									LocalObjectReference: corev1.LocalObjectReference{
										Name: gatewayName,
									},
								},
							},
						},
						{
							Name: "tenants",
							VolumeSource: corev1.VolumeSource{
								Secret: &corev1.SecretVolumeSource{
									SecretName: gatewayName,
								},
							},
						},
					},
					Containers: []corev1.Container{
						createObservatoriumAPIContainer(m, namespace),
						createOPAAMSContainer(m, namespace, amsURL),
						createJaegerAgentContainer(m),
					},
					Affinity: &corev1.Affinity{
						PodAntiAffinity: &corev1.PodAntiAffinity{
							PreferredDuringSchedulingIgnoredDuringExecution: []corev1.WeightedPodAffinityTerm{
								{
									Weight: 100,
									PodAffinityTerm: corev1.PodAffinityTerm{
										LabelSelector: &metav1.LabelSelector{
											MatchExpressions: []metav1.LabelSelectorRequirement{
												{
													Key:      "app.kubernetes.io/name",
													Operator: metav1.LabelSelectorOpIn,
													Values:   []string{gatewayName},
												},
											},
										},
										TopologyKey: "kubernetes.io/hostname",
									},
								},
							},
						},
					},
				},
			},
		},
	}
}

func createObservatoriumAPIContainer(m TemplateMaps, namespace string) corev1.Container {
	logLevel := TemplateFn(observatoriumAPI, m.LogLevels)
	return corev1.Container{
		Name:  gatewayName,
		Image: TemplateFn(observatoriumAPI, m.Images),
		Args: []string{
			"--web.listen=0.0.0.0:8080",
			"--web.internal.listen=0.0.0.0:8081",
			fmt.Sprintf("--log.level=%s", logLevel),
			fmt.Sprintf("--metrics.read.endpoint=http://%s.%s.svc.cluster.local:9090", qfeService, namespace),
			fmt.Sprintf("--metrics.write.endpoint=http://%s.%s.svc.cluster.local:19291", routerService, namespace),
			fmt.Sprintf("--metrics.alertmanager.endpoint=http://%s.%s.svc.cluster.local:9093", alertManagerName, namespace),
			"--rbac.config=/etc/observatorium/rbac.yaml",
			"--tenants.config=/etc/observatorium/tenants.yaml",
			"--server.read-timeout=5m",
		},
		Ports: []corev1.ContainerPort{
			{Name: "grpc-public", ContainerPort: 8090},
			{Name: "internal", ContainerPort: 8081},
			{Name: "public", ContainerPort: 8080},
		},
		Resources: m.ResourceRequirements[observatoriumAPI],
		VolumeMounts: []corev1.VolumeMount{
			{
				Name:      "rbac",
				ReadOnly:  true,
				MountPath: "/etc/observatorium/rbac.yaml",
				SubPath:   "rbac.yaml",
			},
			{
				Name:      "tenants",
				ReadOnly:  true,
				MountPath: "/etc/observatorium/tenants.yaml",
				SubPath:   "tenants.yaml",
			},
		},
		LivenessProbe: &corev1.Probe{
			ProbeHandler: corev1.ProbeHandler{
				HTTPGet: &corev1.HTTPGetAction{
					Path:   "/live",
					Port:   intstr.FromInt32(8081),
					Scheme: corev1.URISchemeHTTP,
				},
			},
			FailureThreshold: 10,
			PeriodSeconds:    30,
		},
		ReadinessProbe: &corev1.Probe{
			ProbeHandler: corev1.ProbeHandler{
				HTTPGet: &corev1.HTTPGetAction{
					Path:   "/ready",
					Port:   intstr.FromInt32(8081),
					Scheme: corev1.URISchemeHTTP,
				},
			},
			FailureThreshold: 12,
			PeriodSeconds:    5,
		},
	}
}

func createOPAAMSContainer(m TemplateMaps, namespace, amsURL string) corev1.Container {
	return corev1.Container{
		Name:  componentOPAAMS,
		Image: TemplateFn(opaAMS, m.Images),
		Args: []string{
			"--web.listen=127.0.0.1:8082",
			"--web.internal.listen=0.0.0.0:8083",
			"--web.healthchecks.url=http://127.0.0.1:8082",
			"--log.level=warn",
			fmt.Sprintf("--ams.url=%s", amsURL),
			"--resource-type-prefix=observatorium",
			"--oidc.client-id=$(CLIENT_ID)",
			"--oidc.client-secret=$(CLIENT_SECRET)",
			"--oidc.issuer-url=$(ISSUER_URL)",
			"--opa.package=observatorium",
			fmt.Sprintf("--memcached=%s.%s.svc.cluster.local:11211", gatewayCacheName, namespace),
			"--memcached.expire=300",
			"--ams.mappings=osd=${OSD_ORGANIZATION_ID}",
			"--ams.mappings=osd=${SD_OPS_ORGANIZATION_ID}",
			"--ams.mappings=cnvqe={CNVQE_ORGANIZATION_ID}",
			"--internal.tracing.endpoint=localhost:6831",
		},
		Env: []corev1.EnvVar{
			{
				Name: "ISSUER_URL",
				ValueFrom: &corev1.EnvVarSource{
					SecretKeyRef: &corev1.SecretKeySelector{
						LocalObjectReference: corev1.LocalObjectReference{
							Name: gatewayName,
						},
						Key: "issuer-url",
					},
				},
			},
			{
				Name: "CLIENT_ID",
				ValueFrom: &corev1.EnvVarSource{
					SecretKeyRef: &corev1.SecretKeySelector{
						LocalObjectReference: corev1.LocalObjectReference{
							Name: gatewayName,
						},
						Key: "client-id",
					},
				},
			},
			{
				Name: "CLIENT_SECRET",
				ValueFrom: &corev1.EnvVarSource{
					SecretKeyRef: &corev1.SecretKeySelector{
						LocalObjectReference: corev1.LocalObjectReference{
							Name: gatewayName,
						},
						Key: "client-secret",
					},
				},
			},
		},
		Ports: []corev1.ContainerPort{
			{Name: "opa-ams-api", ContainerPort: 8082},
			{Name: "opa-ams-metrics", ContainerPort: 8083},
		},
		Resources: m.ResourceRequirements[apiCache],
		LivenessProbe: &corev1.Probe{
			ProbeHandler: corev1.ProbeHandler{
				HTTPGet: &corev1.HTTPGetAction{
					Path:   "/live",
					Port:   intstr.FromInt32(8083),
					Scheme: corev1.URISchemeHTTP,
				},
			},
			FailureThreshold: 10,
			PeriodSeconds:    30,
		},
		ReadinessProbe: &corev1.Probe{
			ProbeHandler: corev1.ProbeHandler{
				HTTPGet: &corev1.HTTPGetAction{
					Path:   "/ready",
					Port:   intstr.FromInt32(8083),
					Scheme: corev1.URISchemeHTTP,
				},
			},
			FailureThreshold: 12,
			PeriodSeconds:    5,
		},
	}
}

func createJaegerAgentContainer(m TemplateMaps) corev1.Container {
	return corev1.Container{
		Name:            componentJaegerAgent,
		Image:           TemplateFn(jaeger, m.Images),
		ImagePullPolicy: corev1.PullIfNotPresent,
		Args: []string{
			"--reporter.grpc.host-port=dns:///otel-trace-writer-collector-headless.observatorium-tools.svc:14250",
			"--reporter.type=grpc",
			"--agent.tags=pod.namespace=$(NAMESPACE),pod.name=$(POD)",
		},
		Env: []corev1.EnvVar{
			{
				Name: "NAMESPACE",
				ValueFrom: &corev1.EnvVarSource{
					FieldRef: &corev1.ObjectFieldSelector{
						APIVersion: "v1",
						FieldPath:  "metadata.namespace",
					},
				},
			},
			{
				Name: "POD",
				ValueFrom: &corev1.EnvVarSource{
					FieldRef: &corev1.ObjectFieldSelector{
						APIVersion: "v1",
						FieldPath:  "metadata.name",
					},
				},
			},
		},
		Ports: []corev1.ContainerPort{
			{Name: "configs", ContainerPort: 5778, Protocol: corev1.ProtocolTCP},
			{Name: "jaeger-thrift", ContainerPort: 6831, Protocol: corev1.ProtocolTCP},
			{Name: "metrics", ContainerPort: 14271, Protocol: corev1.ProtocolTCP},
		},
		Resources: m.ResourceRequirements[observatoriumAPI],
		LivenessProbe: &corev1.Probe{
			ProbeHandler: corev1.ProbeHandler{
				HTTPGet: &corev1.HTTPGetAction{
					Path:   "/",
					Port:   intstr.FromInt32(14271),
					Scheme: corev1.URISchemeHTTP,
				},
			},
			TimeoutSeconds:   1,
			PeriodSeconds:    10,
			SuccessThreshold: 1,
			FailureThreshold: 5,
		},
		ReadinessProbe: &corev1.Probe{
			ProbeHandler: corev1.ProbeHandler{
				HTTPGet: &corev1.HTTPGetAction{
					Path:   "/",
					Port:   intstr.FromInt32(14271),
					Scheme: corev1.URISchemeHTTP,
				},
			},
			InitialDelaySeconds: 1,
			TimeoutSeconds:      1,
			PeriodSeconds:       10,
			SuccessThreshold:    1,
			FailureThreshold:    3,
		},
		TerminationMessagePath:   "/dev/termination-log",
		TerminationMessagePolicy: corev1.TerminationMessageFallbackToLogsOnError,
	}
}

func createGatewayService(m TemplateMaps, namespace string) *corev1.Service {
	labels, selectorLabels := gatewayLabels(m)
	return &corev1.Service{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Service",
			APIVersion: "v1",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      gatewayName,
			Namespace: namespace,
			Labels:    labels,
		},
		Spec: corev1.ServiceSpec{
			Type:                  corev1.ServiceTypeClusterIP,
			SessionAffinity:       corev1.ServiceAffinityNone,
			InternalTrafficPolicy: &[]corev1.ServiceInternalTrafficPolicyType{corev1.ServiceInternalTrafficPolicyCluster}[0],
			IPFamilyPolicy:        &[]corev1.IPFamilyPolicyType{corev1.IPFamilyPolicySingleStack}[0],
			IPFamilies:            []corev1.IPFamily{corev1.IPv4Protocol},
			Ports: []corev1.ServicePort{
				{
					Name:        "grpc-public",
					Protocol:    corev1.ProtocolTCP,
					AppProtocol: stringPtr("h2c"),
					Port:        8090,
					TargetPort:  intstr.FromInt32(8090),
				},
				{
					Name:        "internal",
					Protocol:    corev1.ProtocolTCP,
					AppProtocol: stringPtr("http"),
					Port:        8081,
					TargetPort:  intstr.FromInt32(8081),
				},
				{
					Name:        "public",
					Protocol:    corev1.ProtocolTCP,
					AppProtocol: stringPtr("http"),
					Port:        8080,
					TargetPort:  intstr.FromInt32(8080),
				},
				{
					Name:       "opa-ams-api",
					Protocol:   corev1.ProtocolTCP,
					Port:       8082,
					TargetPort: intstr.FromInt32(8082),
				},
				{
					Name:       "opa-ams-metrics",
					Protocol:   corev1.ProtocolTCP,
					Port:       8083,
					TargetPort: intstr.FromInt32(8083),
				},
			},
			Selector: selectorLabels,
		},
	}
}

// Helper function to return a pointer to a string
func stringPtr(s string) *string {
	return &s
}

func gatewayRBAC(m TemplateMaps, namespace, contents string) *corev1.ConfigMap {
	labels, _ := gatewayLabels(m)
	return &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      gatewayName,
			Namespace: namespace,
			Labels:    labels,
		},
		TypeMeta: metav1.TypeMeta{
			Kind:       "ConfigMap",
			APIVersion: "v1",
		},
		Data: map[string]string{
			"rbac.yaml": contents,
		},
	}
}

func stageGatewayTenants(m TemplateMaps, namespace string) *corev1.Secret {
	labels, _ := gatewayLabels(m)
	return &corev1.Secret{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Secret",
			APIVersion: "v1",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      gatewayName,
			Namespace: namespace,
			Labels:    labels,
			Annotations: map[string]string{
				"qontract.recycle": "true",
			},
		},
		StringData: map[string]string{
			"client-id":     "${CLIENT_ID}",
			"client-secret": "${CLIENT_SECRET}",
			"issuer-url":    "https://sso.redhat.com/auth/realms/redhat-external",
			"tenants.yaml": `tenants:
      - id: 0fc2b00e-201b-4c17-b9f2-19d91adc4fd2
        name: rhobs
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium.api.stage.openshift.com/oidc/rhobs/callback
          usernameClaim: preferred_username
          groupClaim: email
      - id: 770c1124-6ae8-4324-a9d4-9ce08590094b
        name: osd
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.stage.openshift.com/oidc/osd/callback
          usernameClaim: preferred_username
        opa:
          url: http://127.0.0.1:8082/v1/data/observatorium/allow
        rateLimits:
        - endpoint: /api/metrics/v1/.+/api/v1/receive
          limit: 10000
          window: 30s
      - id: 1b9b6e43-9128-4bbf-bfff-3c120bbe6f11
        name: rhacs
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.stage.openshift.com/oidc/rhacs/callback
          usernameClaim: preferred_username
      - id: 9ca26972-4328-4fe3-92db-31302013d03f
        name: cnvqe
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.stage.openshift.com/oidc/cnvqe/callback
          usernameClaim: preferred_username
      - id: 37b8fd3f-56ff-4b64-8272-917c9b0d1623
        name: psiocp
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.stage.openshift.com/oidc/psiocp/callback
          usernameClaim: preferred_username
      - id: 8ace13a2-1c72-4559-b43d-ab43e32a255a
        name: rhods
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.stage.openshift.com/oidc/rhods/callback
          usernameClaim: preferred_username
      - id: 99c885bc-2d64-4c4d-b55e-8bf30d98c657
        name: odfms
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.stage.openshift.com/oidc/odfms/callback
          usernameClaim: preferred_username
      - id: d17ea8ce-d4c6-42ef-b259-7d10c9227e93
        name: reference-addon
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.stage.openshift.com/oidc/reference-addon/callback
          usernameClaim: preferred_username
      - id: AC879303-C60F-4D0D-A6D5-A485CFD638B8
        name: dptp
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.stage.openshift.com/oidc/dptp/callback
          usernameClaim: preferred_username
      - id: 3833951d-bede-4a53-85e5-f73f4913973f
        name: appsre
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.stage.openshift.com/oidc/appsre/callback
          usernameClaim: preferred_username
      - id: 0031e8d6-e50a-47ea-aecb-c7e0bd84b3f1
        name: rhtap
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.stage.openshift.com/oidc/rhtap/callback
          usernameClaim: preferred_username
      - id: 72e6f641-b2e2-47eb-bbc2-fee3c8fbda26
        name: rhel
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.stage.openshift.com/oidc/rhel/callback
          usernameClaim: preferred_username
        rateLimits:
        - endpoint: '/api/metrics/v1/rhel/api/v1/receive'
          limit: 10000
          window: 30s
      - id: FB870BF3-9F3A-44FF-9BF7-D7A047A52F43
        name: telemeter
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium.api.stage.openshift.com/oidc/telemeter/callback
          usernameClaim: preferred_username
`,
		},
	}
}

func prodGatewayTenants(m TemplateMaps, namespace string) *corev1.Secret {
	labels, _ := gatewayLabels(m)
	return &corev1.Secret{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Secret",
			APIVersion: "v1",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      gatewayName,
			Namespace: namespace,
			Labels:    labels,
			Annotations: map[string]string{
				"qontract.recycle": "true",
			},
		},
		StringData: map[string]string{
			"client-id":     "${CLIENT_ID}",
			"client-secret": "${CLIENT_SECRET}",
			"issuer-url":    "https://sso.redhat.com/auth/realms/redhat-external",
			"tenants.yaml": `tenants:
      - id: 0fc2b00e-201b-4c17-b9f2-19d91adc4fd2
        name: rhobs
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium.api.openshift.com/oidc/rhobs/callback
          usernameClaim: preferred_username
          groupClaim: email
      - id: 770c1124-6ae8-4324-a9d4-9ce08590094b
        name: osd
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.openshift.com/oidc/osd/callback
          usernameClaim: preferred_username
        opa:
          url: http://127.0.0.1:8082/v1/data/observatorium/allow
        rateLimits:
        - endpoint: /api/metrics/v1/.+/api/v1/receive
          limit: 10000
          window: 30s
      - id: 1b9b6e43-9128-4bbf-bfff-3c120bbe6f11
        name: rhacs
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.openshift.com/oidc/rhacs/callback
          usernameClaim: preferred_username
      - id: 9ca26972-4328-4fe3-92db-31302013d03f
        name: cnvqe
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.openshift.com/oidc/cnvqe/callback
          usernameClaim: preferred_username
      - id: 37b8fd3f-56ff-4b64-8272-917c9b0d1623
        name: psiocp
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.openshift.com/oidc/psiocp/callback
          usernameClaim: preferred_username
      - id: 8ace13a2-1c72-4559-b43d-ab43e32a255a
        name: rhods
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.openshift.com/oidc/rhods/callback
          usernameClaim: preferred_username
      - id: 99c885bc-2d64-4c4d-b55e-8bf30d98c657
        name: odfms
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.openshift.com/oidc/odfms/callback
          usernameClaim: preferred_username
      - id: d17ea8ce-d4c6-42ef-b259-7d10c9227e93
        name: reference-addon
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.openshift.com/oidc/reference-addon/callback
          usernameClaim: preferred_username
      - id: AC879303-C60F-4D0D-A6D5-A485CFD638B8
        name: dptp
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.openshift.com/oidc/dptp/callback
          usernameClaim: preferred_username
      - id: 3833951d-bede-4a53-85e5-f73f4913973f
        name: appsre
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.openshift.com/oidc/appsre/callback
          usernameClaim: preferred_username
      - id: 0031e8d6-e50a-47ea-aecb-c7e0bd84b3f1
        name: rhtap
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.openshift.com/oidc/rhtap/callback
          usernameClaim: preferred_username
      - id: 72e6f641-b2e2-47eb-bbc2-fee3c8fbda26
        name: rhel
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium-mst.api.openshift.com/oidc/rhel/callback
          usernameClaim: preferred_username
        rateLimits:
        - endpoint: '/api/metrics/v1/rhel/api/v1/receive'
          limit: 10000
          window: 30s
      - id: FB870BF3-9F3A-44FF-9BF7-D7A047A52F43
        name: telemeter
        oidc:
          clientID: ${CLIENT_ID}
          clientSecret: ${CLIENT_SECRET}
          issuerURL: https://sso.redhat.com/auth/realms/redhat-external
          redirectURL: https://observatorium.api.openshift.com/oidc/telemeter/callback
          usernameClaim: preferred_username
`,
		},
	}
}

var gatewayTemplateParams = []templatev1.Parameter{
	{
		Name:        "OSD_ORGANIZATION_ID",
		Description: "Organization ID for OSD",
	},
	{
		Name:        "SD_OPS_ORGANIZATION_ID",
		Description: "Organization ID for SD Ops",
	},
	{
		Name:        "CNVQE_ORGANIZATION_ID",
		Description: "Organization ID for CNVQE",
	},
	{
		Name:        "CLIENT_ID",
		Description: "Client ID for OIDC",
	},
	{
		Name:        "CLIENT_SECRET",
		Description: "Client secret for OIDC",
	},
}

func gatewayServiceMonitor(m TemplateMaps, matchNS string) *monitoringv1.ServiceMonitor {
	labels, selectorLabels := gatewayLabels(m)
	labels[openshiftCustomerMonitoringLabel] = openShiftClusterMonitoringLabelValue
	return &monitoringv1.ServiceMonitor{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "rhobs-gateway",
			Namespace: openshiftCustomerMonitoringNamespace,
			Labels:    labels,
		},
		TypeMeta: metav1.TypeMeta{
			Kind:       "ServiceMonitor",
			APIVersion: "monitoring.coreos.com/v1",
		},
		Spec: monitoringv1.ServiceMonitorSpec{
			Endpoints: []monitoringv1.Endpoint{
				{
					Port:     "internal",
					Path:     "/metrics",
					Interval: "30s",
				},
				{
					Port:     "opa-ams-metrics",
					Path:     "/metrics",
					Interval: "30s",
				},
				{
					Port:     "metrics",
					Path:     "/metrics",
					Interval: "30s",
				},
			},
			Selector: metav1.LabelSelector{
				MatchLabels: selectorLabels,
			},
			NamespaceSelector: monitoringv1.NamespaceSelector{
				MatchNames: []string{
					matchNS,
				},
			},
		},
	}
}
