SHELL := /usr/bin/env bash

.PHONY: deps x64-x86 arm64ec all clean

deps:
	./scripts/install-build-deps.sh

x64-x86:
	./scripts/build-winlator-wine.sh x64-x86

arm64ec:
	./scripts/build-winlator-wine.sh arm64ec

all:
	./scripts/build-winlator-wine.sh all

clean:
	rm -rf work dist
