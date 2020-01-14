.PHONY: all
all: generate

.PHONY: generate
generate: prometheusrules servicemonitors slos

.PHONY: prometheusrules
prometheusrules: resources/observability/prometheusrules

resources/observability/prometheusrules:
	jsonnetfmt -i prometheusrules.jsonnet
	jsonnet -J vendor -m resources/observability/prometheusrules prometheusrules.jsonnet | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml -- {}; rm -rf {}' -- {}

.PHONY: servicemonitors
servicemonitors: resources/observability/servicemonitors

resources/observability/servicemonitors:
	jsonnetfmt -i servicemonitors.jsonnet
	jsonnet -J vendor -m resources/observability/servicemonitors servicemonitors.jsonnet | xargs -I{} sh -c 'cat {} | gojsontoyaml > {}.yaml -- {}; rm -rf {}' -- {}

.PHONY: slos
slos: resources/observability/slo/observatorium.slo.yaml

resources/observability/slo/observatorium.slo.yaml: slo.jsonnet
	jsonnetfmt -i slo.jsonnet
	jsonnet -J vendor slo.jsonnet | gojsontoyaml > resources/observability/slo/observatorium.slo.yaml
