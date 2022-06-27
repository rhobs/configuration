FROM quay.io/observatorium/up:master-2022-03-31-2aa26e9

RUN apk update &&\
    apk add curl jq

COPY ./tests/integration_tests/runtest.sh /tests/runtest.sh

WORKDIR /tests
ENTRYPOINT ["/bin/sh", "runtest.sh"]