XCODEGEN := xcodegen

.PHONY: gen test lint verify parity clean

gen:
	$(XCODEGEN) generate

test:
	bash scripts/run-tests.sh

lint:
	swift format lint --recursive --strict CamCardClone CamCardCloneTests CamCardCloneUITests CamCardDataTests

# Reproduces the CI test plan locally (requires macOS + Xcode 16.4).
verify:
	bash scripts/run-tests.sh --clean

# Pure-Swift parity check, runnable on Windows without Xcode.
parity:
	swift test

clean:
	rm -rf build *.xcresult
