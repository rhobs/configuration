package main

import (
	"github.com/observatorium/observatorium/configuration_go/kubegen/openshift"
	templatev1 "github.com/openshift/api/template/v1"
	"github.com/philipgough/mimic/encoding"
	monitoringv1 "github.com/prometheus-operator/prometheus-operator/pkg/apis/monitoring/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/intstr"
)

// TelemeterRules generates the Rules for telemetry.
func (s Stage) TelemeterRules() {
	rules := monitoringv1.PrometheusRule{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.coreos.com/v1",
			Kind:       "PrometheusRule",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "telemeter-rules",
			Namespace: s.namespace(),
			Labels: map[string]string{
				"operator.thanos.io/prometheus-rule": "true",
				"app.kubernetes.io/name":             "telemeter",
				"app.kubernetes.io/part-of":          "rhobs",
				"app.kubernetes.io/component":        "rules",
			},
		},
		Spec: monitoringv1.PrometheusRuleSpec{
			Groups: rules(),
		},
	}

	gen := s.generator("rhobs-thanos-operator")
	template := openshift.WrapInTemplate([]runtime.Object{&rules}, metav1.ObjectMeta{Name: "telemeter-rules"}, []templatev1.Parameter{})
	encoder := encoding.GhodssYAML(template)
	gen.Add("telemeter-rules.yaml", encoder)
	gen.Generate()
}

// TelemeterRules generates the Rules for telemetry for a local environment.
func (l Local) TelemeterRules() {
	rules := monitoringv1.PrometheusRule{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "monitoring.coreos.com/v1",
			Kind:       "PrometheusRule",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      "telemeter-rules",
			Namespace: l.namespace(),
			Labels: map[string]string{
				"operator.thanos.io/prometheus-rule": "true",
				"app.kubernetes.io/name":             "telemeter",
				"app.kubernetes.io/part-of":          "rhobs",
				"app.kubernetes.io/component":        "rules",
			},
		},
		Spec: monitoringv1.PrometheusRuleSpec{
			Groups: rules(),
		},
	}

	gen := l.generator("rhobs-thanos-operator")
	encoder := encoding.GhodssYAML(rules)
	gen.Add("telemeter-rules.yaml", encoder)
	gen.Generate()
}

func rules() []monitoringv1.RuleGroup {
	interval := monitoringv1.Duration("4m")
	tenantLbls := map[string]string{"tenant_id": "FB870BF3-9F3A-44FF-9BF7-D7A047A52F43"}

	return []monitoringv1.RuleGroup{
		{
			Name:     "telemeter-telemeter.rules",
			Interval: &interval,
			Rules: []monitoringv1.Rule{
				{
					Record: "steps:count1h",
					Expr:   intstr.FromString("count_over_time(vector(1)[1h:5m])"),
					Labels: tenantLbls,
				},
				{
					Record: "name_reason:cluster_operator_degraded:count",
					Expr:   intstr.FromString("count by (name,reason) (cluster_operator_conditions{condition=\"Degraded\"} == 1)"),
					Labels: tenantLbls,
				},
				{
					Record: "name_reason:cluster_operator_unavailable:count",
					Expr:   intstr.FromString("count by (name,reason) (cluster_operator_conditions{condition=\"Available\"} == 0)"),
					Labels: tenantLbls,
				},
				{
					Record: "id_code:apiserver_request_error_rate_sum:max",
					Expr:   intstr.FromString("sort_desc(max by (_id,code) (code:apiserver_request_count:rate:sum{code=~\"(4|5)\\\\d\\\\d\"}) > 0.5)"),
					Labels: tenantLbls,
				},
				{
					Record: "id_version:cluster_available",
					Expr:   intstr.FromString("bottomk by (_id) (1, max by (_id, version) (0 * cluster_version{type=\"failure\"}) or max by (_id, version) (1 + 0 * cluster_version{type=\"current\"})"),
					Labels: tenantLbls,
				},
				{
					Record: "id_version_ebs_account_internal:cluster_subscribed",
					Expr:   intstr.FromString("topk by (_id) (1, max by (_id, managed, ebs_account, internal) (label_replace(label_replace((ocm_subscription{support=~\"Standard|Premium|Layered\"} * 0 + 1) or ocm_subscription * 0, \"internal\", \"true\", \"email_domain\", \"redhat.com|(.*\\\\.|^)ibm.com\"), \"managed\", \"\", \"managed\", \"false\")) + on(_id) group_left(version) (topk by (_id) (1, id_version*0)) + on(_id) group_left(install_type) (topk by (_id) (1, id_install_type*0)) + on(_id) group_left(host_type) (topk by (_id) (1, id_primary_host_type*0)) + on(_id) group_left(provider) (topk by (_id) (1, id_provider*0)))"),
					Labels: tenantLbls,
				},
				{
					Record: "id_primary_host_type",
					Expr:   intstr.FromString("0 * (max by (_id,host_type) (topk by (_id) (1, label_replace(label_replace(label_replace(label_replace(label_replace(label_replace(cluster:virt_platform_nodes:sum, \"host_type\", \"$1\", \"type\", \"(aws|ibm_.*|ovirt|none|rhev|gcp|openstack|hyperv|vmware|nutanix.*)\"), \"host_type\", \"virt-unknown\", \"host_type\", \"\"), \"host_type\", \"kvm-unknown\", \"type\", \"kvm\"), \"host_type\", \"xen-unknown\", \"type\", \"xen.*\"), \"host_type\", \"metal\", \"host_type\", \"none\"), \"host_type\", \"ibm-$1\", \"host_type\", \"ibm[_-](power|systemz).*\"))) or on(_id) label_replace(max by (_id) (cluster_version{type=\"current\"}), \"host_type\", \"\", \"host_type\", \"\"))"),
					Labels: tenantLbls,
				},
				{
					Record: "id_provider",
					Expr:   intstr.FromString("0 * topk by (_id) (1, group by (_id, provider) (label_replace(cluster_infrastructure_provider, \"provider\", \"$1\", \"type\", \"(.*)\")) or on(_id) label_replace(group by (_id) (cluster_version{type=\"current\"}), \"provider\", \"unknown\", \"provider\", \"\"))"),
					Labels: tenantLbls,
				},
				{
					Record: "id_version",
					Expr:   intstr.FromString("0 * (max by (_id,version) (topk by (_id) (1, cluster_version{type=\"current\"})) or on(_id) label_replace(max by (_id) (cluster:node_instance_type_count:sum*0), \"version\", \"\", \"unknown\", \"\"))"),
					Labels: tenantLbls,
				},
				{
					Record: "id_install_type",
					Expr:   intstr.FromString("(count by (_id, install_type) (label_replace(label_replace(label_replace(label_replace(label_replace(label_replace(label_replace(topk by (_id) (1, cluster_installer), \"install_type\", \"upi\", \"type\", \"other\"), \"install_type\", \"ipi\", \"type\", \"openshift-install\"), \"install_type\", \"hive\", \"invoker\", \"hive\"), \"install_type\", \"assisted-installer\", \"invoker\", \"assisted-installer\"), \"install_type\", \"infrastructure-operator\", \"invoker\", \"assisted-installer-operator\"), \"install_type\", \"agent-installer\", \"invoker\", \"agent-installer\"), \"install_type\", \"hypershift\", \"invoker\", \"hypershift\")) or on(_id) (label_replace(count by (_id) (cluster:virt_platform_nodes:sum), \"install_type\", \"unknown\", \"install_type\", \"\"))) * 0"),
					Labels: tenantLbls,
				},
				{
					Record: "id_cloudpak_type",
					Expr:   intstr.FromString("0 * (max by (_id,cloudpak_type) (topk by (_id) (1, count by (_id,cloudpak_type) (label_replace(subscription_sync_total{installed=~\"ibm-((licensing|common-service)-operator).*\"}, \"cloudpak_type\", \"unknown\", \"\", \".*\")))))"),
					Labels: tenantLbls,
				},
				{
					Record: "id_network_type",
					Expr:   intstr.FromString("topk by(_id) (1, (label_replace(7+0*count by (_id) (cluster:usage:resources:sum{resource=\"netnamespaces.network.openshift.io\"}), \"network_type\", \"OpenshiftSDN\", \"\", \"\") > 0) or (label_replace(6+0*count by (_id) (cluster:usage:resources:sum{resource=\"clusterinformations.crd.projectcalico.org\"}), \"network_type\", \"Calico\", \"\", \"\") > 0) or (label_replace(5+0*count by (_id) (cluster:usage:resources:sum{resource=\"acicontainersoperators.aci.ctrl\"}), \"network_type\", \"ACI\", \"\", \"\") > 0) or (label_replace(4+0*count by (_id) (cluster:usage:resources:sum{resource=\"kuryrnetworks.openstack.org\"}), \"network_type\", \"Kuryr\", \"\", \"\") > 0) or (label_replace(3+0*count by (_id) (cluster:usage:resources:sum{resource=\"ciliumendpoints.cilium.io\"}), \"network_type\", \"Cilium\", \"\", \"\") > 0) or (label_replace(2+0*count by (_id) (cluster:usage:resources:sum{resource=\"ncpconfigs.nsx.vmware.com\"}), \"network_type\", \"VMWareNSX\", \"\", \"\") > 0) or (label_replace(1+0*count by (_id) (cluster:usage:resources:sum{resource=\"egressips.k8s.ovn.org\"}), \"network_type\", \"OVNKube\", \"\", \"\")) or (label_replace(0+0*max by (_id) (cluster:node_instance_type_count:sum*0), \"network_type\", \"unknown\", \"\", \"\")))"),
					Labels: tenantLbls,
				},
				{
					Record: "ebs_account_account_type_email_domain_internal",
					Expr:   intstr.FromString("0 * topk by (ebs_account) (1, max by (ebs_account,account_type,internal,email_domain) (label_replace(label_replace(label_replace(ocm_subscription{email_domain=\"redhat.com\"}*0+5, \"class\", \"Internal\", \"class\", \".*\") or label_replace(ocm_subscription{class!=\"Customer\",email_domain=~\"(.*\\\\.|^)ibm.com\"}*0+4, \"class\", \"Internal\", \"class\", \".*\") or (ocm_subscription{class=\"Customer\"}*0+3) or (ocm_subscription{class=\"Partner\"}*0+2) or (ocm_subscription{class=\"Evaluation\"}*0+1) or label_replace(ocm_subscription{class!~\"Evaluation|Customer|Partner\"}*0+0, \"class\", \"\", \"class\", \".*\"), \"account_type\", \"$1\", \"class\", \"(.+)\"), \"internal\", \"true\", \"email_domain\", \"redhat.com|(.*\\\\.|^)ibm.com\") ))"),
					Labels: tenantLbls,
				},
				{
					Record: "acm_top500_mcs:acm_managed_cluster_info",
					Expr:   intstr.FromString("topk(500, sum (acm_managed_cluster_info) by (managed_cluster_id, cloud, created_via, endpoint, instance, job, namespace, pod, service, vendor, version))"),
					Labels: tenantLbls,
				},
				{
					Record: "cluster:usage:workload:capacity_physical_cpu_hours",
					Expr:   intstr.FromString("max by(_id) (sum_over_time(cluster:usage:workload:capacity_physical_cpu_cores:max:5m[1h:5m])) / scalar(steps:count1h)"),
					Labels: tenantLbls,
				},
				{
					Record: "cluster:usage:workload:capacity_physical_instance_hours",
					Expr:   intstr.FromString("max by(_id) (count_over_time(cluster:usage:workload:capacity_physical_cpu_cores:max:5m[1h:5m])) / scalar(steps:count1h)"),
					Labels: tenantLbls,
				},
				{
					Record: "cluster:usage:workload:capacity_virtual_cpu_hours",
					Expr:   intstr.FromString("sum by(_id) (sum_over_time(cluster:capacity_cpu_cores:sum{label_node_role_kubernetes_io = ''}[1h:5m])) / scalar(steps:count1h)"),
					Labels: tenantLbls,
				},
				{
					Record: "cluster:cpu_capacity_cores:_id",
					Expr:   intstr.FromString("group by(_id, tenant_id) (cluster:capacity_cpu_cores:sum{label_node_openshift_io_os_id=\"rhcos\"}) * 0"),
					Labels: tenantLbls,
				},
				{
					Record: "cluster:capacity_effective_cpu_cores",
					Expr:   intstr.FromString("# worker amd64\n(sum by (_id, tenant_id) (cluster:capacity_cpu_cores:sum{label_node_openshift_io_os_id=\"rhcos\",label_node_role_kubernetes_io!=\"master\",label_node_role_kubernetes_io!=\"infra\",label_kubernetes_io_arch=\"amd64\"}) / 2.0 or cluster:cpu_capacity_cores:_id) +\n# worker non-amd64\n(sum by (_id, tenant_id) (cluster:capacity_cpu_cores:sum{label_node_openshift_io_os_id=\"rhcos\",label_node_role_kubernetes_io!=\"master\",label_node_role_kubernetes_io!=\"infra\",label_kubernetes_io_arch!=\"amd64\"}) or cluster:cpu_capacity_cores:_id) +\n# schedulable control plane amd64\n(sum by (_id, tenant_id) (cluster:capacity_cpu_cores:sum{label_node_openshift_io_os_id=\"rhcos\",label_node_role_kubernetes_io=\"master\",label_kubernetes_io_arch=\"amd64\"}) * on(_id, tenant_id) group by(_id, tenant_id) (cluster_master_schedulable == 1) / 2.0 or cluster:cpu_capacity_cores:_id) +\n# schedulable control plane non-amd64\n(sum by (_id, tenant_id) (cluster:capacity_cpu_cores:sum{label_node_openshift_io_os_id=\"rhcos\",label_node_role_kubernetes_io=\"master\",label_kubernetes_io_arch!=\"amd64\"}) * on(_id, tenant_id) group by(_id, tenant_id) (cluster_master_schedulable == 1) or cluster:cpu_capacity_cores:_id)"),
					Labels: tenantLbls,
				},
				{
					Record: "acm_capacity_effective_cpu_cores",
					Expr:   intstr.FromString("# self managed OpenShift cluster\nmax by (_id, managed_cluster_id) (acm_managed_cluster_info{product=\"OpenShift\"}) * on(managed_cluster_id) group_left() (\n    # On one side, the acm_managed_cluster_info metric has the managed_cluster_id label identifiying the managed cluster and the _id label identifying the hub cluster.\n    # On the other side, the cluster:capacity_effective_cpu_cores metric has the _id label which identifying the managed cluster.\n    # To join the 2 metrics, we need to add a managed_cluster_id label with the same value as _id to the cluster:capacity_effective_cpu_cores metric.\n    label_replace(\n      max by(_id) (cluster:capacity_effective_cpu_cores), \"managed_cluster_id\", \"$1\", \"_id\", \"(.*)\"\n    )\n  ) * 2 or\n# managed OpenShift cluster and non-OpenShift clusters\nmax by (_id, managed_cluster_id) (acm_managed_cluster_worker_cores:max)"),
					Labels: tenantLbls,
				},
				{
					Record: "hostedcluster:hypershift_cluster_vcpus:vcpu_hours",
					Expr:   intstr.FromString("max by(_id) (sum_over_time(hostedcluster:hypershift_cluster_vcpus:max[1h:5m])) / scalar(steps:count1h)"),
					Labels: tenantLbls,
				},
				{
					Record: "rosa:cluster:vcpu_hours",
					Expr:   intstr.FromString("hostedcluster:hypershift_cluster_vcpus:vcpu_hours or on (_id) cluster:usage:workload:capacity_virtual_cpu_hours"),
					Labels: tenantLbls,
				},
			},
		},
	}
}
