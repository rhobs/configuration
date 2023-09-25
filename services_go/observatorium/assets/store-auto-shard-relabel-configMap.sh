#!/bin/bash

# Kubernetes replicas are named with the following convention "<statefulset-name>-<ordinal>". 
# This parameter expansion removes all characters until the last hyphen, capturing only the ordinal.
export ORDINAL_INDEX=${HOSTNAME##*-}

# Logging parameters
echo "generating store hashmod config with ORDINAL_INDEX=${ORDINAL_INDEX} THANOS_STORE_REPLICAS=${THANOS_STORE_REPLICAS} HOSTNAME=${HOSTNAME}"

cat <<EOF >/tmp/config/hashmod-config.yaml
- action: hashmod
    source_labels: ["__block_id"]
    target_label: shard
    modulus: ${THANOS_STORE_REPLICAS}
- action: keep
    source_labels: ["shard"]
    regex: ${ORDINAL_INDEX}
EOF
