#!/bin/bash

set -o pipefail

INFO="INFO"
ERROR="ERROR"
log_info(){
    echo "$(date "+%Y-%m-%d %H:%M:%S") [$INFO] $1"
}
log_error(){
    echo "$(date "+%Y-%m-%d %H:%M:%S") [$ERROR] $1"
}
check_pod_status(){
    podname=$1
    namespace=$2
    retry=3
    while [ $retry -ne 0 ]
    do
        containerStatuses=$(oc get $podname -n $namespace -o jsonpath='{.status.containerStatuses[*].state}')
        if [[ $containerStatuses == *'waiting'* || -z $containerStatuses ]];
        then

            log_error "Output: $containerStatuses"
            log_error "Retrying again..."
        else
            log_info "Status of $podname is healthy inside $namespace namespace"
            return
        fi
        sleep 30
        ((retry--))
    done
    log_error "Retry exhausted!!!"
    teardown
    exit 1
}
crds(){
    log_info "Deploying CRD's on cluster"
    oc create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/master/bundle.yaml 1> /dev/null
    oc create -f https://raw.githubusercontent.com/grafana/loki/main/operator/config/crd/bases/loki.grafana.com_recordingrules.yaml 1> /dev/null
    oc create -f https://raw.githubusercontent.com/grafana/loki/main/operator/config/crd/bases/loki.grafana.com_alertingrules.yaml 1> /dev/null

}
role() {
    oc apply -f observatorium-cluster-role.yaml 1> /dev/null
    oc apply -f observatorium-cluster-role-binding.yaml 1> /dev/null
    oc apply --namespace observatorium-metrics -f observatorium-service-account.yaml 1> /dev/null
}
minio(){
    log_info "Deploying resources inside minio namespace"
    oc create ns minio 1> /dev/null
    sleep 5
    oc process -f minio-template.yaml -p MINIO_CPU_REQUEST=15m -p MINIO_CPU_LIMITS=30m -p MINIO_MEMORY_REQUEST=100Mi -p MINIO_MEMORY_LIMITS=150Mi --local -o yaml | sed -e 's/storage: [0-9].Gi/storage: 0.25Gi/g' | oc apply -n minio -f - 1> /dev/null
    sleep 20
    podname=$(oc get pods -n minio -l app.kubernetes.io/name=minio -o name)
    sleep 30
    check_pod_status $podname minio
}
dex(){
    log_info "Deploying resources inside dex namespace"
    oc create ns dex 1> /dev/null
    sleep 5
    oc process -f dex-template.yaml -p DEX_CPU_REQUEST=15m -p DEX_CPU_LIMITS=30m -p DEX_MEMORY_REQUEST=25Mi -p DEX_MEMORY_LIMITS=50Mi --local -o yaml | sed -e 's/storage: [0-9].Gi/storage: 0.25Gi/g' | oc apply -n dex -f - 1> /dev/null
    sleep 20
    podname=$(oc get pods -n dex -l app.kubernetes.io/name=dex -o name)
    sleep 30
    check_pod_status $podname dex
}
destroy(){
    depname=$1
    namespace=$2
    log_info "Destroying $depname resources inside $namespace namespace"
    if [ $depname == 'memcached' ];
    then
        return
    fi
    oc delete statefulsets -n $namespace -l app.kubernetes.io/name=$depname 1> /dev/null
    oc delete deployment -n $namespace -l app.kubernetes.io/name=$depname 1> /dev/null
    oc delete pvc -n $namespace --all=true 1> /dev/null
    sleep 30
}
teardown(){
    log_info "Teardown started"
    oc delete ns minio dex observatorium observatorium-metrics telemeter 1> /dev/null
}
observatorium_metrics(){
    log_info "Deploying resources inside observatorium-metrics namespace"
    oc create ns observatorium-metrics 1> /dev/null
    sleep 5
    oc process -f observatorium-metrics-thanos-objectstorage-secret-template.yaml | oc apply --namespace observatorium-metrics -f - 1> /dev/null
    oc process --param-file=observatorium-metrics.ci.env -f ../resources/services/observatorium-metrics-template.yaml -o jsonpath='{.items[?(@.kind=="ConfigMap")]}' | oc apply --namespace observatorium-metrics -f - 1> /dev/null
    oc apply -f observatorium-alertmanager-config-secret.yaml --namespace observatorium-metrics 1> /dev/null
    role
    comps=('thanos-compact' 'alertmanager' 'thanos-query' 'thanos-query-frontend' 'thanos-receive' 'thanos-rule' 'thanos-stateless-rule' 'memcached' 'thanos-store' 'thanos-volcano-query')
    for comp in ${comps[*]}
    do
        if [ $comp == 'thanos-receive' ];
        then
            oc process --param-file=observatorium-metrics.ci.env -f ../resources/services/observatorium-metrics-template.yaml -o jsonpath='{.items[?(@.kind=="PodDisruptionBudget")]}' | oc apply --namespace observatorium-metrics -f - 1> /dev/null
            oc process --param-file=observatorium-metrics.ci.env -f ../resources/services/observatorium-metrics-template.yaml | oc apply --namespace observatorium-metrics --selector=app.kubernetes.io/name=thanos-receive-controller -f - 1> /dev/null
        fi
        if [ $comp == 'alertmanager' ];
        then
            oc process --param-file=observatorium-metrics.ci.env -f ../resources/services/observatorium-metrics-template.yaml -o jsonpath='{.items[?(@.kind=="PersistentVolumeClaim")]}' | oc apply --namespace observatorium-metrics -f - 1> /dev/null
        fi
        oc process --param-file=observatorium-metrics.ci.env -f ../resources/services/observatorium-metrics-template.yaml | oc apply --namespace observatorium-metrics --selector=app.kubernetes.io/name=$comp -f - 1> /dev/null
        sleep 5
        pods=$(oc get pods -n observatorium-metrics -l app.kubernetes.io/name=$comp -o name)
        sleep 30
        for pod in $pods
        do
            check_pod_status $pod observatorium-metrics
        done
        log_info "Sleeping..."
        sleep 10
        destroy $comp observatorium-metrics
    done
}
observatorium(){
    log_info "Deploying resources inside observatorium namespace"
    oc create ns observatorium 1> /dev/null
    sleep 5
    oc apply -f observatorium-rules-objstore-secret.yaml --namespace observatorium 1> /dev/null
    oc apply -f observatorium-rhobs-tenant-secret.yaml --namespace observatorium 1> /dev/null
    comps=('avalanche-remote-writer' 'gubernator' 'memcached' 'observatorium-api' 'observatorium-up' 'rules-objstore' 'rules-obsctl-reloader')
    for comp in ${comps[*]}
    do
        oc process --param-file=observatorium.test.env -f ../resources/services/observatorium-template.yaml | oc apply --namespace observatorium --selector=app.kubernetes.io/name=$comp -f - 1> /dev/null
        sleep 5
        pods=$(oc get pods -n observatorium -l app.kubernetes.io/name=$comp -o name)
        sleep 30
        for pod in $pods
        do
            check_pod_status $pod observatorium
        done
        log_info "Sleeping..."
        sleep 10
        destroy $comp observatorium
    done

}
telemeter(){
    log_info "Deploying resources inside telemeter namespace"
    oc create ns telemeter 1> /dev/null
    sleep 5
    oc apply --namespace telemeter -f telemeter-token-refersher-oidc-secret.yaml 1> /dev/null
    comps=('memcached' 'nginx' 'memcached' 'token-refresher')
    for comp in ${comps[*]}
    do
        oc process --param-file=telemeter.test.env -f ../resources/services/telemeter-template.yaml | oc apply --namespace telemeter --selector=app.kubernetes.io/name=$comp -f - 1> /dev/null
        sleep 5
        pods=$(oc get pods -n telemeter -l app.kubernetes.io/name=$comp -o name)
        sleep 30
        for pod in $pods
        do
            check_pod_status $pod telemeter
        done
        log_info "Sleeping..."
        sleep 10
        destroy $comp telemeter
    done
}
crds
minio
dex
observatorium_metrics
observatorium
telemeter
teardown
