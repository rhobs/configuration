include .bingo/Variables.mk

SED ?= $(shell which gsed 2>/dev/null || which sed)
XARGS ?= $(shell which gxargs 2>/dev/null || which xargs)
FILES_TO_FMT ?= $(shell find . -path './vendor*' -not -prune -o -name '*.go' -print)

CRD_DIR := $(shell pwd)/crds
TMP_DIR := $(shell pwd)/tmp
BIN_DIR ?= $(TMP_DIR)/bin
OS ?= $(shell uname -s | tr '[A-Z]' '[a-z]')
OC_VERSION ?= latest
OC ?= $(BIN_DIR)/oc

JSONNET_SRC = $(shell find . -type f -not -path './*vendor_jsonnet/*' \( -name '*.libsonnet' -o -name '*.jsonnet' \))
# Given we have Go module in the root of repo we need to have custom dir for jsonnet vendor.
JSONNET_VENDOR_DIR = vendor_jsonnet

.PHONY: all
all: $(JSONNET_VENDOR_DIR) prometheusrules grafana manifests whitelisted_metrics

$(JSONNET_VENDOR_DIR): $(JB) jsonnetfile.json jsonnetfile.lock.json
	@$(JB) install --jsonnetpkg-home="$(JSONNET_VENDOR_DIR)"
	@echo "module fake // Required for repo-wide go.mod to work with JB that pulls unnecessary go code!" > $(JSONNET_VENDOR_DIR)/go.mod

.PHONY: update
update: $(JB) jsonnetfile.json jsonnetfile.lock.json
	@$(JB) update --jsonnetpkg-home="$(JSONNET_VENDOR_DIR)" https://github.com/observatorium/api/jsonnet/lib@main

.PHONY: format
format: $(JSONNET_SRC) $(JSONNETFMT) go-format
	@echo ">>>>> Running format"
	$(JSONNETFMT) -n 2 --max-blank-lines 2 --string-style s --comment-style s -i $(JSONNET_SRC)

.PHONY: lint
lint: $(JSONNET_LINT) $(JSONNET_VENDOR_DIR) go-lint
	@echo ">>>>> Running linter"
	echo ${JSONNET_SRC} | $(XARGS) -n 1 -- $(JSONNET_LINT) -J "$(JSONNET_VENDOR_DIR)"

.PHONY: go-lint
go-lint: ## Runs various static analysis against our code.
go-lint: $(FAILLINT) $(GOLANGCI_LINT) go-format go-deps
	@echo ">> verifying modules being imported"
	@$(FAILLINT) -paths "fmt.{Print,Printf,Println},io/ioutil.{Discard,NopCloser,ReadAll,ReadDir,ReadFile,TempDir,TempFile,Writefile}" -ignore-tests ./...
	@echo ">> examining all of the Go files"
	@go vet -stdmethods=false ./...
	@echo ">> linting all of the Go files GOGC=${GOGC}"
	@$(GOLANGCI_LINT) run

.PHONY: go-deps
go-deps: go.mod go.sum
	go mod tidy
	go mod download
	go mod verify

.PHONY: go-format
go-format: ## Formats Go code.
go-format: $(GOIMPORTS) $(GOLANGCI_LINT)
	@echo ">> formatting code"
	@gofmt -s -w $(FILES_TO_FMT)
	@$(GOIMPORTS) -w $(FILES_TO_FMT)

.PHONY: validate
validate: $(OC)
	@echo ">>>>> Validating OpenShift Templates"
	find . -type f \( -name '*template.yaml' \) | $(XARGS) -I{} $(OC) process -f {} --local -o yaml > /dev/null

.PHONE: sync-crds
sync-crds: $(YQ) $(GOJQ)
	@curl https://raw.githubusercontent.com/grafana/loki/main/operator/bundle/community/manifests/loki.grafana.com_alertingrules.yaml | $(YQ) eval -j > $(CRD_DIR)/loki.grafana.com_alertingrules.libsonnet
	@curl https://raw.githubusercontent.com/grafana/loki/main/operator/bundle/community/manifests/loki.grafana.com_recordingrules.yaml | $(YQ) eval -j > $(CRD_DIR)/loki.grafana.com_recordingrules.libsonnet
	$(MAKE) format

.PHONY: prometheusrules
prometheusrules: resources/observability/prometheusrules
	$(MAKE) clean
	yes | cp -r observability/prometheus_rule_tests/* resources/observability/prometheusrules/

resources/observability/prometheusrules: format observability/prometheusrules.jsonnet $(JSONNET) $(GOJSONTOYAML)
	@echo ">>>>> Running prometheusrules"
	rm -f resources/observability/prometheusrules/*.yaml
	$(JSONNET) -J "$(JSONNET_VENDOR_DIR)" -m resources/observability/prometheusrules observability/prometheusrules.jsonnet | $(XARGS) -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	find resources/observability/prometheusrules/*.yaml | $(XARGS) -I{} sh -c '$(SED) -i "1s;^;---\n\$$schema: /openshift/prometheus-rule-1.yml\n;" {}'
	$(MAKE) mimic

.PHONY: test-rules
test-rules: prometheusrules $(PROMTOOL) $(YQ) $(wildcard observability/prometheus_rule_tests/*.prometheusrulestests.yaml) $(wildcard resources/observability/prometheusrules/*.prometheusrules.yaml)
	find resources/observability/prometheusrules/ -type f -name *.prometheusrules.yaml | $(XARGS) -I{} sh -c 'cat {} | $(YQ) e ".spec" - > {}.test' -- {}
	$(PROMTOOL) check rules `find resources/observability/prometheusrules/ -type f -name *.test`
	$(PROMTOOL) test rules `find resources/observability/prometheusrules/ -type f -name *.prometheusrulestests.yaml`
	find resources/observability/prometheusrules -type f -name '*.test' -delete

.PHONY: grafana
grafana: resources/observability/grafana/observatorium resources/observability/grafana/observatorium-logs $(JSONNET_VENDOR_DIR)
	$(MAKE) clean

resources/observability/grafana/observatorium: format observability/grafana.jsonnet $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running grafana observatorium"
	rm -f resources/observability/grafana/observatorium/*.yaml
	$(JSONNET) -J "$(JSONNET_VENDOR_DIR)" -m resources/observability/grafana/observatorium observability/grafana.jsonnet | $(XARGS) -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}

resources/observability/grafana/observatorium-logs: format observability/grafana-obs-logs.jsonnet $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running grafana observatorium-logs"
	rm -f resources/observability/grafana/observatorium-logs/*.yaml
	$(JSONNET) -J "$(JSONNET_VENDOR_DIR)" -m resources/observability/grafana/observatorium-logs observability/grafana-obs-logs.jsonnet | $(XARGS) -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}

.PHONY: whitelisted_metrics
whitelisted_metrics: $(GOJSONTOYAML) $(GOJQ)
	@echo ">>>>> Running whitelisted_metrics"
	# Download the latest metrics file to extract the new added metrics.
	# NOTE: Because old clusters could still send metrics the whitelisting is append only
	# (configuration/telemeter/metrics.json).
	curl -q https://raw.githubusercontent.com/openshift/cluster-monitoring-operator/master/manifests/0000_50_cluster-monitoring-operator_04-config.yaml | \
		$(GOJSONTOYAML) -yamltojson | \
		$(GOJQ) -r '.data["metrics.yaml"]' | \
		$(GOJSONTOYAML) -yamltojson | \
		$(GOJQ) -r '.matches | sort' | \
		cat configuration/telemeter/metrics.json - | \
		$(GOJQ) -s '.[0] + .[1] | sort | unique' > /tmp/metrics.json
	cp /tmp/metrics.json configuration/telemeter/metrics.json

.PHONY: migrate-vendor
migrate-vendor:
	@# Remove old jsonnet vendor. If vendor is present Go module tools are confused (e.g Goland). It\'s not needed for normal operations.
	@rm -rf "./vendor"

.PHONY: manifests
manifests: migrate-vendor format $(JSONNET_VENDOR_DIR)
manifests: resources/services/telemeter-template.yaml resources/services/jaeger-template.yaml resources/services/parca-template.yaml tests/minio-template.yaml tests/dex-template.yaml
manifests: resources/services/observatorium-template.yaml resources/services/observatorium-metrics-template.yaml resources/services/observatorium-logs-template.yaml resources/services/observatorium-traces-subscriptions-template.yaml resources/services/observatorium-traces-template.yaml resources/crds/observatorium-logs-crds-template.yaml
manifests: resources/services/metric-federation-rule-template.yaml
	$(MAKE) clean

resources/services/parca-template.yaml: $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
resources/services/parca-template.yaml: $(wildcard services/parca-*)
	@echo ">>>>> Running parca-template"
	$(JSONNET) -J "$(JSONNET_VENDOR_DIR)" -m resources/services services/parca-template.jsonnet | $(XARGS) -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}

resources/services/jaeger-template.yaml: $(wildcard services/jaeger-*) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running jaeger-template"
	$(JSONNET) -J "$(JSONNET_VENDOR_DIR)" services/jaeger-template.jsonnet | $(GOJSONTOYAML) > $@

tests/minio-template.yaml: $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running minio-template"
	$(JSONNET) -J "$(JSONNET_VENDOR_DIR)" services/minio-template.jsonnet | $(GOJSONTOYAML) > $@

tests/dex-template.yaml: $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running dex-template"
	$(JSONNET) -J "$(JSONNET_VENDOR_DIR)" services/dex-template.jsonnet | $(GOJSONTOYAML) > $@

resources/services/telemeter-template.yaml: $(wildcard services/telemeter-*) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running telemeter templates"
	$(JSONNET) -J "$(JSONNET_VENDOR_DIR)" services/telemeter-template.jsonnet | $(GOJSONTOYAML) > $@

resources/services/observatorium-tenants-template.yaml: services/observatorium-tenants-template.jsonnet $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running observatorium mst tenants templates"
	$(JSONNET) -J vendor services/observatorium-tenants-template.jsonnet | $(GOJSONTOYAML) > $@

resources/services/observatorium-template.yaml: resources/.tmp/tenants/rbac.json services/observatorium.libsonnet services/observatorium-template.jsonnet $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running observatorium templates"
	$(JSONNET) -J "$(JSONNET_VENDOR_DIR)" services/observatorium-template.jsonnet | $(GOJSONTOYAML) > $@

resources/services/observatorium-metrics-template.yaml: $(wildcard services/observatorium-metrics-*) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running observatorium-metrics templates"
	$(JSONNET) -J "$(JSONNET_VENDOR_DIR)" services/observatorium-metrics-template.jsonnet | $(GOJSONTOYAML) > $@

resources/services/observatorium-logs-template.yaml: $(wildcard services/observatorium-logs-*) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running observatorium-logs templates"
	$(JSONNET) -J "$(JSONNET_VENDOR_DIR)" services/observatorium-logs-template.jsonnet | $(GOJSONTOYAML) > $@

resources/services/observatorium-traces-template.yaml: $(wildcard services/observatorium-traces-*) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running observatorium-traces templates"
	$(JSONNET) -J "$(JSONNET_VENDOR_DIR)" services/observatorium-traces-template.jsonnet | $(GOJSONTOYAML) > $@

resources/services/observatorium-traces-subscriptions-template.yaml: $(wildcard services/observatorium-traces-*) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running observatorium-traces-subscriptions templates"
	$(JSONNET) -J "$(JSONNET_VENDOR_DIR)" services/observatorium-traces-subscriptions-template.jsonnet | $(GOJSONTOYAML) > $@

resources/services/metric-federation-rule-template.yaml: $(wildcard services/metric-federation-rule*) $(wildcard configuration/observatorium/metric-federation-rule*) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running metric-federation-rule templates"
	$(JSONNET) -J "$(JSONNET_VENDOR_DIR)" services/metric-federation-rule-template.jsonnet | $(GOJSONTOYAML) > $@

resources/crds/observatorium-logs-crds-template.yaml: $(wildcard crds/loki*) sync-crds $(JSONNET) $(GOJSONTOYAML)
	@echo ">>>>> Running obsevatorium-logs-crds template"
	$(JSONNET) crds/observatorium-logs-crds-template.jsonnet | $(GOJSONTOYAML) > $@

.PHONY: clean
clean:
	find resources/crds -type f ! -name '*.yaml' -delete
	find resources/services -type f ! -name '*.yaml' -delete
	find resources/observability/prometheusrules -type f ! -name '*.yaml' -delete
	find resources/observability/grafana/observatorium -type f ! -name '*.yaml' -delete
	find resources/observability/grafana/observatorium-logs -type f ! -name '*.yaml' -delete
	find resources/services/telemeter-template.yaml -type f ! -name '*.yaml' -delete

resources/.tmp/tenants/rbac.json: configuration/observatorium/rbac.go
	$(MAKE) mimic

# Generate rbac and Pyrra-based Prometheus rules for SLO.
.PHONY: mimic
mimic:
	GOFLAGS="-mod=mod" go run ./mimic.go generate -o resources

# In theory we'd be able to run Pyrra as a CLI directly.
# PYRRA_DIR := $(shell pwd)/test
#
# .PHONY: docker-pyrra
# docker-pyrra:
# 	@chmod -R 777 $(PYRRA_DIR)
# 	docker run -v $(PYRRA_DIR):/shared -i ghcr.io/pyrra-dev/pyrra:main generate --config-files=/shared/pyrra/*.yaml --prometheus-folder=/shared/rules/ --generic-rules

# Tools
$(TMP_DIR):
	mkdir -p $(TMP_DIR)

$(BIN_DIR): $(TMP_DIR)
	mkdir -p $(BIN_DIR)

$(OC): $(BIN_DIR)
	@echo "Downloading OpenShift CLI"
	curl -sNL "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$(OC_VERSION)/openshift-client-$(OS).tar.gz" | tar -xzf - -C $(BIN_DIR)
