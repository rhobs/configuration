# This is a script to spin up a unique, self-contained test environment.

#!/bin/bash

set -e
set -o pipefail
set -x

NAME="${2:-rhobs-test}"

ns() {
  echo "Trying to create ${NAME} namespace"
  # Try to create namespace, best effort. For our long lived cluster, you need to create project manually.
  oc create ns ${NAME} || true
  oc project ${NAME}
}

role() {
  oc process -f cluster-roles-template.yaml NAME=${NAME} | oc apply -f -
  oc apply --namespace ${NAME} -f rhobs-service-account.yaml
}

minio() {
  oc process -f minio-template.yaml | oc apply --namespace ${NAME} -f -
  oc process -f minio-secret-template.yaml NAMESPACE=${NAME} MINIO_NAMESPACE=${NAME} | oc apply --namespace ${NAME} -f -
}

dex() {
  oc process -f dex-template.yaml NAMESPACE=${NAME} | oc apply --namespace ${NAME} -f -
}

observatorium_metrics() {
  role

  cat <<EOL > .observatorium-metrics.test.env
NAMESPACE=${NAME}
OBSERVATORIUM_NAMESPACE=${NAME}
NAMESPACES='["${NAME}"]'

SERVICE_ACCOUNT_NAME=rhobs
THANOS_S3_SECRET=thanos-s3
JAEGER_AGENT_IMAGE=jaegertracing/jaeger-agent

THANOS_QUERIER_REPLICAS=1
THANOS_QUERY_FRONTEND_REPLICAS=1
THANOS_RECEIVE_REPLICAS=1
THANOS_RULER_REPLICAS=1
THANOS_STORE_BUCKET_CACHE_REPLICAS=1
THANOS_STORE_INDEX_CACHE_REPLICAS=1
THANOS_STORE_REPLICAS=1

MEMCACHED_CPU_LIMIT=200m
MEMCACHED_CPU_REQUEST=100m
MEMCACHED_MEMORY_LIMIT=200Mi
MEMCACHED_MEMORY_REQUEST=100Mi
THANOS_COMPACTOR_MEMORY_LIMIT=200Mi
THANOS_COMPACTOR_MEMORY_REQUEST=100Mi
THANOS_QUERIER_CPU_LIMIT=200m
THANOS_QUERIER_CPU_REQUEST=100m
THANOS_QUERIER_MEMORY_LIMIT=200Mi
THANOS_QUERIER_MEMORY_REQUEST=100Mi
THANOS_QUERY_FRONTEND_CPU_LIMIT=200m
THANOS_QUERY_FRONTEND_CPU_REQUEST=100m
THANOS_QUERY_FRONTEND_MEMORY_LIMIT=200Mi
THANOS_QUERY_FRONTEND_MEMORY_REQUEST=100Mi
THANOS_RECEIVE_CPU_LIMIT=200m
THANOS_RECEIVE_CPU_REQUEST=100m
THANOS_RECEIVE_MEMORY_LIMIT=200Mi
THANOS_RECEIVE_MEMORY_REQUEST=100Mi
THANOS_RULER_CPU_LIMIT=200m
THANOS_RULER_CPU_REQUEST=100m
THANOS_RULER_MEMORY_LIMIT=200Mi
THANOS_RULER_MEMORY_REQUEST=100Mi
THANOS_STORE_CPU_LIMIT=200m
THANOS_STORE_CPU_REQUEST=100m
THANOS_STORE_MEMORY_LIMIT=200Mi
THANOS_STORE_MEMORY_REQUEST=100Mi
THANOS_STORE_BUCKET_CACHE_MEMCACHED_CPU_LIMIT=200m
THANOS_STORE_BUCKET_CACHE_MEMCACHED_CPU_REQUEST=100m
THANOS_STORE_BUCKET_CACHE_MEMCACHED_MEMORY_LIMIT=200Mi
THANOS_STORE_BUCKET_CACHE_MEMCACHED_MEMORY_REQUEST=100Mi
THANOS_STORE_INDEX_CACHE_MEMCACHED_CPU_LIMIT=200m
THANOS_STORE_INDEX_CACHE_MEMCACHED_CPU_REQUEST=100m
THANOS_STORE_INDEX_CACHE_MEMCACHED_MEMORY_LIMIT=200Mi
THANOS_STORE_INDEX_CACHE_MEMCACHED_MEMORY_REQUEST=100Mi
EOL

  oc process --param-file=.observatorium-metrics.test.env -f ../resources/services/observatorium-metrics-template.yaml | \
  oc apply --namespace ${NAME} -f -
  oc apply --namespace ${NAME} -f alertmanager-config.yaml
}

observatorium() {
  cat <<EOL > .observatorium.test.env
NAMESPACE=${NAME}
OBSERVATORIUM_METRICS_NAMESPACE=${NAME}
OBSERVATORIUM_LOGS_NAMESPACE=${NAME}
NAMESPACES='["${NAME}"]'

SERVICE_ACCOUNT_NAME=default
JAEGER_AGENT_IMAGE=jaegertracing/jaeger-agent
GUBERNATOR_IMAGE=thrawn01/gubernator

GUBERNATOR_REPLICAS=1
OBSERVATORIUM_API_REPLICAS=1
OBSERVATORIUM_API_CPU_LIMIT=100m
OBSERVATORIUM_API_MEMORY_LIMIT=100Mi
OBSERVATORIUM_API_MEMORY_REQUEST=100Mi
UP_CPU_LIMIT=100m
UP_MEMORY_REQUEST=100Mi
UP_MEMORY_LIMIT=100Mi
TEST_DEX_NAMESPACE=${NAME}
EOL

  oc process --param-file=.observatorium.test.env -f ../resources/services/observatorium-template.yaml | oc apply --namespace ${NAME} -f -
}

telemeter() {
  cat <<EOL > .telemeter.test.env
NAMESPACE=${NAME}
OBSERVATORIUM_NAMESPACE=${NAME}
OBSERVATORIUM_METRICS_NAMESPACE=${NAME}
NAMESPACES='["${NAME}"]'

SERVICE_ACCOUNT_NAME=default

MEMCACHED_CPU_LIMIT=1
REPLICAS=1
TELEMETER_SERVER_MEMORY_LIMIT=200Mi
TELEMETER_SERVER_MEMORY_REQUEST=100Mi
EOL

    oc apply --namespace ${NAME} -f telemeter-token-refersher-oidc-secret.yaml
    oc process --param-file=.telemeter.test.env -f ../resources/services/telemeter-template.yaml TELEMETER_FORWARD_URL=http://observatorium-observatorium-api.${NAME}.svc.cluster.local:8080/api/metrics/v1/telemeter/api/v1/receive | \
    oc apply --namespace ${NAME} -f -
}

teardown() {
    oc delete ns ${NAME} || true
}

case $1 in
deploy)
    ns
    minio
    dex
    observatorium
    observatorium_metrics
    #telemeter
    ;;
teardown)
    teardown
    ;;
esac

