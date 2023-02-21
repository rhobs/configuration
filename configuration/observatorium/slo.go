package cfgobservatorium

import (
	"fmt"
	"strings"

	"github.com/bwplotka/mimic"
	"github.com/bwplotka/mimic/encoding"
	monitoring "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring"
	monitoringv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	pyrrav1alpha1 "github.com/pyrra-dev/pyrra/kubernetes/api/v1alpha1"
	"github.com/pyrra-dev/pyrra/slo"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const (
	window             = "28d" // Window over which our SLOs are calculated.
	availabilityTarget = "99"  // Availability SLO target, currently at 99%.
	latencyTarget      = "90"  // Latency SLO percentile target.
	latencySeconds     = "5"   // Latency request duration to measure percentile target (this is diff for query SLOs).
)

var (
	pyrraTypeMeta = metav1.TypeMeta{
		Kind:       "ServiceLevelObjective",
		APIVersion: pyrrav1alpha1.GroupVersion.Version,
	}

	promRuleTypeMeta = metav1.TypeMeta{
		APIVersion: monitoring.GroupName + "/" + monitoringv1.Version,
		Kind:       monitoringv1.PrometheusRuleKind,
	}

	ruleFileLabels = map[string]string{
		"prometheus": "app-sre",
		"role":       "alert-rules",
	}

	dashboardIDs = map[string]string{
		"telemeter-production":   "f9fa7677fb4a2669f123f9a0f2234b47",
		"telemeter-staging":      "080e53f245a15445bdf777ae0e66945d",
		"mst-production":         "283e7002d85c08126681241df2fdb22b",
		"mst-stage":              "92520ea4d6976f30d1618164e186ef9b",
		"rhobsp02ue1-production": "7f4df1c2d5518d5c3f2876ca9bb874a8",
	}

	dashboardDataSource = map[string]string{
		"telemeter-production":   "telemeter-prod-01-prometheus",
		"telemeter-staging":      "app-sre-stage-01-prometheus",
		"mst-production":         "telemeter-prod-01-prometheus",
		"mst-stage":              "app-sre-stage-01-prometheus",
		"rhobsp02ue1-production": "rhobsp02ue1-prometheus",
	}

	// Unifying our namespaces would allow us to remove the metrics/up/apiJobSelector maps.
	apiJobSelector = map[string]string{
		"telemeter-production":   "observatorium-observatorium-api",
		"telemeter-staging":      "observatorium-observatorium-api",
		"mst-production":         "observatorium-observatorium-mst-api",
		"mst-stage":              "observatorium-observatorium-mst-api",
		"rhobsp02ue1-production": "observatorium-observatorium-mst-api",
	}

	metricsNS = map[string]string{
		"telemeter-production":   "observatorium-metrics-production",
		"telemeter-staging":      "observatorium-metrics-stage",
		"mst-production":         "observatorium-mst-production",
		"mst-stage":              "observatorium-mst-stage",
		"rhobsp02ue1-production": "observatorium-mst-production",
	}

	upNS = map[string]string{
		"telemeter-production":   "observatorium-production",
		"telemeter-staging":      "observatorium-stage",
		"mst-production":         "observatorium-mst-production",
		"mst-stage":              "observatorium-mst-stage",
		"rhobsp02ue1-production": "observatorium-mst-production",
	}
)

type sloType string

const (
	latency      sloType = "latency"
	availability sloType = "availability"
)

// rhobsSLOs is a shorthand struct to generate Pyrra SLOs.
type rhobsSLOs struct {
	name                string
	labels              map[string]string
	description         string
	successOrErrorsExpr string
	totalExpr           string
	alertName           string
	sloType             sloType
}

type rhobSLOList []rhobsSLOs

func (slos rhobSLOList) GetObjectives(envName string) []pyrrav1alpha1.ServiceLevelObjective {
	objectives := []pyrrav1alpha1.ServiceLevelObjective{}

	for _, s := range slos {
		objective := pyrrav1alpha1.ServiceLevelObjective{
			TypeMeta: pyrraTypeMeta,
			ObjectMeta: metav1.ObjectMeta{
				Name:   s.name,
				Labels: s.labels,
				Annotations: map[string]string{
					slo.PropagationLabelsPrefix + "message":   s.description,
					slo.PropagationLabelsPrefix + "dashboard": getGrafanaLink(envName),
					slo.PropagationLabelsPrefix + "runbook":   getRunbookLink(s.alertName),
				},
			},
			Spec: pyrrav1alpha1.ServiceLevelObjectiveSpec{
				Description: s.description,
				Window:      window,
				Alerting: pyrrav1alpha1.Alerting{
					Name: s.alertName,
				},
			},
		}

		if s.sloType == availability {
			objective.Spec.Target = availabilityTarget
			objective.Spec.ServiceLevelIndicator = pyrrav1alpha1.ServiceLevelIndicator{
				Ratio: &pyrrav1alpha1.RatioIndicator{
					Errors: pyrrav1alpha1.Query{
						Metric: s.successOrErrorsExpr,
					},
					Total: pyrrav1alpha1.Query{
						Metric: s.totalExpr,
					},
				},
			}
		} else {
			objective.Spec.Target = latencyTarget
			objective.Spec.ServiceLevelIndicator = pyrrav1alpha1.ServiceLevelIndicator{
				Latency: &pyrrav1alpha1.LatencyIndicator{
					Success: pyrrav1alpha1.Query{
						Metric: s.successOrErrorsExpr,
					},
					Total: pyrrav1alpha1.Query{
						Metric: s.totalExpr,
					},
				},
			}
		}

		objectives = append(objectives, objective)
	}

	return objectives
}

// getGrafanaLink returns the AppSRE production Grafana dashboard for a particular RHOBS environment.
func getGrafanaLink(envName string) string {
	return fmt.Sprintf(
		"https://grafana.app-sre.devshift.net/d/%s/%s-slos?orgId=1&refresh=10s&var-datasource=%s&var-namespace={{$labels.namespace}}&var-job=All&var-pod=All&var-interval=5m",
		dashboardIDs[envName],
		envName,
		dashboardDataSource[envName],
	)
}

// getRunbookLink returns the rhobs/config runbook link for a particular alert.
func getRunbookLink(alert string) string {
	return fmt.Sprintf(
		"https://github.com/rhobs/configuration/blob/main/docs/sop/observatorium.md#%s",
		alert,
	)
}

// TelemeterSLOs returns the openshift/telemeter specific SLOs we maintain.
func TelemeterSLOs(envName string) []pyrrav1alpha1.ServiceLevelObjective {
	slos := rhobSLOList{
		// Telemeter Availability SLOs.
		{
			name: "rhobs-telemeter-server-metrics-upload-availability-slo",
			labels: map[string]string{
				"route":   "telemeter-server-upload",
				"service": "telemeter",
			},
			description:         "Telemeter Server /upload is burning too much error budget to guarantee availability SLOs.",
			successOrErrorsExpr: "haproxy_server_http_responses_total{route=\"telemeter-server-upload\", code=~\"5..\"}",
			totalExpr:           "haproxy_server_http_responses_total{route=\"telemeter-server-upload\", code!~\"^4..$\"}",
			alertName:           "TelemeterServerMetricsUploadWriteAvailabilityErrorBudgetBurning",
			sloType:             availability,
		},
		{
			name: "rhobs-telemeter-server-metrics-receive-availability-slo",
			labels: map[string]string{
				"route":   "telemeter-server-receive",
				"service": "telemeter",
			},
			description:         "Telemeter Server /receive is burning too much error budget to guarantee availability SLOs.",
			successOrErrorsExpr: "haproxy_server_http_responses_total{route=\"telemeter-server-metrics-v1-receive\", code=~\"5..\"}",
			totalExpr:           "haproxy_server_http_responses_total{route=\"telemeter-server-metrics-v1-receive\", code!~\"^4..$\"}",
			alertName:           "TelemeterServerMetricsReceiveWriteAvailabilityErrorBudgetBurning",
			sloType:             availability,
		},

		// Telemeter Latency SLOs.
		{
			name: "rhobs-telemeter-server-metrics-upload-latency-slo",
			labels: map[string]string{
				"route":   "telemeter-server-upload",
				"service": "telemeter",
			},
			description:         "Telemeter Server /upload is burning too much error budget to guarantee latency SLOs.",
			successOrErrorsExpr: "http_request_duration_seconds_bucket{job=\"telemeter-server\", handler=\"upload\", code=~\"^2..$\", le=\"" + latencySeconds + "\"}",
			totalExpr:           "http_request_duration_seconds_count{job=\"telemeter-server\", handler=\"upload\", code=~\"^2..$\"}",
			alertName:           "TelemeterServerMetricsUploadWriteLatencyErrorBudgetBurning",
			sloType:             latency,
		},
		{
			name: "rhobs-telemeter-server-metrics-receive-latency-slo",
			labels: map[string]string{
				"route":   "telemeter-server-receive",
				"service": "telemeter",
			},
			description:         "Telemeter Server /receive is burning too much error budget to guarantee latency SLOs.",
			successOrErrorsExpr: "http_request_duration_seconds_bucket{job=\"telemeter-server\", handler=\"receive\", code=~\"^2..$\", le=\"" + latencySeconds + "\"}",
			totalExpr:           "http_request_duration_seconds_count{job=\"telemeter-server\", handler=\"receive\", code=~\"^2..$\"}",
			alertName:           "TelemeterServerMetricsReceiveWriteLatencyErrorBudgetBurning",
			sloType:             latency,
		},
	}

	return slos.GetObjectives(envName)
}

func ObservatoriumSLOs(envName string) []pyrrav1alpha1.ServiceLevelObjective {
	slos := rhobSLOList{
		// Observatorium Availability SLOs.
		{
			name: "api-metrics-write-availability-slo",
			labels: map[string]string{
				"service":  "observatorium-api",
				"instance": envName,
			},
			description:         "API /receive handler is burning too much error budget to guarantee availability SLOs.",
			successOrErrorsExpr: "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"receive\", code=~\"^5..$\"}",
			totalExpr:           "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"receive\", code!~\"^4..$\"}",
			alertName:           "APIMetricsWriteAvailabilityErrorBudgetBurning",
			sloType:             availability,
		},
		{
			name: "api-metrics-query-availability-slo",
			labels: map[string]string{
				"service":  "observatorium-api",
				"instance": envName,
			},
			description:         "API /query handler is burning too much error budget to guarantee availability SLOs.",
			successOrErrorsExpr: "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"query\", code=~\"^5..$\"}",
			totalExpr:           "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"query\", code!~\"^4..$\"}",
			alertName:           "APIMetricsQueryAvailabilityErrorBudgetBurning",
			sloType:             availability,
		},
		{
			name: "api-metrics-query-range-availability-slo",
			labels: map[string]string{
				"service":  "observatorium-api",
				"instance": envName,
			},
			description:         "API /query_range handler is burning too much error budget to guarantee availability SLOs.",
			successOrErrorsExpr: "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"query_range\", code=~\"^5..$\"}",
			totalExpr:           "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"query_range\", code!~\"^4..$\"}",
			alertName:           "APIMetricsQueryRangeAvailabilityErrorBudgetBurning",
			sloType:             availability,
		},
		{
			name: "api-rules-raw-write-availability-slo",
			labels: map[string]string{
				"service":  "observatorium-api",
				"instance": envName,
			},
			description:         "API /rules/raw endpoint for writes is burning too much error budget to guarantee availability SLOs.",
			successOrErrorsExpr: "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"rules-raw\", method=\"PUT\", code=~\"^5..$\"}",
			totalExpr:           "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"rules-raw\", method=\"PUT\", code!~\"^4..$\"}",
			alertName:           "APIRulesRawWriteAvailabilityErrorBudgetBurning",
			sloType:             availability,
		},
		{
			name: "api-rules-raw-read-availability-slo",
			labels: map[string]string{
				"service":  "observatorium-api",
				"instance": envName,
			},
			description:         "API /rules/raw endpoint for reads is burning too much error budget to guarantee availability SLOs.",
			successOrErrorsExpr: "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"rules-raw\", method=\"GET\", code=~\"^5..$\"}",
			totalExpr:           "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"rules-raw\", method=\"GET\", code!~\"^4..$\"}",
			alertName:           "APIRulesRawReadAvailabilityErrorBudgetBurning",
			sloType:             availability,
		},
		{
			name: "api-rules-read-availability-slo",
			labels: map[string]string{
				"service":  "observatorium-api",
				"instance": envName,
			},
			description:         "API /rules endpoint is burning too much error budget to guarantee availability SLOs.",
			successOrErrorsExpr: "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"rules\", method=\"GET\", code=~\"^5..$\"}",
			totalExpr:           "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"rules\", method=\"GET\", code!~\"^4..$\"}",
			alertName:           "APIRulesReadAvailabilityErrorBudgetBurning",
			sloType:             availability,
		},
		{
			name: "api-rules-sync-availability-slo",
			labels: map[string]string{
				"service":  "observatorium-api",
				"instance": envName,
			},
			description:         "Thanos Ruler /reload endpoint is burning too much error budget to guarantee availability SLOs.",
			successOrErrorsExpr: "client_api_requests_total{client=\"reload\", container=\"thanos-rule-syncer\", namespace=\"" + metricsNS[envName] + "\", code=~\"^5..$\"}",
			totalExpr:           "client_api_requests_total{client=\"reload\", container=\"thanos-rule-syncer\", namespace=\"" + metricsNS[envName] + "\", code!~\"^4..$\"}",
			alertName:           "APIRulesSyncAvailabilityErrorBudgetBurning",
			sloType:             availability,
		},
		{
			name: "api-alerting-availability-slo",
			labels: map[string]string{
				"service":  "observatorium-api",
				"instance": envName,
			},
			description:         "API Thanos Rule failing to send alerts to Alertmanager and is burning too much error budget to guarantee availability SLOs.",
			successOrErrorsExpr: "thanos_alert_sender_alerts_dropped_total{container=\"thanos-rule\", namespace=\"" + metricsNS[envName] + "\", code=~\"^5..$\"}",
			totalExpr:           "thanos_alert_sender_alerts_dropped_total{container=\"thanos-rule\", namespace=\"" + metricsNS[envName] + "\", code!~\"^4..$\"}",
			alertName:           "APIAlertmanagerAvailabilityErrorBudgetBurning",
			sloType:             availability,
		},
		{
			name: "api-alerting-notif-availability-slo",
			labels: map[string]string{
				"service":  "observatorium-api",
				"instance": envName,
			},
			description:         "API Alertmanager failing to deliver alerts to upstream targets and is burning too much error budget to guarantee availability SLOs.",
			successOrErrorsExpr: "alertmanager_notifications_failed_total{service=\"observatorium-alertmanager\", namespace=\"" + metricsNS[envName] + "\", code=~\"^5..$\"}",
			totalExpr:           "alertmanager_notifications_failed_total{service=\"observatorium-alertmanager\", namespace=\"" + metricsNS[envName] + "\", code!~\"^4..$\"}",
			alertName:           "APIAlertmanagerNotificationsAvailabilityErrorBudgetBurning",
			sloType:             availability,
		},

		// Observatorium Latency SLOs.
		{
			name: "api-metrics-write-latency-slo",
			labels: map[string]string{
				"service":  "observatorium-api",
				"instance": envName,
			},
			description:         "API /receive handler is burning too much error budget to guarantee latency SLOs.",
			successOrErrorsExpr: "http_request_duration_seconds_bucket{job=\"" + apiJobSelector[envName] + "\", handler=\"receive\", code=~\"^2..$\", le=\"" + latencySeconds + "\"}",
			totalExpr:           "http_request_duration_seconds_count{job=\"" + apiJobSelector[envName] + "\", handler=\"receive\", code=~\"^2..$\"}",
			alertName:           "APIMetricsWriteLatencyErrorBudgetBurning",
			sloType:             latency,
		},
		{
			name: "api-metrics-read-1M-latency-slo",
			labels: map[string]string{
				"service":  "observatorium-api",
				"instance": envName,
			},
			description:         "API /query endpoint is burning too much error budget for 1M samples, to guarantee latency SLOs.",
			successOrErrorsExpr: "up_custom_query_duration_seconds_bucket{query=\"query-path-sli-1M-samples\", namespace=\"" + upNS[envName] + "\", code=~\"^2..$\", le=\"10\"}",
			totalExpr:           "up_custom_query_duration_seconds_count{query=\"query-path-sli-1M-samples\", namespace=\"" + upNS[envName] + "\", code=~\"^2..$\"}",
			alertName:           "APIMetricsReadLatency1MErrorBudgetBurning",
			sloType:             latency,
		},
		{
			name: "api-metrics-read-10M-latency-slo",
			labels: map[string]string{
				"service":  "observatorium-api",
				"instance": envName,
			},
			description:         "API /query endpoint is burning too much error budget for 100M samples, to guarantee latency SLOs.",
			successOrErrorsExpr: "up_custom_query_duration_seconds_bucket{query=\"query-path-sli-10M-samples\", namespace=\"" + upNS[envName] + "\", code=~\"^2..$\", le=\"30\"}",
			totalExpr:           "up_custom_query_duration_seconds_count{query=\"query-path-sli-10M-samples\", namespace=\"" + upNS[envName] + "\", code=~\"^2..$\"}",
			alertName:           "APIMetricsReadLatency10MErrorBudgetBurning",
			sloType:             latency,
		},
		{
			name: "api-metrics-read-100M-latency-slo",
			labels: map[string]string{
				"service":  "observatorium-api",
				"instance": envName,
			},
			description:         "API /query endpoint is burning too much error budget for 100M samples, to guarantee latency SLOs.",
			successOrErrorsExpr: "up_custom_query_duration_seconds_bucket{query=\"query-path-sli-1M-samples\", namespace=\"" + upNS[envName] + "\", code=~\"^2..$\", le=\"120\"}",
			totalExpr:           "up_custom_query_duration_seconds_count{query=\"query-path-sli-1M-samples\", namespace=\"" + upNS[envName] + "\", code=~\"^2..$\"}",
			alertName:           "APIMetricsReadLatency100MErrorBudgetBurning",
			sloType:             latency,
		},
	}

	return slos.GetObjectives(envName)
}

// GenSLO is the function responsible for tying together Pyrra Objectives and converting them into SLO+Rule files.
func GenSLO(genPyrra, genRules *mimic.Generator) {
	// Add on extra Telemeter-only SLOs.
	telemeterObjectives := TelemeterSLOs("telemeter-production")
	telemeterStageObjectives := TelemeterSLOs("telemeter-staging")
	obsSLOTelemeter := ObservatoriumSLOs("telemeter-production")
	obsSLOTelemeterStage := ObservatoriumSLOs("telemeter-staging")

	telemeterProd := []pyrrav1alpha1.ServiceLevelObjective{}
	telemeterProd = append(telemeterProd, telemeterObjectives...)
	telemeterProd = append(telemeterProd, obsSLOTelemeter...)

	telemeterStage := []pyrrav1alpha1.ServiceLevelObjective{}
	telemeterStage = append(telemeterStage, telemeterStageObjectives...)
	telemeterStage = append(telemeterStage, obsSLOTelemeterStage...)

	envSLOs(
		"telemeter-production",
		telemeterProd,
		"rhobs-slos-telemeter-production.prometheusrules.yaml",
		false,
		genPyrra,
		genRules,
	)

	envSLOs(
		"telemeter-staging",
		telemeterStage,
		"rhobs-slos-telemeter-stage.prometheusrules.yaml",
		true,
		genPyrra,
		genRules,
	)

	envSLOs(
		"mst-production",
		ObservatoriumSLOs("mst-production"),
		"rhobs-slos-mst-production.prometheusrules.yaml",
		false,
		genPyrra,
		genRules,
	)

	envSLOs(
		"mst-stage",
		ObservatoriumSLOs("mst-stage"),
		"rhobs-slos-mst-stage.prometheusrules.yaml",
		true,
		genPyrra,
		genRules,
	)

	envSLOs(
		"rhobsp02ue1-production",
		ObservatoriumSLOs("rhobsp02ue1-production"),
		"rhobs-slos-rhobsp02ue1-prod.prometheusrules.yaml",
		false,
		genPyrra,
		genRules,
	)
}

func envSLOs(envName string, objs []pyrrav1alpha1.ServiceLevelObjective, ruleFilename string, isStage bool, genPyrra, genRules *mimic.Generator) {
	// We can generate objective files if we wish to.

	// for _, obj := range objs {
	// 	name := envName + "-" + obj.ObjectMeta.Name + ".yaml"
	// 	genPyrra.Add(name, encoding.GhodssYAML(obj))
	// }

	genRules.Add(ruleFilename, encoding.GhodssYAML("", makePrometheusRule(objs, strings.TrimSuffix(ruleFilename, ".prometheusrules.yaml"), isStage)))
}

// appSREPrometheusRule allows adding schema field to the generated YAML.
type appSREPrometheusRule struct {
	Schema string `json:"$schema"`
	monitoringv1.PrometheusRule
}

// Adapted from https://github.com/pyrra-dev/pyrra/blob/v0.5.3/kubernetes/controllers/servicelevelobjective.go#L207
// Helps us group and generate SLO rules into monitoringv1.PrometheusRule objects.
// Ideally, this can be done via pyrra generate command somehow. Pending PR: https://github.com/pyrra-dev/pyrra/pull/620
func makePrometheusRule(objs []pyrrav1alpha1.ServiceLevelObjective, name string, isStage bool) appSREPrometheusRule {
	grp := []monitoringv1.RuleGroup{}
	for _, obj := range objs {
		objective, err := obj.Internal()
		if err != nil {
			panic(err)
		}

		increases, err := objective.IncreaseRules()
		if err != nil {
			panic(err)
		}
		grp = append(grp, increases)

		burnrates, err := objective.Burnrates()
		if err != nil {
			panic(err)
		}
		grp = append(grp, burnrates)

		generic, err := objective.GenericRules()
		if err != nil {
			panic(err)
		}
		grp = append(grp, generic)
	}

	// We do not want to page on staging environments, i.e, no "critical" alerts.
	// There isn't a way to control the alert severity in Pyrra config yet, but ideally should be.
	// Pending PR: https://github.com/pyrra-dev/pyrra/pull/617
	if isStage {
		for i := range grp {
			for j := range grp[i].Rules {
				if v, ok := grp[i].Rules[j].Labels["severity"]; ok {
					if v == "critical" {
						grp[i].Rules[j].Labels["severity"] = "high"
					}
				}
			}
		}
	}

	return appSREPrometheusRule{
		Schema: "/openshift/prometheus-rule-1.yml",
		PrometheusRule: monitoringv1.PrometheusRule{
			TypeMeta: promRuleTypeMeta,
			ObjectMeta: metav1.ObjectMeta{
				Name:   name,
				Labels: ruleFileLabels,
			},
			Spec: monitoringv1.PrometheusRuleSpec{
				Groups: grp,
			},
		},
	}
}
