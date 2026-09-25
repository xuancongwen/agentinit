.PHONY: build test check
build:            ## regenerate install.sh from src/ and templates/
	./build.sh
test: build       ## run the test suite against src/ and the built install.sh
	test/run.sh src/agentinit.sh
	test/run.sh install.sh
check: build      ## fail if install.sh is stale
	git diff --exit-code install.sh
