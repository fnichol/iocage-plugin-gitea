JSON_SOURCES ?= $(shell find . -name '*.json' -not -path './tmp/*' -and -not -path './vendor/*')
CHECK_TOOLS += jq

check-json: jq-parse ## Checks linting & styling rules for JSON files
.PHONY: check-json

jq-parse: checktools ## Checks JSON files are parseable
	@echo "--- $@"
	@for json in $(JSON_SOURCES); do echo "jq empty $$json"; jq empty "$$json"; done
.PHONY: jq-parse
