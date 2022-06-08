#!/bin/bash

set -e
set -o pipefail

# Authenticaton related vars
export OIDC_URL=${OIDC_URL:-https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token}
export CLIENT_ID=${CLIENT_ID:-client_id}
export CLIENT_SECRET=${CLIENT_SECRET:-client_secret}

# Up configuration vars
export TENANT=${TENANT:-rhobs}
export OBSERVATORIUM_API_URL=${OBSERVATORIUM_API_URL:-https://observatorium.api}
export LOG_LEVEL=${LOG_LEVEL:-info}
export METRIC_NAME=${METRIC_NAME:-rhobs_e2e}
export METRIC_LABELS=${METRIC_LABELS:-_id=\"test\"}

# Up run parameters
export UP_DURATION=${UP_DURATION:-30s}
export UP_INITIAL_DELAY=${UP_INITIAL_DELAY:-5s}

export TOKEN=$(curl \
    --fail-with-body \
    --request POST  \
    --url ${OIDC_URL} \
    --header 'content-type: application/x-www-form-urlencoded' \
    --data grant_type=client_credentials --data client_id=${CLIENT_ID} \
    --data client_secret=${CLIENT_SECRET} | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
    echo "Failed to obtain the bearer token"; exit 1;
fi

up --endpoint-type=metrics \
    --endpoint-read=${OBSERVATORIUM_API_URL}/api/metrics/v1/${TENANT} \
	--endpoint-write=${OBSERVATORIUM_API_URL}/api/metrics/v1/${TENANT}/api/v1/receive \
    --token=${TOKEN} \
	--log.level=${LOG_LEVEL} \
	--name=${METRIC_NAME} \
	--labels=${METRIC_LABELS} \
    --duration=${UP_DURATION} \
    --initial-query-delay=${UP_INITIAL_DELAY}

