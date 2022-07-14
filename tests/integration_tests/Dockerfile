FROM quay.io/observatorium/up:master-2022-07-13-7f0630b

RUN apk update &&\
    apk add curl jq

COPY ./tests/integration_tests/runtest.sh /tests/runtest.sh

WORKDIR /tests
ENTRYPOINT ["/bin/sh", "runtest.sh"]