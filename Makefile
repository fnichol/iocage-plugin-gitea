CLI_SRC_URL := https://raw.githubusercontent.com/fnichol/iocage-plugin-cli/master/bin/plugin
VENDORED_CLI := overlay/usr/local/bin/plugin

.PHONY: vendor-cli
vendor-cli:
	mkdir -p `dirname $(VENDORED_CLI)` \
		&& fetch -o $(VENDORED_CLI) $(CLI_SRC_URL) \
		&& chmod 0755 $(VENDORED_CLI) \
		&& echo && $(VENDORED_CLI) --version \
		&& echo "--> New version of iocage-plugin-cli is vendored in $(VENDORED_CLI)"
