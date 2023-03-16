#!/bin/bash

set -e
set -o pipefail

ARTIFACT_DIR="${ARTIFACT_DIR:-/tmp/artifacts}"
INFO="INFO"
log_info(){
    echo "$(date "+%Y-%m-%d %H:%M:%S") [$INFO] $1"
}
check_status(){
    res=$1
    namespace=$2
    log_info "Checking status of $res inside $namespace"
    oc rollout status $res -n $namespace --timeout=5m || (must_gather "$ARTIFACT_DIR" && exit 1)
}
prereq(){
    log_info "Deploying prerequisites on cluster"
    oc apply -f pre-requisites.yaml
    oc process -f ../resources/crds/observatorium-logs-crds-template.yaml | oc apply -f -

}
minio(){
    log_info "Deploying resources inside minio namespace"
    oc create ns minio || true
    sleep 5
    oc process -f ../minio-template.yaml -p MINIO_CPU_REQUEST=30m -p MINIO_CPU_LIMITS=50m -p MINIO_MEMORY_REQUEST=50Mi -p MINIO_MEMORY_LIMITS=100Mi --local -o yaml | sed -e 's/storage: [0-9].Gi/storage: 0.25Gi/g' | oc apply -n minio -f -
    sleep 5 
    check_status deployment/minio minio
}
dex(){
    log_info "Deploying resources inside dex namespace"
    oc create ns dex || true
    sleep 5
    oc process -f ../dex-template.yaml -p DEX_CPU_REQUEST=30m -p DEX_CPU_LIMITS=50m -p DEX_MEMORY_REQUEST=50Mi -p DEX_MEMORY_LIMITS=100Mi --local -o yaml | sed -e 's/storage: [0-9].Gi/storage: 0.25Gi/g' | oc apply -n dex -f -
    sleep 5
    check_status deployment/dex dex
}
observatorium_metrics(){
    log_info "Deploying resources inside observatorium-metrics namespace"
    oc create ns observatorium-metrics || true
    sleep 5
    oc process -f ../observatorium-metrics-thanos-objectstorage-secret-template.yaml | oc apply --namespace observatorium-metrics -f - 
    oc apply -f ../observatorium-alertmanager-config-secret.yaml --namespace observatorium-metrics
    oc apply -f ../observatorium-cluster-role.yaml
    oc apply -f ../observatorium-cluster-role-binding.yaml
    oc apply --namespace observatorium-metrics -f ../observatorium-service-account.yaml
    oc process --param-file=observatorium-metrics.ci.env -f ../../resources/services/observatorium-metrics-template.yaml | oc apply --namespace observatorium-metrics -f - 
    sleep 5
    resources=$(oc get statefulsets -o name -n observatorium-metrics ; oc get deployments -o name -n observatorium-metrics)
    for res in $resources
    do
        check_status $res observatorium-metrics
    done
}
observatorium(){
    log_info "Deploying resources inside observatorium namespace"
    oc create ns observatorium || true
    sleep 5
    oc apply -f ../observatorium-rules-objstore-secret.yaml --namespace observatorium 
    oc apply -f ../observatorium-rhobs-tenant-secret.yaml --namespace observatorium 
    oc process --param-file=observatorium.test.ci.env -f ../../resources/services/observatorium-template.yaml | oc apply --namespace observatorium -f -
    sleep 5
    resources=$(oc get statefulsets -o name -n observatorium ; oc get deployments -o name -n observatorium)
    for res in $resources
    do
        check_status $res observatorium
    done

}
telemeter(){
    log_info "Deploying resources inside telemeter namespace"
    oc create ns telemeter || true
    sleep 5
    oc apply --namespace telemeter -f ../telemeter-token-refersher-oidc-secret.yaml 
    oc process --param-file=telemeter.ci.env -f ../../resources/services/telemeter-template.yaml | oc apply --namespace telemeter  -f - 
    sleep 5
    resources=$(oc get statefulsets -o name -n telemeter ; oc get deployments -o name -n telemeter)
    for res in $resources
    do
        check_status $res telemeter
    done
}
run_test(){
    log_info "Deploying observatorium-up for testing"
    oc apply -n observatorium -f test-tenant.yaml
    oc apply -n observatorium -f rbac.yaml
    oc rollout restart deployment/observatorium-observatorium-api -n observatorium
    check_status deployment/observatorium-observatorium-api observatorium
    oc apply -n observatorium -f observatorium-up-metrics.yaml
    oc wait --for=condition=complete --timeout=5m -n observatorium job/observatorium-up-metrics || (must_gather "$ARTIFACT_DIR" && exit 1)
}
must_gather() {
    local artifact_dir="$1"

    for namespace in minio dex observatorium observatorium-metrics telemeter; do
        mkdir -p "$artifact_dir/$namespace"

        for name in $(oc get pods -n "$namespace" -o jsonpath='{.items[*].metadata.name}') ; do
            oc -n "$namespace" describe pod "$name" > "$artifact_dir/$namespace/$name.describe"
            oc -n "$namespace" get pod "$name" -o yaml > "$artifact_dir/$namespace/$name.yaml"

            for initContainer in $(oc -n "$namespace" get po "$name" -o jsonpath='{.spec.initContainers[*].name}') ; do
                oc -n "$namespace" logs "$name" -c "$initContainer" > "$artifact_dir/$namespace/$name-$initContainer.logs"
            done

            for container in $(oc -n "$namespace" get po "$name" -o jsonpath='{.spec.containers[*].name}') ; do
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
case $1 in
metrics)
    prereq
    minio
    dex
    observatorium_metrics
    observatorium
    run_test
    telemeter
    ;;
logs)
    #TODO
    ;;
traces)
    #TODO
    ;;
*)
    echo "usage: $(basename "$0") { metrics | logs | traces }"
    ;;
esac
