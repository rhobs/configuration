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
	globalSLOWindowDuration                   = "28d" // Window over which all RHOBS SLOs are calculated.
	globalMetricsSLOAvailabilityTargetPercent = "99"  // The Availability Target percentage for RHOBS metrics availability SLOs.
	globalSLOLatencyTargetPercent             = "90"  // The Latency Target percentage for RHOBS latency SLOs.
	genericSLOLatencySeconds                  = "5"   // Latency request duration to measure percentile target (this is diff for query SLOs).
)

// rhobsInstanceEnv represents a particular RHOBS Instance environment.
type rhobsInstanceEnv string

const (
	telemeterProduction   rhobsInstanceEnv = "telemeter-production"   // Telemeter production Observatorium instance on telemeter-prod-01 cluster.
	telemeterStaging      rhobsInstanceEnv = "telemeter-staging"      // Telemeter staging Observatorium instance on app-sre-stage-01 cluster.
	rhelemeterProduction  rhobsInstanceEnv = "rhelemeter-production"  // Rhelemeter production instance on telemeter-prod-01 cluster.
	rhelemeterStaging     rhobsInstanceEnv = "rhelemeter-stage"       // Rhelemeter staging instance on app-sre-stage-01 cluster.
	mstProduction         rhobsInstanceEnv = "mst-production"         // MST production Observatorium instance on telemeter-prod-01 cluster.
	mstStage              rhobsInstanceEnv = "mst-stage"              // MST staging Observatorium instance on app-sre-stage-01 cluster.
	rhobsp02ue1Production rhobsInstanceEnv = "rhobsp02ue1-production" // MST production Observatorium instance on rhobsp02ue1 cluster.
)

var (
	// Reusable k8s type metas.

	pyrraTypeMeta = metav1.TypeMeta{
		Kind:       "ServiceLevelObjective",
		APIVersion: pyrrav1alpha1.GroupVersion.Version,
	}

	promRuleTypeMeta = metav1.TypeMeta{
		APIVersion: monitoring.GroupName + "/" + monitoringv1.Version,
		Kind:       monitoringv1.PrometheusRuleKind,
	}

	// Needed appSRE labels for prom-operator PromethuesRule file.
	ruleFileLabels = map[string]string{
		"prometheus": "app-sre",
		"role":       "alert-rules",
	}

	// Grafana IDs <> env.
	dashboardIDs = map[rhobsInstanceEnv]string{
		telemeterProduction:   "f9fa7677fb4a2669f123f9a0f2234b47",
		telemeterStaging:      "080e53f245a15445bdf777ae0e66945d",
		mstProduction:         "283e7002d85c08126681241df2fdb22b",
		mstStage:              "92520ea4d6976f30d1618164e186ef9b",
		rhobsp02ue1Production: "7f4df1c2d5518d5c3f2876ca9bb874a8",
	}

	// Grafana Data Source <> env.
	dashboardDataSource = map[rhobsInstanceEnv]string{
		telemeterProduction:   "telemeter-prod-01-prometheus",
		telemeterStaging:      "app-sre-stage-01-prometheus",
		mstProduction:         "telemeter-prod-01-prometheus",
		mstStage:              "app-sre-stage-01-prometheus",
		rhobsp02ue1Production: "rhobsp02ue1-prometheus",
	}

	// Prometheus job label value for the Observatorium API.
	apiJobSelector = map[rhobsInstanceEnv]string{
		telemeterProduction:   "observatorium-observatorium-api",
		telemeterStaging:      "observatorium-observatorium-api",
		mstProduction:         "observatorium-observatorium-mst-api",
		mstStage:              "observatorium-observatorium-mst-api",
		rhobsp02ue1Production: "observatorium-observatorium-mst-api",
	}

	// Namespace for the metrics (Thanos) components of Observatorium instance.
	// Usually the same namespace as Observatorium API, but can be different in some
	// cases like Telemeter due to historical reasons.
	//
	// This can be deprecated once we unify our environments.
	metricsNS = map[rhobsInstanceEnv]string{
		telemeterProduction:   "observatorium-metrics-production",
		telemeterStaging:      "observatorium-metrics-stage",
		mstProduction:         "observatorium-mst-production",
		mstStage:              "observatorium-mst-stage",
		rhobsp02ue1Production: "observatorium-mst-production",
	}

	// Namespace for the observatorium/up job in Observatorium instance, that allows
	// generating synthetic data for Query SLOs. Usually the same namespace as other
	// components, but can be different in some cases like Telemeter due to historical
	// reasons.
	//
	// This can be deprecated once we unify our environments.
	upNS = map[rhobsInstanceEnv]string{
		telemeterProduction:   "observatorium-production",
		telemeterStaging:      "observatorium-stage",
		mstProduction:         "observatorium-mst-production",
		mstStage:              "observatorium-mst-stage",
		rhobsp02ue1Production: "observatorium-mst-production",
	}
)

// sloType indicates the type of a particular SLO in rhobsSLOs shorthand.
type sloType string

const (
	// Pyrra Latency SLO, calculated as percentile ratio of successful requests
	// in a latency bucket by total successful requests. For example, p90 of
	// # of http requests with 2xx response code, under 5s / # of http requests with 2xx.
	sloTypeLatency sloType = "latency"

	// Pyrra Availablity SLO, calculated as the inverse percentage ratio of errors by total
	// requests. For example, (1 - # of http requests with 5xx response code / # of http requests) * 100.
	sloTypeAvailability sloType = "availability"
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

// rhobSLOList is a list of shorthand SLOs.
type rhobSLOList []rhobsSLOs

// GetObjectives returns Pyrra Objectives from a rhobsSLOList shorthand.
func (slos rhobSLOList) GetObjectives(envName rhobsInstanceEnv) []pyrrav1alpha1.ServiceLevelObjective {
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
				Window:      globalSLOWindowDuration,
				Alerting: pyrrav1alpha1.Alerting{
					Name: s.alertName,
				},
			},
		}

		if s.sloType == sloTypeAvailability {
			// Metrics availability target as the default.
			objective.Spec.Target = globalMetricsSLOAvailabilityTargetPercent
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
			objective.Spec.Target = globalSLOLatencyTargetPercent
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
func getGrafanaLink(envName rhobsInstanceEnv) string {
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
//
// This set of SLOs are driven by the RHOBS Service Level Objectives document
// https://docs.google.com/document/d/1wJjcpgg-r8rlnOtRiqWGv0zwr1MB6WwkQED1XDWXVQs/edit
func TelemeterSLOs(envName rhobsInstanceEnv) []pyrrav1alpha1.ServiceLevelObjective {
	return append(TelemeterUploadSLOs(envName), TelemeterReceiveSLOs(envName, "Telemeter")...)
}

// RhelemeterSLOs returns the openshift/telemeter specific SLOs we maintain for the Rhelemeter instance.
func RhelemeterSLOs(envName rhobsInstanceEnv) []pyrrav1alpha1.ServiceLevelObjective {
	return TelemeterReceiveSLOs(envName, "Rhelemeter")
}

// TelemeterReceiveSLOs returns the openshift/telemeter specific SLOs we maintain for the remote write path. This path
// runs on diferent instances, so we need to be able to customize the instance name.
func TelemeterReceiveSLOs(envName rhobsInstanceEnv, instanceName string) []pyrrav1alpha1.ServiceLevelObjective {
	slos := rhobSLOList{
		{
			name: fmt.Sprintf("rhobs-%s-server-metrics-receive-availability-slo", strings.ToLower(instanceName)),
			labels: map[string]string{
				"route": fmt.Sprintf("%s-server-receive", strings.ToLower(instanceName)),
				// This has to match a service known by app-interface, so we can't use the instance name because Rhelemeter
				// is part of the Telemeter service definition for now.
				slo.PropagationLabelsPrefix + "service": "telemeter",
			},
			description:         fmt.Sprintf("%s Server /receive is burning too much error budget to guarantee availability SLOs.", instanceName),
			successOrErrorsExpr: fmt.Sprintf("haproxy_server_http_responses_total{route=\"%s-server-metrics-v1-receive\", code=~\"5..\"}", strings.ToLower(instanceName)),
			totalExpr:           fmt.Sprintf("haproxy_server_http_responses_total{route=\"%s-server-metrics-v1-receive\"}", strings.ToLower(instanceName)),
			alertName:           fmt.Sprintf("%sServerMetricsReceiveWriteAvailabilityErrorBudgetBurning", instanceName),
			sloType:             sloTypeAvailability,
		},
		{
			name: fmt.Sprintf("rhobs-%s-server-metrics-receive-latency-slo", strings.ToLower(instanceName)),
			labels: map[string]string{
				"route":                                 fmt.Sprintf("%s-server-receive", strings.ToLower(instanceName)),
				slo.PropagationLabelsPrefix + "service": "telemeter",
			},
			description:         fmt.Sprintf("%s Server /receive is burning too much error budget to guarantee latency SLOs.", instanceName),
			successOrErrorsExpr: fmt.Sprintf("http_request_duration_seconds_bucket{job=\"%s-server\", handler=\"receive\", code=~\"^2..$\", le=\""+genericSLOLatencySeconds+"\"}", strings.ToLower(instanceName)),
			totalExpr:           fmt.Sprintf("http_request_duration_seconds_count{job=\"%s-server\", handler=\"receive\", code=~\"^2..$\"}", strings.ToLower(instanceName)),
			alertName:           fmt.Sprintf("%sServerMetricsReceiveWriteLatencyErrorBudgetBurning", instanceName),
			sloType:             sloTypeLatency,
		},
	}

	return slos.GetObjectives(envName)
}

// TelemeterReceiveSLOs returns the openshift/telemeter specific SLOs we maintain for the upload path. These are only
// available for the Telemeter instance, so there's no customization on instance name.
func TelemeterUploadSLOs(envName rhobsInstanceEnv) []pyrrav1alpha1.ServiceLevelObjective {
	slos := rhobSLOList{
		{
			name: "rhobs-telemeter-server-metrics-upload-availability-slo",
			labels: map[string]string{
				"route":                                 "telemeter-server-upload",
				slo.PropagationLabelsPrefix + "service": "telemeter",
			},
			description:         "Telemeter Server /upload is burning too much error budget to guarantee availability SLOs.",
			successOrErrorsExpr: "haproxy_server_http_responses_total{route=\"telemeter-server-upload\", code=~\"5..\"}",
			totalExpr:           "haproxy_server_http_responses_total{route=\"telemeter-server-upload\"}",
			alertName:           "TelemeterServerMetricsUploadWriteAvailabilityErrorBudgetBurning",
			sloType:             sloTypeAvailability,
		},
		{
			name: "rhobs-telemeter-server-metrics-upload-latency-slo",
			labels: map[string]string{
				"route":                                 "telemeter-server-upload",
				slo.PropagationLabelsPrefix + "service": "telemeter",
			},
			description:         "Telemeter Server /upload is burning too much error budget to guarantee latency SLOs.",
			successOrErrorsExpr: "http_request_duration_seconds_bucket{job=\"telemeter-server\", handler=\"upload\", code=~\"^2..$\", le=\"" + genericSLOLatencySeconds + "\"}",
			totalExpr:           "http_request_duration_seconds_count{job=\"telemeter-server\", handler=\"upload\", code=~\"^2..$\"}",
			alertName:           "TelemeterServerMetricsUploadWriteLatencyErrorBudgetBurning",
			sloType:             sloTypeLatency,
		},
	}

	return slos.GetObjectives(envName)
}

// ObservatoriumSLOs returns the observatorium/observatorium specific SLOs we maintain.
//
// This set of SLOs are driven by the RHOBS Service Level Objectives document
// https://docs.google.com/document/d/1wJjcpgg-r8rlnOtRiqWGv0zwr1MB6WwkQED1XDWXVQs/edit
func ObservatoriumSLOs(envName rhobsInstanceEnv, signal signal) []pyrrav1alpha1.ServiceLevelObjective {
	var slos rhobSLOList
	switch signal {
	case metricsSignal:
		slos = rhobSLOList{
			// Observatorium Metrics Availability SLOs.
			{
				name: "api-metrics-write-availability-slo",
				labels: map[string]string{
					slo.PropagationLabelsPrefix + "service": "observatorium-api",
					"instance":                              string(envName),
				},
				description:         "API /receive handler is burning too much error budget to guarantee availability SLOs.",
				successOrErrorsExpr: "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"receive\", group=\"metricsv1\", code=~\"^5..$\"}",
				totalExpr:           "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"receive\", group=\"metricsv1\"}",
				alertName:           "APIMetricsWriteAvailabilityErrorBudgetBurning",
				sloType:             sloTypeAvailability,
			},
			// Queriers are deployed as separate instances for adhoc and rule queries.
			// The read availability SLO is split to reflect this deployment topology.
			{
				name: "api-metrics-rule-query-availability-slo",
				labels: map[string]string{
					slo.PropagationLabelsPrefix + "service": "observatorium-api",
					"instance":                              string(envName),
				},
				description:         "API /query handler endpoint for rules evaluation is burning too much error budget to guarantee availability SLOs.",
				successOrErrorsExpr: "http_requests_total{job=\"observatorium-ruler-query\", handler=\"query\", code=~\"^5..$\"}",
				totalExpr:           "http_requests_total{job=\"observatorium-ruler-query\", handler=\"query\"}",
				alertName:           "APIMetricsRulerQueryAvailabilityErrorBudgetBurning",
				sloType:             sloTypeAvailability,
			},
			{
				name: "api-metrics-query-availability-slo",
				labels: map[string]string{
					slo.PropagationLabelsPrefix + "service": "observatorium-api",
					"instance":                              string(envName),
				},
				description:         "API /query handler is burning too much error budget to guarantee availability SLOs.",
				successOrErrorsExpr: "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"query\", group=\"metricsv1\", code=~\"^5..$\"}",
				totalExpr:           "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"query\", group=\"metricsv1\"}",
				alertName:           "APIMetricsQueryAvailabilityErrorBudgetBurning",
				sloType:             sloTypeAvailability,
			},
			{
				name: "api-metrics-query-range-availability-slo",
				labels: map[string]string{
					slo.PropagationLabelsPrefix + "service": "observatorium-api",
					"instance":                              string(envName),
				},
				description:         "API /query_range handler is burning too much error budget to guarantee availability SLOs.",
				successOrErrorsExpr: "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"query_range\", group=\"metricsv1\", code=~\"^5..$\"}",
				totalExpr:           "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"query_range\", group=\"metricsv1\"}",
				alertName:           "APIMetricsQueryRangeAvailabilityErrorBudgetBurning",
				sloType:             sloTypeAvailability,
			},
			{
				name: "api-rules-raw-write-availability-slo",
				labels: map[string]string{
					slo.PropagationLabelsPrefix + "service": "observatorium-api",
					"instance":                              string(envName),
				},
				description:         "API /rules/raw endpoint for writes is burning too much error budget to guarantee availability SLOs.",
				successOrErrorsExpr: "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"rules-raw\", method=\"PUT\", group=\"metricsv1\", code=~\"^5..$\"}",
				totalExpr:           "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"rules-raw\", method=\"PUT\", group=\"metricsv1\"}",
				alertName:           "APIRulesRawWriteAvailabilityErrorBudgetBurning",
				sloType:             sloTypeAvailability,
			},
			{
				name: "api-rules-read-availability-slo",
				labels: map[string]string{
					slo.PropagationLabelsPrefix + "service": "observatorium-api",
					"instance":                              string(envName),
				},
				description:         "API /rules endpoint is burning too much error budget to guarantee availability SLOs.",
				successOrErrorsExpr: "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"rules\", method=\"GET\", group=\"metricsv1\", code=~\"^5..$\"}",
				totalExpr:           "http_requests_total{job=\"" + apiJobSelector[envName] + "\", handler=\"rules\", method=\"GET\", group=\"metricsv1\"}",
				alertName:           "APIRulesReadAvailabilityErrorBudgetBurning",
				sloType:             sloTypeAvailability,
			},
			{
				name: "api-rules-sync-availability-slo",
				labels: map[string]string{
					slo.PropagationLabelsPrefix + "service": "observatorium-api",
					"instance":                              string(envName),
				},
				description:         "Thanos Ruler /reload endpoint is burning too much error budget to guarantee availability SLOs.",
				successOrErrorsExpr: "client_api_requests_total{client=\"reload\", container=\"thanos-rule-syncer\", namespace=\"" + metricsNS[envName] + "\", code=~\"^5..$\"}",
				totalExpr:           "client_api_requests_total{client=\"reload\", container=\"thanos-rule-syncer\", namespace=\"" + metricsNS[envName] + "\"}",
				alertName:           "APIRulesSyncAvailabilityErrorBudgetBurning",
				sloType:             sloTypeAvailability,
			},
			{
				name: "api-alerting-availability-slo",
				labels: map[string]string{
					slo.PropagationLabelsPrefix + "service": "observatorium-api",
					"instance":                              string(envName),
				},
				description:         "API Thanos Rule failing to send alerts to Alertmanager and is burning too much error budget to guarantee availability SLOs.",
				successOrErrorsExpr: "thanos_alert_sender_alerts_dropped_total{container=\"thanos-rule\", namespace=\"" + metricsNS[envName] + "\", code=~\"^5..$\"}",
				totalExpr:           "thanos_alert_sender_alerts_dropped_total{container=\"thanos-rule\", namespace=\"" + metricsNS[envName] + "\"}",
				alertName:           "APIAlertmanagerAvailabilityErrorBudgetBurning",
				sloType:             sloTypeAvailability,
			},
			{
				name: "api-alerting-notif-availability-slo",
				labels: map[string]string{
					"service":  "observatorium-api",
					"instance": string(envName),
				},
				description:         "API Alertmanager failing to deliver alerts to upstream targets and is burning too much error budget to guarantee availability SLOs.",
				successOrErrorsExpr: "alertmanager_notifications_failed_total{service=\"observatorium-alertmanager\", namespace=\"" + metricsNS[envName] + "\", code=~\"^5..$\"}",
				totalExpr:           "alertmanager_notifications_failed_total{service=\"observatorium-alertmanager\", namespace=\"" + metricsNS[envName] + "\"}",
				alertName:           "APIAlertmanagerNotificationsAvailabilityErrorBudgetBurning",
				sloType:             sloTypeAvailability,
			},

			// Observatorium Metrics Latency SLOs.
			{
				name: "api-metrics-write-latency-slo",
				labels: map[string]string{
					slo.PropagationLabelsPrefix + "service": "observatorium-api",
					"instance":                              string(envName),
				},
				description:         "API /receive handler is burning too much error budget to guarantee latency SLOs.",
				successOrErrorsExpr: "http_request_duration_seconds_bucket{job=\"" + apiJobSelector[envName] + "\", handler=\"receive\", group=\"metricsv1\", code=~\"^2..$\", le=\"" + genericSLOLatencySeconds + "\"}",
				totalExpr:           "http_request_duration_seconds_count{job=\"" + apiJobSelector[envName] + "\", handler=\"receive\", group=\"metricsv1\", code=~\"^2..$\"}",
				alertName:           "APIMetricsWriteLatencyErrorBudgetBurning",
				sloType:             sloTypeLatency,
			},
			// Queriers are deployed as separate instances for adhoc and rule queries.
			// The read latencies SLO are split to reflect this deployment topology.
			{
				name: "api-metrics-rule-read-1M-latency-slo",
				labels: map[string]string{
					slo.PropagationLabelsPrefix + "service": "observatorium-api",
					"instance":                              string(envName),
				},
				description:         "API /query endpoint for rules evaluation is burning too much error budget for 1M samples, to guarantee latency SLOs.",
				successOrErrorsExpr: "up_custom_query_duration_seconds_bucket{query=\"rule-query-path-sli-1M-samples\", namespace=\"" + upNS[envName] + "\", http_code=~\"^2..$\", le=\"10\"}",
				totalExpr:           "up_custom_query_duration_seconds_count{query=\"rule-query-path-sli-1M-samples\", namespace=\"" + upNS[envName] + "\", http_code=~\"^2..$\"}",
				alertName:           "APIMetricsRuleReadLatency1MErrorBudgetBurning",
				sloType:             sloTypeLatency,
			},
			{
				name: "api-metrics-rule-read-10M-latency-slo",
				labels: map[string]string{
					slo.PropagationLabelsPrefix + "service": "observatorium-api",
					"instance":                              string(envName),
				},
				description:         "API /query endpoint for rules evaluation is burning too much error budget for 100M samples, to guarantee latency SLOs.",
				successOrErrorsExpr: "up_custom_query_duration_seconds_bucket{query=\"rule-query-path-sli-10M-samples\", namespace=\"" + upNS[envName] + "\", http_code=~\"^2..$\", le=\"30\"}",
				totalExpr:           "up_custom_query_duration_seconds_count{query=\"rule-query-path-sli-10M-samples\", namespace=\"" + upNS[envName] + "\", http_code=~\"^2..$\"}",
				alertName:           "APIMetricsRuleReadLatency10MErrorBudgetBurning",
				sloType:             sloTypeLatency,
			},
			{
				name: "api-metrics-rule-read-100M-latency-slo",
				labels: map[string]string{
					slo.PropagationLabelsPrefix + "service": "observatorium-api",
					"instance":                              string(envName),
				},
				description:         "API /query endpoint for rules evaluation is burning too much error budget for 100M samples, to guarantee latency SLOs.",
				successOrErrorsExpr: "up_custom_query_duration_seconds_bucket{query=\"rule-query-path-sli-1M-samples\", namespace=\"" + upNS[envName] + "\", http_code=~\"^2..$\", le=\"120\"}",
				totalExpr:           "up_custom_query_duration_seconds_count{query=\"rule-query-path-sli-1M-samples\", namespace=\"" + upNS[envName] + "\", http_code=~\"^2..$\"}",
				alertName:           "APIMetricsRulenReadLatency100MErrorBudgetBurning",
				sloType:             sloTypeLatency,
			},
			{
				name: "api-metrics-read-1M-latency-slo",
				labels: map[string]string{
					slo.PropagationLabelsPrefix + "service": "observatorium-api",
					"instance":                              string(envName),
				},
				description:         "API /query endpoint is burning too much error budget for 1M samples, to guarantee latency SLOs.",
				successOrErrorsExpr: "up_custom_query_duration_seconds_bucket{query=\"query-path-sli-1M-samples\", namespace=\"" + upNS[envName] + "\", http_code=~\"^2..$\", le=\"10\"}",
				totalExpr:           "up_custom_query_duration_seconds_count{query=\"query-path-sli-1M-samples\", namespace=\"" + upNS[envName] + "\", http_code=~\"^2..$\"}",
				alertName:           "APIMetricsReadLatency1MErrorBudgetBurning",
				sloType:             sloTypeLatency,
			},
			{
				name: "api-metrics-read-10M-latency-slo",
				labels: map[string]string{
					slo.PropagationLabelsPrefix + "service": "observatorium-api",
					"instance":                              string(envName),
				},
				description:         "API /query endpoint is burning too much error budget for 100M samples, to guarantee latency SLOs.",
				successOrErrorsExpr: "up_custom_query_duration_seconds_bucket{query=\"query-path-sli-10M-samples\", namespace=\"" + upNS[envName] + "\", http_code=~\"^2..$\", le=\"30\"}",
				totalExpr:           "up_custom_query_duration_seconds_count{query=\"query-path-sli-10M-samples\", namespace=\"" + upNS[envName] + "\", http_code=~\"^2..$\"}",
				alertName:           "APIMetricsReadLatency10MErrorBudgetBurning",
				sloType:             sloTypeLatency,
			},
			{
				name: "api-metrics-read-100M-latency-slo",
				labels: map[string]string{
					slo.PropagationLabelsPrefix + "service": "observatorium-api",
					"instance":                              string(envName),
				},
				description:         "API /query endpoint is burning too much error budget for 100M samples, to guarantee latency SLOs.",
				successOrErrorsExpr: "up_custom_query_duration_seconds_bucket{query=\"query-path-sli-1M-samples\", namespace=\"" + upNS[envName] + "\", http_code=~\"^2..$\", le=\"120\"}",
				totalExpr:           "up_custom_query_duration_seconds_count{query=\"query-path-sli-1M-samples\", namespace=\"" + upNS[envName] + "\", http_code=~\"^2..$\"}",
				alertName:           "APIMetricsReadLatency100MErrorBudgetBurning",
				sloType:             sloTypeLatency,
			},
		}
	default:
		panic(signal + " is not an Observatorium signal")
	}

	return slos.GetObjectives(envName)
}

// GenSLO is the function responsible for tying together Pyrra Objectives and converting them into SLO+Rule files.
func GenSLO(genPyrra, genRules *mimic.Generator) {
	// Add on extra Telemeter-only SLOs.
	var telemeterProdObjectives []pyrrav1alpha1.ServiceLevelObjective
	telemeterProdObjectives = append(telemeterProdObjectives, TelemeterSLOs(telemeterProduction)...)
	telemeterProdObjectives = append(telemeterProdObjectives, ObservatoriumSLOs(telemeterProduction, metricsSignal)...)

	var telemeterStageObjectives []pyrrav1alpha1.ServiceLevelObjective
	telemeterStageObjectives = append(telemeterStageObjectives, TelemeterSLOs(telemeterStaging)...)
	telemeterStageObjectives = append(telemeterStageObjectives, ObservatoriumSLOs(telemeterStaging, metricsSignal)...)

	// Add on for Rhelemeter SLOs, which are a subset of Telemeter SLOs.
	var rhelemeterProdObjectives []pyrrav1alpha1.ServiceLevelObjective
	rhelemeterProdObjectives = append(rhelemeterProdObjectives, RhelemeterSLOs(rhelemeterProduction)...)

	var rhelemeterStageObjectives []pyrrav1alpha1.ServiceLevelObjective
	rhelemeterStageObjectives = append(rhelemeterStageObjectives, RhelemeterSLOs(rhelemeterStaging)...)

	envSLOs(
		rhelemeterProduction,
		rhelemeterProdObjectives,
		"rhobs-slos-rhelemeter-production",
		genPyrra,
		genRules,
	)

	envSLOs(
		rhelemeterStaging,
		rhelemeterStageObjectives,
		"rhobs-slos-rhelemeter-stage",
		genPyrra,
		genRules,
	)

	envSLOs(
		telemeterProduction,
		telemeterProdObjectives,
		"rhobs-slos-telemeter-production",
		genPyrra,
		genRules,
	)

	envSLOs(
		telemeterStaging,
		telemeterStageObjectives,
		"rhobs-slos-telemeter-stage",
		genPyrra,
		genRules,
	)

	envSLOs(
		mstProduction,
		ObservatoriumSLOs(mstProduction, metricsSignal),
		"rhobs-slos-mst-production",
		genPyrra,
		genRules,
	)

	envSLOs(
		mstStage,
		ObservatoriumSLOs(mstStage, metricsSignal),
		"rhobs-slos-mst-stage",
		genPyrra,
		genRules,
	)

}

// envSLOs generates the resultant config for a particular rhobsInstanceEnv.
func envSLOs(envName rhobsInstanceEnv, objs []pyrrav1alpha1.ServiceLevelObjective, ruleFilename string, genPyrra, genRules *mimic.Generator) {
	for _, obj := range objs {
		name := string(envName) + "-" + obj.ObjectMeta.Name + ".yaml"
		genPyrra.Add(name, encoding.GhodssYAML(obj))
	}

	// We add "" to encoding as first arg, so that we get a YAML doc directive
	// at the start of the file as per app-interface format.
	genRules.Add(ruleFilename+".prometheusrules.yaml", encoding.GhodssYAML("", makePrometheusRule(envName, objs, ruleFilename)))
}

// appInterfacePrometheusRule allows adding schema field to the generated YAML.
type appInterfacePrometheusRule struct {
	Schema string `json:"$schema"`
	monitoringv1.PrometheusRule
}

// Adapted from https://github.com/pyrra-dev/pyrra/blob/v0.5.3/kubernetes/controllers/servicelevelobjective.go#L207
// Helps us group and generate SLO rules into monitoringv1.PrometheusRule objects which are embedded in appInterfacePrometheusRule struct.
// Ideally, this can be done via pyrra generate command somehow. Upstream PR: https://github.com/pyrra-dev/pyrra/pull/620
// However even with CLI we might need to generate in specific format, and group together  SLO rules in different ways.
func makePrometheusRule(envName rhobsInstanceEnv, objs []pyrrav1alpha1.ServiceLevelObjective, name string) appInterfacePrometheusRule {
	grp := []monitoringv1.RuleGroup{}
	for _, obj := range objs {
		objective, err := obj.Internal()
		if err != nil {
			mimic.PanicErr(err)
		}

		increases, err := objective.IncreaseRules()
		if err != nil {
			mimic.PanicErr(err)
		}
		grp = append(grp, increases)

		burnrates, err := objective.Burnrates()
		if err != nil {
			mimic.PanicErr(err)
		}
		grp = append(grp, burnrates)

		generic, err := objective.GenericRules()
		if err != nil {
			mimic.PanicErr(err)
		}
		grp = append(grp, generic)
	}

	// AppSRE customizations.
	for i := range grp {
		for j := range grp[i].Rules {
			if grp[i].Rules[j].Alert != "" {
				// Prune certain alert labels.
				delete(grp[i].Rules[j].Labels, "le")
				delete(grp[i].Rules[j].Labels, "client")
				delete(grp[i].Rules[j].Labels, "container")

				// Hack for AM alert labels.
				if v, ok := grp[i].Rules[j].Labels["service"]; ok && v == "observatorium-alertmanager" {
					grp[i].Rules[j].Labels["service"] = "observatorium-api"
				}
			}

			// Make long/short labels more descriptive.
			if v, ok := grp[i].Rules[j].Labels["long"]; ok {
				grp[i].Rules[j].Labels["long_burnrate_window"] = v
				delete(grp[i].Rules[j].Labels, "long")
			}

			if v, ok := grp[i].Rules[j].Labels["short"]; ok {
				grp[i].Rules[j].Labels["short_burnrate_window"] = v
				delete(grp[i].Rules[j].Labels, "short")
			}
		}
	}
	// We do not want to page on SLO alerts until we're comfortable with how frequently
	// they fire.
	// Ticket: https://issues.redhat.com/browse/RHOBS-781
	// We also do not want to send noise to app-sre Slack when the SLOMetricAbsent alert
	// fires, as the metrics we use for the SLOs are sometimes unitialized for a long time.
	// For example, some SLOS on API endpoints with low traffic sometimes trigger this.
	for i := range grp {
		for j := range grp[i].Rules {
			if grp[i].Rules[j].Alert == "SLOMetricAbsent" {
				grp[i].Rules[j].Labels["severity"] = "medium"
				continue
			}
			if v, ok := grp[i].Rules[j].Labels["severity"]; ok {
				switch v {
				case "critical":
					grp[i].Rules[j].Labels["severity"] = "high"
				case "warning":
					grp[i].Rules[j].Labels["severity"] = "medium"
				}
			}
		}
	}

	return appInterfacePrometheusRule{
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
