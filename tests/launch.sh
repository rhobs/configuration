# This is a script to spin up a test environment.

#!/bin/bash

set -e
set -o pipefail

set_aws_credentials()
{
    echo "SetAWSCredential: AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY,AWS_DEFAULT_REGION,ENDPOINT"
    AWS_DEFAULT_REGION="${1:-us-east-2}"
    AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
    AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
    ENDPOINT="https://s3.${AWS_DEFAULT_REGION}.amazonaws.com"

    #use credentials in Env if AWS_ACCESS_KEY_ID and AWS_ACCESS_KEY_ID are not empty
    if [[ $AWS_ACCESS_KEY_ID == "" || ${AWS_SECRET_ACCESS_KEY} == "" ]]; then
        #use credentials in local as the second option
        if aws configure get region; then
            echo "SetAWSCredential: use credentials in local"
            AWS_ACCESS_KEY_ID="$(aws configure get aws_access_key_id)"
            AWS_SECRET_ACCESS_KEY="$(aws configure get aws_secret_access_key)"
        #use credentials stored in cluster as the third option
        elif oc get secret aws-creds -n kube-system;  then
            echo "SetAWSCredential: try credentials in kube-system/aws-creds"
            AWS_ACCESS_KEY_ID=$(oc get secret aws-creds -n kube-system -o json | jq -r '.data.aws_access_key_id'|base64 -d)
            AWS_SECRET_ACCESS_KEY=$(oc get secret  aws-creds -n kube-system -o json |jq -r '.data.aws_secret_access_key'|base64 -d)
        fi
    fi

    if [[ $AWS_ACCESS_KEY_ID == "" || ${AWS_SECRET_ACCESS_KEY} == "" ]]; then
        echo "SetAWSCredential: Error: AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
        exit 1
    fi
}

create_s3_bucket(){
    bucket_name=$1
    echo "CreateS3Bucket: ${bucket_name}"
    if ! aws configure get region; then
        echo "CreateS3Bucket: Warning: !!!! aws configure get region failed, please create the bucket ${bucket_name} manually"
        return 0
    fi
    aws s3api list-buckets |grep ${bucket_name}
    if [[ $? == 0 ]]  ;then
       echo "CreateS3Bucket: use existing bucketi ${bucket_name}"
    else
        aws s3api create-bucket --bucket $bucket_name --region $AWS_DEFAULT_REGION --create-bucket-configuration LocationConstraint=$AWS_DEFAULT_REGION
        if [[ $? == 0 ]]  ;then
           echo "CreateS3Bucket: created new bucket $bucket_name"
        else
            echo "CreateS3Bucket: Warning: !!!! create bucket $bucket_name failed, please create the bucket ${bucket_name} manually"
        fi
    fi
}

create_loki_secret() {
    secret_name=$1
    bucket_name=$2
    echo "CreateLokiSecret: secret $secret_name"
    oc create secret generic ${secret_name} \
        --from-literal=bucketnames="${bucket_name}" \
        --from-literal=endpoint="${ENDPOINT}" \
        --from-literal=region="${AWS_DEFAULT_REGION}" \
        --from-literal=access_key_id="${AWS_ACCESS_KEY_ID}" \
        --from-literal=access_key_secret="${AWS_SECRET_ACCESS_KEY}"
    if [[ $? == 0 ]]  ;then
        echo "CreateLokiSecret: Secret ${secret_name} created, endpoint=${ENDPOINT} bucket=${bucket_name}"
    fi
}

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
    oc apply -f observatorium-alertmanager-config-secret.yaml --namespace observatorium-metrics
    role
    oc process --param-file=observatorium-metrics.test.env -f ../resources/services/observatorium-metrics-template.yaml | oc apply --namespace observatorium-metrics -f -
}

observatorium() {
    oc create ns observatorium || true
    oc apply -f observatorium-rules-objstore-secret.yaml --namespace observatorium
    oc apply -f observatorium-rhobs-tenant-secret.yaml --namespace observatorium
    oc process --param-file=observatorium.test.env -f ../resources/services/observatorium-template.yaml | oc apply --namespace observatorium -f -
}

telemeter() {
    oc create ns telemeter || true
    oc apply --namespace telemeter -f telemeter-token-refersher-oidc-secret.yaml
    oc process --param-file=telemeter.test.env -f ../resources/services/telemeter-template.yaml | oc apply --namespace telemeter -f -
}

lokistack(){
    echo "deployLoki: in ${loki_namespace}"
    cluster_name=$(oc config view -o jsonpath='{range .clusters[*]}{"\n"}{.name}' |egrep -v ':|^$')
    app_domain=$(oc get ingresses.config/cluster -o jsonpath={.spec.domain})
    default_storage_class=$(oc get sc |grep '(default)' |awk '{print $1}')
    alertmanger_url="observatorium-alertmanager-mst.${app_domain}"
    #alertmanger_namespace="observatorium-mst-stage"

    set_aws_credentials
    oc project $loki_namespace >/dev/null 2>&1|| oc new-project $loki_namespace >/dev/null 2>&1

    loki_s3_secret="${cluster_name}-obs-logs-s3"
    loki_s3_bucket="${cluster_name}-obs-logs-s3"
    loki_rules_s3_secret="${cluster_name}-rules-obs-s3"
    loki_rules_s3_bucket="${cluster_name}-rules-obs-s3"
    if oc get secret $loki_s3_secret >/dev/null 2>&1; then
        echo "use existing secret $loki_s3_secret"
    else
        create_s3_bucket $loki_s3_bucket
	create_loki_secret $loki_s3_bucket $loki_s3_secret
    fi

    if oc get secret $loki_rules_s3_secret >/dev/null 2>&1 ; then
	    echo "use existing secret $loki_rules_s3_secret"
    else
        create_s3_bucket $loki_rules_s3_bucket
	create_loki_secret $loki_rules_s3_bucket $loki_rules_s3_secret
    fi

    oc process -f ../resources/crds/observatorium-logs-crds-template.yaml | oc apply -f -  
    oc process -f ../resources/services/observatorium-logs-template.yaml -p NAMESPACE=${loki_namespace} \
        -p ALERTMANAGER_EXTERNAL_URL=${alertmanger_url}  \
        -p LOKI_S3_SECRET=${loki_s3_secret}  \
        -p RULES_OBJSTORE_S3_SECRET=${loki_rules_s3_secret}  \
	-p STORAGE_CLASS=${default_storage_class} | oc apply -f -
}

teardown() {
    #oc delete ns telemeter || true
    #oc delete ns observatorium-metrics || true
    #oc delete ns observatorium || true
    #oc delete ns minio || true
    #oc delete ns dex || true
    oc delete ns ${loki_namespace} || true
}

###################Main################################
loki_namespace="observatorium-logs"
case $1 in
deploy)
    minio
    dex
    lokistack
    observatorium
    observatorium_metrics
    telemeter
    ;;
teardown)
    teardown
    ;;
*)
    echo "Please input parameter [ deploy | teardown ]"
    ;;
esac

