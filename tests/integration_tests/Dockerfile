# This is a workaround since `up` images are now built with scratch,
# meaning we cannot execture other commands. This copies `up` binary
# and runs the tests in an Alpine-based container.
FROM quay.io/observatorium/up:master-2022-07-13-7f0630b as source

FROM alpine

COPY --from=source /usr/bin/up /usr/bin/up

RUN apk update &&\
    apk add curl jq

COPY ./tests/integration_tests/runtest.sh /tests/runtest.sh

WORKDIR /tests
ENTRYPOINT ["/bin/sh", "runtest.sh"]