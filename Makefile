SHELL := /bin/bash

.PHONY: lint test smoke fmt

lint:
	@files=$$(git ls-files '*.sh'); \
	if [[ -n "$$files" ]]; then \
	  shellcheck $$files; \
	else \
	  echo "No .sh files"; \
	fi

test:
	@files=$$(git ls-files '*.sh'); \
	if [[ -n "$$files" ]]; then \
	  bash -n $$files; \
	else \
	  echo "No .sh files"; \
	fi

smoke:
	@set -euo pipefail; \
	if [[ -x tests/smoke.sh ]]; then \
	  tests/smoke.sh; \
	else \
	  echo "tests/smoke.sh not found or not executable"; \
	  exit 1; \
	fi

fmt:
	@files=$$(git ls-files '*.sh'); \
	if [[ -n "$$files" ]]; then \
	  for f in $$files; do bash -n "$$f"; done; \
	else \
	  echo "No .sh files"; \
	fi
