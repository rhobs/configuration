.PHONY: all
all: $(VENDOR_DIR) prometheusrules grafana manifests whitelisted_metrics

include .bingo/Variables.mk

VENDOR_DIR = vendor
$(VENDOR_DIR): $(JB) jsonnetfile.json jsonnetfile.lock.json
	@$(JB) install

JSONNET_SRC = $(shell find . -type f -not -path './*vendor/*' \( -name '*.libsonnet' -o -name '*.jsonnet' \))

.PHONY: format
format: $(JSONNET_SRC) $(JSONNETFMT)
	@echo ">>>>> Running format"
	$(JSONNETFMT) -n 2 --max-blank-lines 2 --string-style s --comment-style s -i $(JSONNET_SRC)

.PHONY: lint
lint: format $(JSONNET_SRC) $(JSONNET_LINT)
	@echo ">>>>> Running linter"
	find . -type f -not -path './*vendor/*' -name '*.libsonnet' -o -name '*.jsonnet' -exec $(JSONNET_LINT) -J vendor {} \;

.PHONY: prometheusrules
prometheusrules: resources/observability/prometheusrules

resources/observability/prometheusrules: format observability/prometheusrules.jsonnet $(JSONNET) $(GOJSONTOYAML)
	@echo ">>>>> Running prometheusrules"
	rm -f resources/observability/prometheusrules/*.yaml
	$(JSONNET) -J vendor -m resources/observability/prometheusrules observability/prometheusrules.jsonnet | xargs -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	find resources/observability/prometheusrules -type f ! -name '*.yaml' -delete
	find resources/observability/prometheusrules/*.yaml | xargs -I{} sh -c 'sed -i "1s;^;---\n\$$schema: /openshift/prometheus-rule-1.yml\n;" {}'


.PHONY: grafana
grafana: resources/observability/grafana/observatorium resources/observability/grafana/observatorium-logs $(VENDOR_DIR)

resources/observability/grafana/observatorium: format observability/grafana.jsonnet $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running grafana"
	rm -f resources/observability/grafana/observatorium/*.yaml
	$(JSONNET) -J vendor -m resources/observability/grafana/observatorium observability/grafana.jsonnet | xargs -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	find resources/observability/grafana/observatorium -type f ! -name '*.yaml' -delete

resources/observability/grafana/observatorium-logs: format observability/grafana-obs-logs.jsonnet $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running grafana observatorium-logs"
	rm -f resources/observability/grafana/observatorium-logs/*.yaml
	$(JSONNET) -J vendor observability/grafana-obs-logs.jsonnet | $(GOJSONTOYAML) > resources/observability/grafana/observatorium-logs/grafana-dashboards-template.yaml
	find resources/observability/grafana/observatorium-logs -type f ! -name '*.yaml' -delete

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
manifests: format resources/templates/conprof-template.yaml resources/templates/jaeger-template.yaml resources/templates/observatorium-template.yaml $(VENDOR_DIR)

resources/templates/conprof-template.yaml: $(shell find manifests -type f) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running conprof-template"
	$(JSONNET) -J vendor -m resources/templates manifests/conprof.jsonnet | xargs -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}

resources/templates/jaeger-template.yaml: $(shell find manifests -type f) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running jaeger-template"
	$(JSONNET) -J vendor manifests/jaeger.jsonnet | $(GOJSONTOYAML) > resources/templates/jaeger-template.yaml

resources/templates/observatorium-template.yaml: $(shell find manifests -type f) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running observatorium templates"
	$(JSONNET) -J vendor -m resources/templates manifests/main.jsonnet | xargs -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	find resources/templates -type f ! -name '*.yaml' -delete
