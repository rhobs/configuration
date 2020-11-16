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

.PHONY: prometheusrules
prometheusrules: resources/observability/prometheusrules

resources/observability/prometheusrules: format prometheusrules.jsonnet $(JSONNET) $(GOJSONTOYAML)
	@echo ">>>>> Running prometheusrules"
	rm -f resources/observability/prometheusrules/*.yaml
	$(JSONNET) -J vendor -m resources/observability/prometheusrules prometheusrules.jsonnet | xargs -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	find resources/observability/prometheusrules -type f ! -name '*.yaml' -delete
	find resources/observability/prometheusrules/*.yaml | xargs -I{} sh -c 'sed -i "1s;^;---\n\$$schema: /openshift/prometheus-rule-1.yml\n;" {}'


.PHONY: grafana
grafana: manifests/production/grafana/observatorium manifests/production/grafana/observatorium-logs

manifests/production/grafana/observatorium: format environments/production/grafana.jsonnet $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running grafana"
	rm -f manifests/production/grafana/observatorium/*.yaml
	$(JSONNET) -J vendor -m manifests/production/grafana/observatorium environments/production/grafana.jsonnet | xargs -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	find manifests/production/grafana/observatorium -type f ! -name '*.yaml' -delete

manifests/production/grafana/observatorium-logs: format environments/production/grafana-obs-logs.jsonnet $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running grafana observatorium-logs"
	rm -f manifests/production/grafana/observatorium-logs/*.yaml
	$(JSONNET) -J vendor -m manifests/production/grafana/observatorium-logs environments/production/grafana-obs-logs.jsonnet | xargs -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	find manifests/production/grafana/observatorium-logs -type f ! -name '*.yaml' -delete

.PHONY: whitelisted_metrics
whitelisted_metrics: $(GOJSONTOYAML) $(GOJQ)
	@echo ">>>>> Running whitelisted_metrics"
	# Download the latest metrics file to extract the new added metrics.
	# NOTE: Because old clusters could still send metrics the whitelisting is append only
	# (environments/production/metrics.json).
	curl -q https://raw.githubusercontent.com/openshift/cluster-monitoring-operator/master/manifests/0000_50_cluster-monitoring-operator_04-config.yaml | \
		$(GOJSONTOYAML) -yamltojson | \
		$(GOJQ) -r '.data["metrics.yaml"]' | \
		$(GOJSONTOYAML) -yamltojson | \
		$(GOJQ) -r '.matches | sort' | \
		cat environments/production/metrics.json - | \
		$(GOJQ) -s '.[0] + .[1] | sort | unique' > /tmp/metrics.json
	cp /tmp/metrics.json environments/production/metrics.json

.PHONY: manifests
manifests: format $(VENDOR_DIR) manifests/production/conprof-template.yaml manifests/production/jaeger-template.yaml manifests/production/observatorium-template.yaml

manifests/production/conprof-template.yaml: $(shell find environments/production -type f) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running conprof-template"
	$(JSONNET) -J vendor environments/production/conprof.jsonnet | $(GOJSONTOYAML) > manifests/production/conprof-template.yaml

manifests/production/jaeger-template.yaml: $(shell find environments/production -type f) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running jaeger-template"
	$(JSONNET) -J vendor environments/production/jaeger.jsonnet | $(GOJSONTOYAML) > manifests/production/jaeger-template.yaml

manifests/production/observatorium-template.yaml: $(shell find environments/production -type f) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	@echo ">>>>> Running observatorium templates"
	$(JSONNET) -J vendor -m manifests/production environments/production/main.jsonnet  | xargs -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	find manifests/production -type f ! -name '*.yaml' -delete
