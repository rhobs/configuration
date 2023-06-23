# This is a script to spin up a test environment.

#!/bin/bash

set -e
set -o pipefail

role() {
    oc apply -f observatorium-cluster-role.yaml
    oc apply -f observatorium-cluster-role-binding.yaml
    oc apply --namespace observatorium-metrics -f observatorium-service-account.yaml
}

minio() {
    oc create ns minio || true
    oc process -f minio-template.yaml | oc apply --namespace minio -f -
}

dex() {
    oc create ns dex || true
    oc process -f dex-template.yaml | oc apply --namespace dex -f -
}

observatorium_tools(){
    oc apply -f loki-operator.yaml
    sleep 30 # wait till clusterserviceversion becomes available
    oc wait --for=jsonpath='{.status.phase}'=Succeeded $(oc get clusterserviceversion --namespace openshift-operators-redhat --output name | grep -E 'loki-operator.v5.6.*') --namespace openshift-operators-redhat --timeout=60s
    oc create ns observatorium-tools || true
    oc apply --namespace observatorium-tools -f observatorium-tools-network-policy.yaml
    oc process --param-file=logging.test.env -f ../resources/services/meta-monitoring/logging-template.yaml | oc apply --namespace observatorium-tools -f -
}

logging(){
    oc apply -f logging-operator.yaml
    sleep 30 # wait till clusterserviceversion becomes available
    oc wait --for=jsonpath='{.status.phase}'=Succeeded $(oc get clusterserviceversion --namespace openshift-logging --output name | grep -E 'cluster-logging.v5.6.*') --namespace openshift-logging --timeout=60s
    oc apply --namespace openshift-logging -f clusterlogging.yaml
    oc apply --namespace openshift-logging -f clusterlogforwader.yaml
}

observatorium_metrics() {
    oc create ns observatorium-metrics || true
    oc process -f observatorium-metrics-thanos-objectstorage-secret-template.yaml | oc apply --namespace observatorium-metrics -f -
    oc apply --namespace observatorium-metrics -f observatorium-alertmanager-config-secret.yaml
    role
    oc process --param-file=observatorium-metrics.test.env -f ../resources/services/observatorium-metrics-template.yaml | oc apply --namespace observatorium-metrics -f -
    oc process --param-file=observatorium-metric-federation-rule.test.env -f ../resources/services/metric-federation-rule-template.yaml | oc apply --namespace observatorium-metrics -f -
}

observatorium() {
    oc create ns observatorium || true
    oc apply -f observatorium-rules-objstore-secret.yaml --namespace observatorium
    oc apply -f observatorium-rhobs-tenant-secret.yaml --namespace observatorium
    oc apply --namespace observatorium -f observatorium-service-account.yaml
    oc apply -f observatorium-parca-secret.yaml --namespace observatorium
    rbac
    oc process --param-file=observatorium.test.env -f ../resources/services/observatorium-template.yaml | oc apply --namespace observatorium -f -
    oc process --param-file=observatorium-parca.test.env -f ../resources/services/parca-template.yaml | oc apply --namespace observatorium -f -
    oc process --param-file=observatorium-jaeger.test.env -f ../resources/services/jaeger-template.yaml | oc apply --namespace observatorium -f -
}

observatorium_logs(){
    oc create ns observatorium-logs || true
    oc apply --namespace observatorium-logs -f observatorium-logs-secret.yaml
    oc process --param-file=observatorium-logs.test.env -f ../resources/services/observatorium-logs-template.yaml | oc apply --namespace observatorium-logs -f -
}

telemeter() {
    oc create ns telemeter || true
    oc apply --namespace telemeter -f telemeter-token-refersher-oidc-secret.yaml
    oc process --param-file=telemeter.test.env -f ../resources/services/telemeter-template.yaml | oc apply --namespace telemeter -f -
}

rhelemeter() {
    oc create ns rhelemeter || true
    oc process --param-file=rhelemeter.test.env -f ../resources/services/rhelemeter-template.yaml | oc apply --namespace rhelemeter -f -
}

teardown() {
    oc delete ns telemeter || true
    oc delete ns rhelemeter || true
    oc delete ns observatorium-metrics || true
    oc delete ns observatorium || true
    oc delete ns minio || true
    oc delete ns dex || true
    oc delete ns observatorium-logs || true
    oc delete ns observatorium-mst || true
    oc delete ns observatorium-tools || true
    oc delete ns openshift-logging || true
    oc delete ns openshift-operators-redhat || true
}

rbac(){
    # The below namespaces are just created for parca-observatorium-remote-ns-rbac-template. These can be removed once logging/tracing is deployed
    oc create ns observatorium-mst || true
    oc process -f ../resources/services/parca-observatorium-remote-ns-rbac-template.yaml | oc apply -f -
}
case $1 in
deploy)
    minio
    dex
    observatorium_tools
    observatorium_metrics
    telemeter
    rhelemeter
    observatorium_logs
    observatorium
    logging
    ;;
teardown)
    teardown
    ;;
esac

