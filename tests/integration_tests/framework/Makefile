include .bingo/Variables.mk

IMG ?= quay.io/app-sre/rhobs-test
BRANCH := $(strip $(shell git rev-parse --abbrev-ref HEAD))
BUILD_DATE :=$(shell date -u +"%Y-%m-%d")
TAG := $(shell git rev-parse --short=7 HEAD)
EXAMPLES := examples
OCP_MANIFESTS := $(EXAMPLES)/manifests/openshift
DEV_MANIFESTS := $(EXAMPLES)/manifests/dev
XARGS ?= $(shell which gxargs 2>/dev/null || which xargs)
all: build
build: rhobs-test

.PHONY: rhobs-test
rhobs-test:
	CGO_ENABLED=0 go build ./cmd/rhobs-test

.PHONY: vendor
vendor: go.mod go.sum
		go mod tidy
		go mod vendor
.PHONY: go-fmt
go-fmt:
	@fmt_res=$$(gofmt -d -s $$(find . -type f -name '*.go' -not -path './vendor/*')); if [ -n "$$fmt_res" ]; then printf '\nGofmt found style issues. Please check the reported issues\nand fix them if necessary before submitting the code for review:\n\n%s' "$$fmt_res"; exit 1; fi

.PHONY: container-dev
container-dev: kind
	@docker build \
		-f ../../../Dockerfile \
		-t $(IMG):$(BRANCH)-$(BUILD_DATE)-$(TAG) \
		../../../
	docker tag $(IMG):$(BRANCH)-$(BUILD_DATE)-$(TAG) localhost:5001/rhobs-test:latest
	docker push localhost:5001/rhobs-test:latest

.PHONY: kind
kind:
	wget https://kind.sigs.k8s.io/examples/kind-with-registry.sh
	chmod 755 kind-with-registry.sh
	./kind-with-registry.sh

.PHONY: test
test:
	go test ./...
	
.PHONY: local
local: kind container-dev
	kubectl apply -f $(DEV_MANIFESTS)/test-deployment.yaml
	kubectl apply -f $(DEV_MANIFESTS)/rbac.yaml
	kubectl apply -f $(DEV_MANIFESTS)/job.yaml

.PHONY: local-faulty
local-faulty: kind container-dev
	kubectl apply -f $(DEV_MANIFESTS)/test-deployment-faulty-template.yaml
	kubectl apply -f $(DEV_MANIFESTS)/rbac-template.yaml
	kubectl apply -f $(DEV_MANIFESTS)/job-template.yaml

.PHONY: clean
clean:
	find $(EXAMPLES) -type f ! -name '*.yaml' -delete
	find $(OCP_MANIFESTS) -type f ! -name '*.yaml' -delete
	find $(DEV_MANIFESTS) -type f ! -name '*.yaml' -delete

.PHONY: clean-local
clean-local:
	rm -f kind-with-registry.sh
	rm -f ./rhobs-test
	kind delete cluster
	docker ps -a -q | xargs docker rm -f

.PHONY: clean-test
clean-test:
	rm -f kind-with-registry.sh
	rm -f ./rhobs-test
	kind delete cluster
	docker ps -a -q | xargs docker rm -f
	rm -f kubeconfig

.PHONY: container-build
container-build:
	docker buildx build \
		-f ../../../Dockerfile \
		--platform linux/amd64,linux/arm64 \
		--build-arg DOCKERFILE_PATH="/Dockerfile" \
		-t $(IMG):$(BRANCH)-$(BUILD_DATE)-$(TAG) \
		-t $(IMG):$(TAG) \
		../../../
.PHONY: container-build-push
container-build-push:
	@docker buildx build \
		-f ../../../Dockerfile \
		--push \
		--platform linux/amd64,linux/arm64 \
		-t $(IMG):$(BRANCH)-$(BUILD_DATE)-$(TAG) \
		-t $(IMG):$(TAG) \
		../../../
.PHONY: ocp-manifests
ocp-manifests: $(JSONNET) $(JSONNETFMT) $(GOJSONTOYAML)
	echo "ocp manifests"
	$(JSONNETFMT) -n 2 --max-blank-lines 2 --string-style s --comment-style s -i jsonnet/ocp-manifests.jsonnet
	$(JSONNET) -m $(OCP_MANIFESTS) jsonnet/ocp-manifests.jsonnet | $(XARGS) -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	make clean
.PHONY: dev-manifests

dev-manifests: $(JSONNET) $(JSONNETFMT) $(GOJSONTOYAML)
	echo "dev manifests"
	$(JSONNETFMT) -n 2 --max-blank-lines 2 --string-style s --comment-style s -i jsonnet/dev-manifests.jsonnet
	$(JSONNET) -m $(DEV_MANIFESTS) jsonnet/dev-manifests.jsonnet | $(XARGS) -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	make clean

.PHONY: manifests
manifests: dev-manifests ocp-manifests
