INIT ?= []
PARAMS ?= [paramPasswordLength-8]

.PHONY: help doctor graph range build docker-provision docker-range test

help:
	@echo "make doctor                                            -- check for required tools"
	@echo "make graph                                             -- render vulns.dot(.png)"
	@echo "make range GOAL='[root_shell]' [INIT='[]'] [PARAMS='[paramPasswordLength-8]']"
	@echo "                                                        -- generate a range"
	@echo "make build LATTICE=ranges/<range-id>/<lattice-id>      -- build a VM (Packer/VirtualBox)"
	@echo "make docker-provision LATTICE=ranges/<range-id>/<lattice-id>"
	@echo "                                                        -- provision a container instead"
	@echo "make docker-range GOAL='[web_admin_access]'            -- generate + provision in one step"
	@echo "make test                                               -- run the Prolog test suite"

doctor:
	@bash scripts/doctor.sh

graph:
	swipl prolog/main.pl graphAllVulns vulns.dot

range:
	@if [ -z "$(GOAL)" ]; then \
		echo "usage: make range GOAL='[root_shell]' [INIT='[]'] [PARAMS='[paramPasswordLength-8]']" >&2; \
		exit 1; \
	fi
	swipl prolog/main.pl createRangeFromIGS '$(INIT)' '$(GOAL)' '$(PARAMS)'

build:
	@if [ -z "$(LATTICE)" ]; then \
		echo "usage: make build LATTICE=ranges/<range-id>/<lattice-id>" >&2; \
		exit 1; \
	fi
	cd "$(LATTICE)" && bash run_packer.sh

docker-provision:
	@if [ -z "$(LATTICE)" ]; then \
		echo "usage: make docker-provision LATTICE=ranges/<range-id>/<lattice-id>" >&2; \
		exit 1; \
	fi
	bash docker/provision-and-bake.sh "$(LATTICE)"

docker-range:
	@if [ -z "$(GOAL)" ]; then \
		echo "usage: make docker-range GOAL='[web_admin_access]' [INIT='[]'] [PARAMS='[paramPasswordLength-8]']" >&2; \
		exit 1; \
	fi
	bash docker/generate-and-provision.sh '$(INIT)' '$(GOAL)' '$(PARAMS)'

test:
	swipl -s prolog/alpaca_tests.pl -g run_tests -t halt
