#!/bin/bash

set -euo pipefail

ARTIFACT_DIR="${ARTIFACT_DIR:-/tmp/artifacts}"
check_status() {
    oc rollout status $1 -n $2 --timeout=5m || {
        must_gather "$ARTIFACT_DIR"
        exit 1
    }
}

prereq() {
    oc apply -f pre-requisites.yaml
    oc create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml
    oc process -f ../../resources/crds/observatorium-logs-crds-template.yaml | oc apply -f -

}

create_ns() {
    oc create ns minio || true
    oc create ns dex || true
    oc create ns observatorium-metrics || true
    oc create ns observatorium || true
    oc create ns telemeter || true
    oc create ns observatorium-logs || true
    oc create ns observatorium-mst || true
}

minio() {
    oc wait --for=jsonpath='{.status.phase}=Active' namespace/minio --timeout=5s
    oc process --param-file=minio.test.ci.env -f ../minio-template.yaml --local -o yaml | \
        sed -e 's/storage: [0-9].Gi/storage: 0.25Gi/g' | \
        oc apply -n minio -f -
    check_status deployment/minio minio
}

dex() {
    oc wait --for=jsonpath='{.status.phase}=Active' namespace/dex --timeout=5s
    oc process --param-file=dex.test.ci.env -f ../dex-template.yaml --local -o yaml | \
        sed -e 's/storage: [0-9].Gi/storage: 0.25Gi/g' | \
        oc apply -n dex -f -
    check_status deployment/dex dex
}

observatorium_metrics() {
    oc wait --for=jsonpath='{.status.phase}=Active' namespace/observatorium-metrics --timeout=5s
    oc process -f ../observatorium-metrics-thanos-objectstorage-secret-template.yaml | \
         oc apply --namespace observatorium-metrics -f -
    oc apply -f ../observatorium-alertmanager-config-secret.yaml --namespace observatorium-metrics
    oc apply -f ../observatorium-cluster-role.yaml
    oc apply -f ../observatorium-cluster-role-binding.yaml
    oc apply --namespace observatorium-metrics -f ../observatorium-service-account.yaml
    oc process --param-file=observatorium-metrics.ci.env \
        -f ../../resources/services/observatorium-metrics-template.yaml | \
        oc apply --namespace observatorium-metrics -f -
    oc process --param-file=observatorium-metric-federation-rule.test.ci.env \
        -f ../../resources/services/metric-federation-rule-template.yaml| \
        oc apply --namespace observatorium-metrics -f -
    resources=$(
        oc get statefulsets -o name -n observatorium-metrics
        oc get deployments -o name -n observatorium-metrics
    )
    for res in $resources; do
        check_status $res observatorium-metrics
    done
}

observatorium() {
    oc wait --for=jsonpath='{.status.phase}=Active' namespace/observatorium --timeout=5s
    oc apply -f ../observatorium-rules-objstore-secret.yaml --namespace observatorium
    oc apply -f ../observatorium-rhobs-tenant-secret.yaml --namespace observatorium
    oc apply --namespace observatorium -f ../observatorium-service-account.yaml
    oc apply -f ../observatorium-parca-secret.yaml --namespace observatorium
    rbac
    oc process --param-file=observatorium.test.ci.env \
        -f ../../resources/services/observatorium-template.yaml | \
        oc apply --namespace observatorium -f -
    oc process --param-file=observatorium-parca.test.ci.env \
        -f ../../resources/services/parca-template.yaml| \
        oc apply --namespace observatorium -f -
    oc process --param-file=observatorium-jaeger.test.ci.env \
        -f ../../resources/services/jaeger-template.yaml| \
        oc apply --namespace observatorium -f -
    resources=$(
        oc get statefulsets -o name -n observatorium
        oc get deployments -o name -n observatorium
    )
    for res in $resources; do
        check_status $res observatorium
    done

}

telemeter() {
    oc wait --for=jsonpath='{.status.phase}=Active' namespace/telemeter --timeout=5s
    oc apply --namespace telemeter -f ../telemeter-token-refersher-oidc-secret.yaml
    oc process --param-file=telemeter.ci.env \
        -f ../../resources/services/telemeter-template.yaml | \
        oc apply --namespace telemeter -f -
    resources=$(
        oc get statefulsets -o name -n telemeter
        oc get deployments -o name -n telemeter
    )
    for res in $resources; do
        check_status $res telemeter
    done
}

rbac(){
    oc process -f ../../resources/services/parca-observatorium-remote-ns-rbac-template.yaml | \
        oc apply -f -
}

observatorium_logs(){
    oc apply --namespace observatorium-logs -f ../observatorium-logs-secret.yaml
    oc process --param-file=observatorium-logs.test.ci.env -f \
        ../../resources/services/observatorium-logs-template.yaml | \
        oc apply --namespace observatorium-logs -f -
    resources=$(
        oc get statefulsets -o name -n observatorium-logs
        oc get deployments -o name -n observatorium-logs
    )
    for res in $resources; do
        check_status $res observatorium-logs
    done
}

run_test() {
    oc apply -n observatorium -f test-tenant.yaml
    oc apply -n observatorium -f rbac.yaml
    oc rollout restart deployment/observatorium-observatorium-api -n observatorium
    check_status deployment/observatorium-observatorium-api observatorium
    oc apply -n observatorium -f observatorium-up-metrics.yaml
    oc wait --for=condition=complete --timeout=5m \
        -n observatorium job/observatorium-up-metrics || {
        must_gather "$ARTIFACT_DIR" 
        exit 1
    }
}

must_gather() {
    local artifact_dir="$1"

    for namespace in minio dex observatorium observatorium-metrics telemeter; do
        mkdir -p "$artifact_dir/$namespace"

        for name in $(oc get pods -n "$namespace" -o jsonpath='{.items[*].metadata.name}') ; do
            oc -n "$namespace" describe pod "$name" > "$artifact_dir/$namespace/$name.describe"
            oc -n "$namespace" get pod "$name" -o yaml > "$artifact_dir/$namespace/$name.yaml"

            for initContainer in $(oc -n "$namespace" get pod "$name" -o jsonpath='{.spec.initContainers[*].name}') ; do
                oc -n "$namespace" logs "$name" -c "$initContainer" > "$artifact_dir/$namespace/$name-$initContainer.logs"
            done

            for container in $(oc -n "$namespace" get pod "$name" -o jsonpath='{.spec.containers[*].name}') ; do
                oc -n "$namespace" logs "$name" -c "$container" > "$artifact_dir/$namespace/$name-$container.logs"
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

ci.setup() {
    prereq
    create_ns
    minio
    dex
    observatorium
}

ci.metrics() {
    observatorium_metrics
    telemeter
    run_test
}

ci.logs() {
    observatorium_logs
    #run_test
}

ci.traces(){
    #TODO
    :
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

