include .bingo/Variables.mk

SED ?= sed
XARGS ?= xargs

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

.PHONY: prometheusrules
prometheusrules: resources/observability/prometheusrules

resources/observability/prometheusrules: format observability/prometheusrules.jsonnet $(JSONNET) $(GOJSONTOYAML)
	@echo ">>>>> Running prometheusrules"
	rm -f resources/observability/prometheusrules/*.yaml
	$(JSONNET) -J vendor -m resources/observability/prometheusrules observability/prometheusrules.jsonnet | $(XARGS) -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	find resources/observability/prometheusrules -type f ! -name '*.yaml' -delete
	find resources/observability/prometheusrules/*.yaml | $(XARGS) -I{} sh -c '$(SED) -i "1s;^;---\n\$$schema: /openshift/prometheus-rule-1.yml\n;" {}'


# TODO(kakkoyun): resources/observability/grafana
.PHONY: grafana
grafana: manifests/production/grafana/observatorium manifests/production/grafana/observatorium-logs $(VENDOR_DIR)

manifests/production/grafana/observatorium: format observability/grafana.jsonnet $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running grafana"
	rm -f manifests/production/grafana/observatorium/*.yaml
	$(JSONNET) -J vendor -m manifests/production/grafana/observatorium observability/grafana.jsonnet | $(XARGS) -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	find manifests/production/grafana/observatorium -type f ! -name '*.yaml' -delete

manifests/production/grafana/observatorium-logs: format observability/grafana-obs-logs.jsonnet $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running grafana observatorium-logs"
	rm -f manifests/production/grafana/observatorium-logs/*.yaml
	$(JSONNET) -J vendor observability/grafana-obs-logs.jsonnet | $(GOJSONTOYAML) > manifests/production/grafana/observatorium-logs/grafana-dashboards-template.yaml
	find manifests/production/grafana/observatorium-logs -type f ! -name '*.yaml' -delete

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

# TODO(kakkoyun): resources/templates
.PHONY: manifests
manifests: format manifests/production/conprof-template.yaml manifests/production/jaeger-template.yaml manifests/production/observatorium-template.yaml # $(VENDOR_DIR)

manifests/production/conprof-template.yaml: $(shell find manifests -type f) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running conprof-template"
	$(JSONNET) -J vendor -m manifests/production manifests/conprof.jsonnet | $(XARGS) -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	find manifests/production -type f ! -name '*.yaml' -delete

manifests/production/jaeger-template.yaml: $(shell find manifests -type f) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running jaeger-template"
	$(JSONNET) -J vendor manifests/jaeger.jsonnet | $(GOJSONTOYAML) > manifests/production/jaeger-template.yaml

manifests/production/observatorium-template.yaml: $(shell find manifests -type f) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running observatorium templates"
	$(JSONNET) -J vendor -m manifests/production manifests/main.jsonnet 	| $(XARGS) -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	find manifests/production -type f ! -name '*.yaml' -delete
