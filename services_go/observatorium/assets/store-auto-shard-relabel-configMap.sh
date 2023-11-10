#!/bin/bash

# Kubernetes replicas are named with the following convention "<statefulset-name>-<ordinal>". 
# This parameter expansion removes all characters until the last hyphen, capturing only the ordinal.
export ORDINAL_INDEX=${HOSTNAME##*-}
# This parameter expansion removes all characters after the last hyphen, capturing only the statefulset name.
export STATEFULSET_NAME="${HOSTNAME%-*}"
export THANOS_STORE_REPLICAS=$(oc get statefulset ${STATEFULSET_NAME} -n ${NAMESPACE} -o=jsonpath='{.status.replicas}')

# Logging parameters
echo "generating store hashmod config with ORDINAL_INDEX=${ORDINAL_INDEX} THANOS_STORE_REPLICAS=${STATEFULSET_NAME} HOSTNAME=${HOSTNAME} NAMESPACE=${NAMESPACE} THANOS_STORE_REPLICAS=${THANOS_STORE_REPLICAS}"

cat <<EOF >/tmp/config/hashmod-config.yaml
- action: hashmod
  source_labels:
    - __block_id
  target_label: shard
  modulus: ${THANOS_STORE_REPLICAS}
- action: keep
  source_labels:
    - shard
  regex: ${ORDINAL_INDEX}
EOF
