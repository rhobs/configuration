.PHONY: all
all: generate

.PHONY: generate
generate: deps prometheusrules servicemonitors grafana manifests whitelisted_metrics # slos Disabled for now, dependency is broken.

.PHONY: prometheusrules
prometheusrules: resources/observability/prometheusrules

resources/observability/prometheusrules: prometheusrules.jsonnet
	rm -f resources/observability/prometheusrules/*.yaml
	jsonnetfmt -i prometheusrules.jsonnet
	jsonnet -J vendor -m resources/observability/prometheusrules prometheusrules.jsonnet | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml' -- {}
	find resources/observability/prometheusrules -type f ! -name '*.yaml' -delete
	find resources/observability/prometheusrules/*.yaml | xargs -I{} sh -c '/bin/echo -e "---\n\$$schema: /openshift/prometheus-rule-1.yml\n$$(cat {})" > {}'

.PHONY: servicemonitors
servicemonitors: resources/observability/servicemonitors

resources/observability/servicemonitors: servicemonitors.jsonnet
	rm -f resources/observability/servicemonitors/*.yaml
	jsonnetfmt -i servicemonitors.jsonnet
	jsonnet -J vendor -m resources/observability/servicemonitors servicemonitors.jsonnet | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml' -- {}
	find resources/observability/servicemonitors -type f ! -name '*.yaml' -delete

.PHONY: grafana
grafana: resources/observability/grafana

resources/observability/grafana: grafana.jsonnet
	rm -f resources/observability/grafana/*.yaml
	jsonnetfmt -i grafana.jsonnet
	jsonnet -J vendor -m resources/observability/grafana grafana.jsonnet | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml' -- {}
	find resources/observability/grafana -type f ! -name '*.yaml' -delete

.PHONY: slos
slos: resources/observability/slo/telemeter.slo.yaml

resources/observability/slo/telemeter.slo.yaml: slo.jsonnet
	jsonnetfmt -i slo.jsonnet
	jsonnet -J vendor slo.jsonnet | gojsontoyaml > resources/observability/slo/telemeter.slo.yaml
	find resources/observability/slo/*.yaml | xargs -I{} sh -c '/bin/echo -e "---\n\$$schema: /openshift/prometheus-rule-1.yml\n$$(cat {})" > {}'

.PHONY: whitelisted_metrics
whitelisted_metrics:
	# Download the latest metrics file to extract the new added metrics.
	curl -q https://raw.githubusercontent.com/openshift/cluster-monitoring-operator/master/manifests/0000_50_cluster_monitoring_operator_04-config.yaml | \
	gojsontoyaml -yamltojson | \
	jq -r '.data["metrics.yaml"]' | \
	gojsontoyaml -yamltojson | \
	jq  -r '.matches' > /tmp/metrics-new.json
	# Append new metrics to the existing ones.
	# The final results is sorted to show nicely in the diff.
	# First copy current file, as in-place doesn't work.
	cp environments/production/metrics.json /tmp/metrics.json
	jq -s 'add | unique' /tmp/metrics-new.json /tmp/metrics.json > environments/production/metrics.json

.PHONY: manifests
manifests:
	# Make sure to start with a clean 'manifests' dir
	rm -rf manifests/production/*
	mkdir -p manifests/production
	jsonnetfmt -i environments/production/main.jsonnet
	jsonnetfmt -i environments/production/jaeger.jsonnet
	jsonnetfmt -i environments/production/conprof.jsonnet
	jsonnet -J vendor environments/production/main.jsonnet | gojsontoyaml > manifests/production/observatorium-template.yaml
	jsonnet -J vendor environments/production/jaeger.jsonnet | gojsontoyaml > manifests/production/jaeger-template.yaml
	jsonnet -J vendor environments/production/conprof.jsonnet | gojsontoyaml > manifests/production/conprof-template.yaml
	find manifests/production -type f ! -name '*.yaml' -delete

.PHONY: deps
deps:
	@jb install
