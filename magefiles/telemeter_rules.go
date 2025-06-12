package main

import (
	"time"

	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	promqlbuilder "github.com/perses/promql-builder"
	"github.com/perses/promql-builder/label"
	"github.com/perses/promql-builder/subquery"
	"github.com/perses/promql-builder/vector"
	"github.com/philipgough/mimic/encoding"
	monitoringv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

// TelemeterRules generates the Rules for telemetry.
func (s Stage) TelemeterRules() {
	gen := s.generator("rhobs-thanos-operator")
	template := openshift.WrapInTemplate([]runtime.Object{
		NewPrometheusRule(
			"telemeter-rules",
			s.namespace(),
			map[string]string{
				"tenant":                      "FB870BF3-9F3A-44FF-9BF7-D7A047A52F43",
				"app.kubernetes.io/name":      "telemeter",
				"app.kubernetes.io/part-of":   "rhobs",
				"app.kubernetes.io/component": "rules",
			},
			map[string]string{},
			rules(),
		),
	}, metav1.ObjectMeta{Name: "telemeter-rules"}, []templatev1.Parameter{})
	encoder := encoding.GhodssYAML(template)
	gen.Add("telemeter-rules.yaml", encoder)
	gen.Generate()
}

// TelemeterRules generates the Rules for telemetry for a local environment.
func (l Local) TelemeterRules() {
	gen := l.generator("rhobs-thanos-operator")
	encoder := encoding.GhodssYAML(NewPrometheusRule(
		"telemeter-rules",
		l.namespace(),
		map[string]string{
			"tenant":                      "FB870BF3-9F3A-44FF-9BF7-D7A047A52F43",
			"app.kubernetes.io/name":      "telemeter",
			"app.kubernetes.io/part-of":   "rhobs",
			"app.kubernetes.io/component": "rules",
		},
		map[string]string{},
		rules(),
	))
	gen.Add("telemeter-rules.yaml", encoder)
	gen.Generate()
}

func rules() []monitoringv1.RuleGroup {
	ruleGroup := NewRuleGroup(
		"telemeter-telemeter.rules",
		"4m",
		map[string]string{"tenant_id": "FB870BF3-9F3A-44FF-9BF7-D7A047A52F43"},
		[]monitoringv1.Rule{
			NewRecordingRule(
				"steps:count1h",
				promqlbuilder.CountOverTime(
					subquery.New(
						subquery.WithExpr(promqlbuilder.Vector(1)),
						subquery.WithRangeAndStep(time.Hour, time.Minute*5),
					),
				),
				map[string]string{},
				map[string]string{},
			),
			NewRecordingRule(
				"name_reason:cluster_operator_degraded:count",
				promqlbuilder.Count(
					promqlbuilder.Eql(
						vector.New(
							vector.WithMetricName("cluster_operator_conditions"),
							vector.WithLabelMatchers(
								label.New("condition").Equal("Degraded"),
							),
						),
						promqlbuilder.NewNumber(1),
					),
				).By("name", "reason"),
				map[string]string{},
				map[string]string{},
			),
			NewRecordingRule(
				"name_reason:cluster_operator_unavailable:count",
				promqlbuilder.Count(
					promqlbuilder.Eql(
						vector.New(
							vector.WithMetricName("cluster_operator_conditions"),
							vector.WithLabelMatchers(
								label.New("condition").Equal("Available"),
							),
						),
						promqlbuilder.NewNumber(0),
					),
				).By("name", "reason"),
				map[string]string{},
				map[string]string{},
			),
			NewRecordingRule(
				"id_code:apiserver_request_error_rate_sum:max",
				promqlbuilder.SortDesc(
					promqlbuilder.Max(
						promqlbuilder.Gtr(
							vector.New(
								vector.WithMetricName("code:apiserver_request_count:rate:sum"),
								vector.WithLabelMatchers(
									label.New("code").EqualRegexp("(4|5)\\d\\d"),
								),
							),
							promqlbuilder.NewNumber(0.5),
						),
					).By("_id", "code"),
				),
				map[string]string{},
				map[string]string{},
			),
			NewRecordingRule(
				"id_version:cluster_available",
				promqlbuilder.BottomK(
					promqlbuilder.Or(
						promqlbuilder.Max(
							promqlbuilder.Mul(
								vector.New(
									vector.WithMetricName("cluster_version"),
									vector.WithLabelMatchers(
										label.New("type").Equal("failure"),
									),
								),
								promqlbuilder.NewNumber(0),
							),
						).By("_id", "version"),
						promqlbuilder.Max(
							promqlbuilder.Add(
								promqlbuilder.NewNumber(1),
								promqlbuilder.Mul(
									vector.New(
										vector.WithMetricName("cluster_version"),
										vector.WithLabelMatchers(
											label.New("type").Equal("current"),
										),
									),
									promqlbuilder.NewNumber(0),
								),
							),
						).By("_id", "version"),
					),
					1,
				).By("_id"),
				map[string]string{},
				map[string]string{},
			),
			NewRecordingRule(
				"id_version_ebs_account_internal:cluster_subscribed",
				promqlbuilder.TopK(
					promqlbuilder.Add(
						promqlbuilder.Add(
							promqlbuilder.Add(
								promqlbuilder.Add(
									promqlbuilder.Max(
										promqlbuilder.LabelReplace(
											promqlbuilder.LabelReplace(
												promqlbuilder.Or(
													promqlbuilder.Add(
														promqlbuilder.Mul(
															vector.New(
																vector.WithMetricName("ocm_subscription"),
																vector.WithLabelMatchers(
																	label.New("support").EqualRegexp("Standard|Premium|Layered"),
																),
															),
															promqlbuilder.NewNumber(0),
														),
														promqlbuilder.NewNumber(1),
													),
													promqlbuilder.Mul(
														vector.New(
															vector.WithMetricName("ocm_subscription"),
														),
														promqlbuilder.NewNumber(0),
													),
												),
												"internal",
												"true",
												"email_domain",
												"redhat.com|(.*\\\\.|^)ibm.com",
											),
											"managed",
											"",
											"managed",
											"false",
										),
									).By("_id", "managed", "ebs_account", "internal"),
									promqlbuilder.TopK(
										promqlbuilder.Mul(
											vector.New(
												vector.WithMetricName("id_version"),
											),
											promqlbuilder.NewNumber(0),
										),
										1,
									).By("_id"),
								).On("_id").GroupLeft("version"),
								promqlbuilder.TopK(
									promqlbuilder.Mul(
										vector.New(
											vector.WithMetricName("id_install_type"),
										),
										promqlbuilder.NewNumber(0),
									),
									1,
								).By("_id"),
							).On("_id").GroupLeft("install_type"),
							promqlbuilder.TopK(
								promqlbuilder.Mul(
									vector.New(
										vector.WithMetricName("id_primary_host_type"),
									),
									promqlbuilder.NewNumber(0),
								),
								1,
							).By("_id"),
						).On("_id").GroupLeft("host_type"),
						promqlbuilder.TopK(
							promqlbuilder.Mul(
								vector.New(
									vector.WithMetricName("id_provider"),
								),
								promqlbuilder.NewNumber(0),
							),
							1,
						).By("_id"),
					).On("_id").GroupLeft("provider"),
					1,
				),
				map[string]string{},
				map[string]string{},
			),
		},
	)
	return []monitoringv1.RuleGroup{ruleGroup}
}
