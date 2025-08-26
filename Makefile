SHELL := /bin/bash

.PHONY: lint test

lint:
	shellcheck bluezfuncs.sh

test:
	bash -n bluezfuncs.sh
