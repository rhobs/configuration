FROM golang:1.20-alpine
RUN apk update && apk add git

WORKDIR /integration-tests

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build ./cmd/rhobs-test
ENTRYPOINT [ "./rhobs-test" ]
