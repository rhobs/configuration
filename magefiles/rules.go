package main

import (
	v1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	"github.com/prometheus/prometheus/promql/parser"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/intstr"
)

var MustHavePrometheusRuleLabels = map[string]string{
	"operator.thanos.io/prometheus-rule": "true",
}

// NewPrometheusRule creates a new PrometheusRule object
// and ensures labels have the required keys.
func NewPrometheusRule(
	name, namespace string,
	labels map[string]string,
	annotations map[string]string,
	groups []v1.RuleGroup) *v1.PrometheusRule {

	// Merge MustHavePrometheusRuleLabels with the provided labels
	for key, value := range MustHavePrometheusRuleLabels {
		if _, exists := labels[key]; !exists {
			labels[key] = value
		}
	}

	return &v1.PrometheusRule{
		TypeMeta: metav1.TypeMeta{
			Kind:       "PrometheusRule",
			APIVersion: "monitoring.coreos.com/v1",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:        name,
			Namespace:   namespace,
			Labels:      labels,
			Annotations: annotations,
		},
		Spec: v1.PrometheusRuleSpec{
			Groups: groups,
		},
	}
}

// NewRuleGroup creates a new RuleGroup object
func NewRuleGroup(name, interval string, labels map[string]string, rules []v1.Rule) v1.RuleGroup {
	intervalDuration := v1.Duration(interval)
	return v1.RuleGroup{
		Name:     name,
		Interval: &intervalDuration,
		Rules:    rules,
	}
}

// NewAlertingRule creates a new Rule object
func NewAlertingRule(alertName string, expr parser.Expr, forTime string, labels map[string]string, annotations map[string]string) v1.Rule {
	duration := v1.Duration(forTime)
	return v1.Rule{
		Alert:       alertName,
		Expr:        intstr.FromString(expr.Pretty(0)),
		For:         &duration,
		Labels:      labels,
		Annotations: annotations,
	}
}

// NewRecordingRule creates a new Rule object
func NewRecordingRule(recordName string, expr parser.Expr, labels map[string]string, annotations map[string]string) v1.Rule {
	return v1.Rule{
		Record:      recordName,
		Expr:        intstr.FromString(expr.Pretty(0)),
		Labels:      labels,
		Annotations: annotations,
	}
}
