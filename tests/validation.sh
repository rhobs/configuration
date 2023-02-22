#!/bin/bash

set -e
set -o pipefail

minio(){
    # Check status of minio namespace
    namespace='minio'
    phase=$(oc get $(oc get pods -n $namespace -l app.kubernetes.io/name=minio -o name) -n $namespace -o=jsonpath='{.status.phase}')
    status=$(oc get $(oc get pods -n $namespace -l app.kubernetes.io/name=minio -o name) -n $namespace -o=jsonpath="{.status.conditions[*].status}")
    if [[ $phase != 'Running' || $status == *'False'* ]];
    then
        msg=$(oc get $(oc get pods -n $namespace -l app.kubernetes.io/name=minio -o name) -n $namespace -o=jsonpath='{.status.containerStatuses[*]}')
        echo "Status of minio pod: $status"
        echo "Reason: $msg"
        exit 1
    else
        echo "Status of minio pod is healthy in $namespace namespace"
    fi
}
dex(){
    # Check status of dex namespace
    namespace='dex'
    phase=$(oc get $(oc get pods -n $namespace -l app.kubernetes.io/name=dex -o name) -n $namespace -o=jsonpath='{.status.phase}')
    status=$(oc get $(oc get pods -n $namespace -l app.kubernetes.io/name=dex -o name) -n $namespace -o=jsonpath="{.status.conditions[*].status}")
    if [[ $phase != 'Running' ||  $status == *'False'* ]];
    then
        msg=$(oc get $(oc get pods -n $namespace -l app.kubernetes.io/name=dex -o name) -n $namespace -o=jsonpath='{.status.containerStatuses[*]}')
        echo "Status of dex pod: $status"
        echo "Reason: $msg"
        exit 1
    else
        echo "Status of dex pod is healthy in $namespace namespace"
    fi
}
observatorium_metrics(){
    # Check status of observatorium_metrics namespace
    namespace='observatorium-metrics'
    comps=('thanos-compact' 'alertmanager' 'thanos-query' 'thanos-query-frontend' 'memcached' 'thanos-receive-controller' 'thanos-receive' 'thanos-rule' 'thanos-stateless-rule' 'memcached' 'thanos-store' 'thanos-volcano-query')
    for comp in ${comps[*]}
    do
        pods=$(oc get pods -n $namespace -l app.kubernetes.io/name=$comp -o name)
        for pod in $pods
        do
            phase=$(oc get $pod -n $namespace -o=jsonpath='{.status.phase}')
            status=$(oc get $pod -n $namespace -o=jsonpath="{.status.conditions[*].status}")
            if [[ $phase != 'Running' ||  $status == *'False'* ]];
            then
                msg=$(oc get $pod -n $namespace -o=jsonpath='{.status}')
                echo "Status of $pod: $status"
                echo "Reason: $msg"
                exit 1
            else
                echo "Status of $pod is healthy in $namespace namespace"
            fi
        done
    done
}
observatorium(){
    # Check status of observatorium namespace
    namespace='observatorium'
    comps=('avalanche-remote-writer' 'gubernator' 'memcached' 'observatorium-api' 'observatorium-up' 'rules-objstore' 'rules-obsctl-reloader')
    for comp in ${comps[*]}
    do
        pods=$(oc get pods -n $namespace -l app.kubernetes.io/name=$comp -o name)
        for pod in $pods
        do
            phase=$(oc get $pod -n $namespace -o=jsonpath='{.status.phase}')
            status=$(oc get $pod -n $namespace -o=jsonpath="{.status.conditions[*].status}")
            if [[ $phase != 'Running' ||  $status == *'False'* ]];
            then
                msg=$(oc get $pod -n $namespace -o=jsonpath='{.status}')
                echo "Status of $pod: $status"
                echo "Reason: $msg"
                exit 1
            else
                echo "Status of $pod is healthy in $namespace namespace"
            fi
        done
    done
}
telemeter(){
    # Check status of telemeter namespace
    namespace='telemeter'
    comps=('memcached' 'nginx' 'memcached' 'token-refresher')
    for comp in ${comps[*]}
    do
        pods=$(oc get pods -n $namespace -l app.kubernetes.io/name=$comp -o name)
        for pod in $pods
        do
            phase=$(oc get $pod -n $namespace -o=jsonpath='{.status.phase}')
            status=$(oc get $pod -n $namespace -o=jsonpath="{.status.conditions[*].status}")
            if [[ $phase != 'Running' ||  $status == *'False'* ]];
            then
                msg=$(oc get $pod -n $namespace -o=jsonpath='{.status}')
                echo "Status of $pod: $status"
                echo "Reason: $msg"
                exit 1
            else
                echo "Status of $pod is healthy in $namespace namespace"
            fi
        done
    done
}
minio
dex
observatorium_metrics
observatorium
telemeter