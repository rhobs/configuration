include .bingo/Variables.mk

SED ?= sed
XARGS ?= xargs

TMP_DIR := $(shell pwd)/tmp
BIN_DIR ?= $(TMP_DIR)/bin
OS ?= $(shell uname -s | tr '[A-Z]' '[a-z]')
OC_VERSION ?= 4.7.14
OC ?= $(BIN_DIR)/oc

.PHONY: all
all: $(VENDOR_DIR) prometheusrules grafana manifests whitelisted_metrics

VENDOR_DIR = vendor
$(VENDOR_DIR): $(JB) jsonnetfile.json jsonnetfile.lock.json
	@$(JB) install

JSONNET_SRC = $(shell find . -type f -not -path './*vendor/*' \( -name '*.libsonnet' -o -name '*.jsonnet' \))

.PHONY: format
format: $(JSONNET_SRC) $(JSONNETFMT)
	@echo ">>>>> Running format"
	$(JSONNETFMT) -n 2 --max-blank-lines 2 --string-style s --comment-style s -i $(JSONNET_SRC)

.PHONY: lint
lint: $(JSONNET_LINT) vendor
	@echo ">>>>> Running linter"
	echo ${JSONNET_SRC} | $(XARGS) -n 1 -- $(JSONNET_LINT) -J vendor

.PHONY: validate
validate: $(OC)
	@echo ">>>>> Validating OpenShift Templates"
	find . -type f \( -name '*template.yaml' \) | $(XARGS) -I{} $(OC) process -f {} --local -o yaml > /dev/null

.PHONY: prometheusrules
prometheusrules: resources/observability/prometheusrules
	$(MAKE) clean
	yes | cp -r observability/prometheus_rule_tests/* resources/observability/prometheusrules/

resources/observability/prometheusrules: format observability/prometheusrules.jsonnet $(JSONNET) $(GOJSONTOYAML)
	@echo ">>>>> Running prometheusrules"
	rm -f resources/observability/prometheusrules/*.yaml
	$(JSONNET) -J vendor -m resources/observability/prometheusrules observability/prometheusrules.jsonnet | $(XARGS) -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	find resources/observability/prometheusrules/*.yaml | $(XARGS) -I{} sh -c '$(SED) -i "1s;^;---\n\$$schema: /openshift/prometheus-rule-1.yml\n;" {}'

.PHONY: test-rules
test-rules: prometheusrules $(PROMTOOL) $(YQ) $(wildcard observability/prometheus_rule_tests/*.prometheusrulestests.yaml) $(wildcard resources/observability/prometheusrules/*.prometheusrules.yaml)
	find resources/observability/prometheusrules/ -type f -name *.prometheusrules.yaml | $(XARGS) -I{} sh -c 'cat {} | $(YQ) e ".spec" - > {}.test' -- {}
	$(PROMTOOL) check rules `find resources/observability/prometheusrules/ -type f -name *.test`
	$(PROMTOOL) test rules `find resources/observability/prometheusrules/ -type f -name *.prometheusrulestests.yaml`
	find resources/observability/prometheusrules -type f -name '*.test' -delete

.PHONY: grafana
grafana: resources/observability/grafana/observatorium resources/observability/grafana/observatorium-logs/grafana-dashboards-template.yaml $(VENDOR_DIR)
	$(MAKE) clean


resources/observability/grafana/observatorium: format observability/grafana.jsonnet $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running grafana"
	rm -f resources/observability/grafana/observatorium/*.yaml
	$(JSONNET) -J vendor -m resources/observability/grafana/observatorium observability/grafana.jsonnet | $(XARGS) -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}

resources/observability/grafana/observatorium-logs/grafana-dashboards-template.yaml: format observability/grafana.jsonnet $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running grafana"
	rm -f resources/observability/grafana/observatorium-logs/*.yaml
	$(JSONNET) -J vendor observability/grafana-obs-logs.jsonnet | $(GOJSONTOYAML) > $@

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

.PHONY: manifests
manifests: format $(VENDOR_DIR)
manifests: resources/services/telemeter-template.yaml resources/services/jaeger-template.yaml resources/services/conprof-template.yaml
manifests: resources/services/observatorium-template.yaml resources/services/observatorium-metrics-template.yaml resources/services/observatorium-logs-template.yaml
	$(MAKE) clean

resources/services/conprof-template.yaml: $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
resources/services/conprof-template.yaml: $(wildcard services/conprof-*)
	@echo ">>>>> Running conprof-template"
	$(JSONNET) -J vendor -m resources/services services/conprof-template.jsonnet | $(XARGS) -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}

resources/services/jaeger-template.yaml: $(wildcard services/jaeger-*) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running jaeger-template"
	$(JSONNET) -J vendor services/jaeger-template.jsonnet | $(GOJSONTOYAML) > $@

resources/services/telemeter-template.yaml: $(wildcard services/telemeter-*) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running telemeter templates"
	$(JSONNET) -J vendor services/telemeter-template.jsonnet | $(GOJSONTOYAML) > $@

resources/services/observatorium-template.yaml: services/observatorium.libsonnet services/observatorium-template.jsonnet $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running observatorium templates"
	$(JSONNET) -J vendor services/observatorium-template.jsonnet | $(GOJSONTOYAML) > $@

resources/services/observatorium-metrics-template.yaml: $(wildcard services/observatorium-metrics-*) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running observatorium-metrics templates"
	$(JSONNET) -J vendor services/observatorium-metrics-template.jsonnet | $(GOJSONTOYAML) > $@

resources/services/observatorium-logs-template.yaml: $(wildcard services/observatorium-logs-*) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running observatorium-logs templates"
	$(JSONNET) -J vendor services/observatorium-logs-template.jsonnet | $(GOJSONTOYAML) > $@

.PHONY: clean
clean:
	find resources/services -type f ! -name '*.yaml' -delete
	find resources/observability/prometheusrules -type f ! -name '*.yaml' -delete
	find resources/observability/grafana/observatorium -type f ! -name '*.yaml' -delete
	find resources/observability/grafana/observatorium-logs -type f ! -name '*.yaml' -delete

# Tools
$(TMP_DIR):
	mkdir -p $(TMP_DIR)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(OC): $(BIN_DIR)
	@echo "Downloading OpenShift CLI"
	curl -sNL "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$(OC_VERSION)/openshift-client-$(OS).tar.gz" | tar -xzf - -C $(BIN_DIR)
