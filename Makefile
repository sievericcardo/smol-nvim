SHELL := /bin/bash
TS ?= npx --yes tree-sitter-cli@0.24.7
NVIM ?= nvim
LOCKPICK_DIR ?= $(HOME)/Documents/GitHub/lockpick

.PHONY: test ts-test generate parser clean-corpus corpus install-dev

## Run the headless Neovim test suite (compiles the parser in a temp dir).
test:
	bash tests/run.sh

## Run the tree-sitter grammar corpus tests.
ts-test:
	cd tree-sitter-smol && $(TS) test

## Regenerate src/parser.c after editing grammar.js.
generate:
	cd tree-sitter-smol && $(TS) generate

## Build the parser into the plugin's `parser/` directory for local manual use.
parser:
	mkdir -p parser
	$(CC) -O2 -fPIC -shared -I tree-sitter-smol/src \
		tree-sitter-smol/src/parser.c -o parser/smol.so

## Parse every .smol file in the lockpick example corpus; fails on ERROR nodes.
corpus:
	@if [[ ! -d "$(LOCKPICK_DIR)/examples" ]]; then \
		echo "set LOCKPICK_DIR to a lockpick checkout"; exit 1; \
	fi
	@failed=0; \
	for file in $$(find "$(LOCKPICK_DIR)/examples" -name '*.smol' ! -path '*tosemServices-old*'); do \
		if (cd tree-sitter-smol && $(TS) parse "$$file" >/dev/null 2>&1); then :; else \
			echo "parse error: $$file"; failed=1; \
		fi; \
	done; \
	if [[ $$failed -eq 0 ]]; then echo "all corpus files parse cleanly"; else exit 1; fi

clean-corpus:
	find . -name '*.so' -delete
	rm -rf tree-sitter-smol/node_modules
