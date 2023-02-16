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

observatorium_metrics() {
    oc create ns observatorium-metrics || true
    oc process -f observatorium-metrics-thanos-objectstorage-secret-template.yaml | oc apply --namespace observatorium-metrics -f -
    role
    oc process --param-file=observatorium-metrics.test.env -f ../resources/services/observatorium-metrics-template.yaml | oc apply --namespace observatorium-metrics -f -
}

observatorium() {
    oc create ns observatorium || true
    oc process --param-file=observatorium.test.env -f ../resources/services/observatorium-template.yaml | oc apply --namespace observatorium -f -
}

telemeter() {
    oc create ns telemeter || true
    oc apply --namespace telemeter -f telemeter-token-refersher-oidc-secret.yaml
    oc process --param-file=telemeter.test.env -f ../resources/services/telemeter-template.yaml | oc apply --namespace telemeter -f -
}
loki_crds(){
    oc create -f https://raw.githubusercontent.com/grafana/loki/main/operator/config/crd/bases/loki.grafana.com_recordingrules.yaml
    oc create -f https://raw.githubusercontent.com/grafana/loki/main/operator/config/crd/bases/loki.grafana.com_alertingrules.yaml
}

teardown() {
    oc delete ns telemeter || true
    oc delete ns observatorium-metrics || true
    oc delete ns observatorium || true
    oc delete ns minio || true
    oc delete ns dex || true
    oc delete crds recordingrules.loki.grafana.com || true
    oc delete crds alertingrules.loki.grafana.com || true
}

case $1 in
deploy)
    minio
    dex
    loki_crds
    observatorium
    observatorium_metrics
    telemeter
    ;;
teardown)
    teardown
    ;;
esac

