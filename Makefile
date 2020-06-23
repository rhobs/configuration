include .bingo/Variables.mk

VENDOR_DIR = vendor
$(VENDOR_DIR): $(JB) jsonnetfile.json jsonnetfile.lock.json
	@$(JB) install

JSONNET_SRC = $(shell find . -type f -not -path './*vendor/*' \( -name '*.libsonnet' -o -name '*.jsonnet' \))

.PHONY: jsonnetfmt
jsonnetfmt: $(JSONNET_SRC) $(JSONNETFMT)
	$(JSONNETFMT) -n 2 --max-blank-lines 2 --string-style s --comment-style s -i $(JSONNET_SRC)

.PHONY: generate
generate: $(VENDOR_DIR) prometheusrules grafana manifests whitelisted_metrics # slos Disabled for now, dependency is broken.

.PHONY: prometheusrules
prometheusrules: resources/observability/prometheusrules

resources/observability/prometheusrules: prometheusrules.jsonnet $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	rm -f resources/observability/prometheusrules/*.yaml
	$(JSONNETFMT) -i prometheusrules.jsonnet
	$(JSONNET) -J vendor -m resources/observability/prometheusrules prometheusrules.jsonnet | xargs -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	find resources/observability/prometheusrules -type f ! -name '*.yaml' -delete
	find resources/observability/prometheusrules/*.yaml | xargs -I{} sh -c '/bin/echo -e "---\n\$$schema: /openshift/prometheus-rule-1.yml\n$$(cat {})" > {}'


.PHONY: grafana
grafana: resources/observability/grafana

resources/observability/grafana: grafana.jsonnet $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	rm -f resources/observability/grafana/*.yaml
	$(JSONNETFMT) -i grafana.jsonnet
	$(JSONNET) -J vendor -m resources/observability/grafana grafana.jsonnet | xargs -I{} sh -c 'cat {} | $(GOJSONTOYAML) > {}.yaml' -- {}
	find resources/observability/grafana -type f ! -name '*.yaml' -delete

.PHONY: slos
slos: resources/observability/slo/telemeter.slo.yaml

resources/observability/slo/telemeter.slo.yaml: slo.jsonnet $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	$(JSONNETFMT) -i slo.jsonnet
	$(JSONNET) -J vendor slo.jsonnet | $(GOJSONTOYAML) > resources/observability/slo/telemeter.slo.yaml
	find resources/observability/slo/*.yaml | xargs -I{} sh -c '/bin/echo -e "---\n\$$schema: /openshift/prometheus-rule-1.yml\n$$(cat {})" > {}'

.PHONY: whitelisted_metrics
whitelisted_metrics: $(GOJSONTOYAML) $(GOJQ)
	# Download the latest metrics file to extract the new added metrics.
	# NOTE: Metric whitelisting should be only append on server side: (environments/production/metrics.json).
	# We want to be sure, we are fully compatible with old clusters as well. is append only.
	curl -q https://raw.githubusercontent.com/openshift/cluster-monitoring-operator/master/manifests/0000_50_cluster_monitoring_operator_04-config.yaml | \
		$(GOJSONTOYAML) -yamltojson | \
		$(GOJQ) -r '.data["metrics.yaml"]' | \
		$(GOJSONTOYAML) -yamltojson | \
		$(GOJQ) -r '.matches | sort' | \
		cat environments/production/metrics.json - | \
		$(GOJQ) -s '.[0] + .[1] | sort | unique' > /tmp/metrics.json
	cp /tmp/metrics.json environments/production/metrics.json

.PHONY: manifests
manifests: manifests/production/conprof-template.yaml manifests/production/jaeger-template.yaml manifests/production/observatorium-template.yaml

manifests/production/conprof-template.yaml: $(shell find environments/production -type f) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	$(JSONNET) -J vendor environments/production/conprof.jsonnet | $(GOJSONTOYAML) > manifests/production/conprof-template.yaml

manifests/production/jaeger-template.yaml: $(shell find environments/production -type f) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	$(JSONNET) -J vendor environments/production/jaeger.jsonnet | $(GOJSONTOYAML) > manifests/production/jaeger-template.yaml

manifests/production/observatorium-template.yaml: $(shell find environments/production -type f) $(JSONNET) $(GOJSONTOYAML) $(JSONNETFMT)
	$(JSONNET) -J vendor environments/production/main.jsonnet | $(GOJSONTOYAML) > manifests/production/observatorium-template.yaml
