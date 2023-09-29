#!/bin/bash

set -euo pipefail

ARTIFACT_DIR="${ARTIFACT_DIR:-/tmp/artifacts}"
NS=(minio dex observatorium observatorium-metrics telemeter observatorium-mst observatorium-tools observatorium-logs rhelemeter)
check_status() {
    echo "checking rollout status of $1 inside $2 namespace"
    oc rollout status $1 -n $2 --timeout=5m || {
        must_gather "$ARTIFACT_DIR"
        exit 1
    }
}

prereq() {
    oc apply -f manifests/pre-requisites.yaml
    oc create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml
    oc create -f https://raw.githubusercontent.com/grafana/loki/main/operator/bundle/openshift/manifests/loki.grafana.com_lokistacks.yaml
}

ns() {
    for ns in "${NS[@]}"; do
        oc create ns $ns || true
    done
}

minio() {
    oc wait --for=jsonpath='{.status.phase}=Active' namespace/minio --timeout=5s
    oc process --param-file=env/minio.test.ci.env -f ../deploy/manifests/minio-template.yaml | \
        oc apply -n minio -f -
}

dex() {
    oc wait --for=jsonpath='{.status.phase}=Active' namespace/dex --timeout=5s
    oc process --param-file=env/dex.test.ci.env -f ../deploy/manifests/dex-template.yaml | \
        oc apply -n dex -f -
}

observatorium_metrics() {
    oc wait --for=jsonpath='{.status.phase}=Active' namespace/observatorium-metrics --timeout=5s
    oc process -f ../deploy/manifests/observatorium-metrics-thanos-objectstorage-secret-template.yaml | \
         oc apply --namespace observatorium-metrics -f -
    oc apply -f ../deploy/manifests/observatorium-alertmanager-config-secret.yaml --namespace observatorium-metrics
    oc apply -f ../deploy/manifests/observatorium-cluster-role.yaml
    oc apply -f ../deploy/manifests/observatorium-cluster-role-binding.yaml
    oc apply --namespace observatorium-metrics -f ../deploy/manifests/observatorium-service-account.yaml
    oc process --param-file=env/observatorium-metrics.ci.env \
        -f ../../resources/services/observatorium-metrics-template.yaml | \
        oc apply --namespace observatorium-metrics -f -
    oc process --param-file=env/observatorium-metric-federation-rule.test.ci.env \
        -f ../../resources/services/metric-federation-rule-template.yaml| \
        oc apply --namespace observatorium-metrics -f -
}

observatorium_tools(){
    oc wait --for=jsonpath='{.status.phase}=Active' namespace/observatorium-tools --timeout=5s
    oc apply --namespace observatorium-tools -f ../deploy/manifests/observatorium-tools-network-policy.yaml
    oc process --param-file=env/logging.test.ci.env -f ../../resources/services/meta-monitoring/logging-template.yaml | oc apply --namespace observatorium-tools -f -
    oc process --param-file=env/observatorium-parca.test.ci.env -f ../../resources/services/meta-monitoring/profiling-template.yaml | oc apply --namespace observatorium-tools -f -
}

observatorium() {
    oc wait --for=jsonpath='{.status.phase}=Active' namespace/observatorium --timeout=5s
    oc apply -f ../deploy/manifests/observatorium-rules-objstore-secret.yaml --namespace observatorium
    oc apply -f ../deploy/manifests/observatorium-rhobs-tenant-secret.yaml --namespace observatorium
    oc apply --namespace observatorium -f ../deploy/manifests/observatorium-service-account.yaml
    oc process --param-file=env/observatorium.test.ci.env \
        -f ../../resources/services/observatorium-template.yaml | \
        oc apply --namespace observatorium -f -
    oc process --param-file=env/observatorium-jaeger.test.ci.env \
        -f ../../resources/services/jaeger-template.yaml| \
        oc apply --namespace observatorium -f -
}

telemeter() {
    oc wait --for=jsonpath='{.status.phase}=Active' namespace/telemeter --timeout=5s
    oc apply --namespace telemeter -f ../deploy/manifests/telemeter-token-refersher-oidc-secret.yaml
    oc process --param-file=env/telemeter.ci.env \
        -f ../../resources/services/telemeter-template.yaml | \
        oc apply --namespace telemeter -f -
}

rhelemeter() {
    oc wait --for=jsonpath='{.status.phase}=Active' namespace/rhelemeter --timeout=5s
    oc process -f --param-file=env/rhelemeter.test.ci.env -p RHELEMETER_CLIENT_INFO_PSK=ZXhhbXBsZS1hcHAtc2VjcmV0 \
        -f ../../resources/services/rhelemeter-template.yaml | oc apply --namespace rhelemeter -f -
}

run_test() {
    for ns in "${NS[@]}" ; do
        resources=$(
            oc get statefulsets -o name -n $ns
            oc get deployments -o name -n $ns
        )
        for res in $resources; do
            check_status $res $ns
        done
    done
    oc apply -n observatorium -f manifests/test-tenant.yaml
    oc apply -n observatorium -f manifests/rbac.yaml
    oc rollout restart deployment/observatorium-observatorium-api -n observatorium
    check_status deployment/observatorium-observatorium-api observatorium
    oc apply -n observatorium -f manifests/observatorium-up-metrics.yaml
    oc wait --for=condition=complete --timeout=5m \
        -n observatorium job/observatorium-up-metrics || {
        must_gather "$ARTIFACT_DIR" 
        exit 1
    }
}

must_gather() {
    local artifact_dir="$1"

    for ns in "${NS[@]}"; do
        mkdir -p "$artifact_dir/$ns"

        for name in $(oc get pods -n "$ns" -o jsonpath='{.items[*].metadata.name}') ; do
            oc -n "$ns" describe pod "$name" > "$artifact_dir/$ns/$name.describe"
            oc -n "$ns" get pod "$name" -o yaml > "$artifact_dir/$ns/$name.yaml"

            for initContainer in $(oc -n "$ns" get pod "$name" -o jsonpath='{.spec.initContainers[*].name}') ; do
                oc -n "$ns" logs "$name" -c "$initContainer" > "$artifact_dir/$ns/$name-$initContainer.logs"
            done

            for container in $(oc -n "$ns" get pod "$name" -o jsonpath='{.spec.containers[*].name}') ; do
                oc -n "$ns" logs "$name" -c "$container" > "$artifact_dir/$ns/$name-$container.logs"
            done
        done
    done

    oc describe nodes > "$artifact_dir/nodes"
    oc get pods --all-namespaces > "$artifact_dir/pods"
    oc get deploy --all-namespaces > "$artifact_dir/deployments"
    oc get statefulset --all-namespaces > "$artifact_dir/statefulsets"
    oc get services --all-namespaces > "$artifact_dir/services"
    oc get endpoints --all-namespaces > "$artifact_dir/endpoints"
}

ci.deploy() {
    prereq
    ns
    minio
    dex
    observatorium
    observatorium_metrics
    telemeter
    rhelemeter
    observatorium_tools
}

ci.tests() {
    run_test
}

ci.help() {
	local fns=$(declare -F -p | cut -f3 -d ' ' | grep '^ci\.' | cut -f2- -d.)
	read -d '^' -r docstring <<EOF_HELP
Usage:
  $(basename "$0") <task>

task:
$(for fn in ${fns[@]};do printf "  - %s\n" "${fn}";done)
^
EOF_HELP
	echo -e "$docstring"
	exit 1
}

is_function() {
	local fn=$1
	[[ $(type -t "$fn") == "function" ]]
	return $?
}

main() {
	local fn=${1:-''}
	local ci_fn="ci.$fn"
	if ! is_function "$ci_fn"; then
		ci.help
	fi
	$ci_fn
	return $?
}
main "$@"
