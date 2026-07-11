.PHONY: verify build test clean

verify: build test

build:
	@set -e; \
	DERIVED_DATA=$$(mktemp -d); \
	trap 'rm -rf "$$DERIVED_DATA"' EXIT; \
	xcodebuild -scheme TextCleaner -configuration Release -derivedDataPath "$$DERIVED_DATA" -quiet build; \
	rm -rf build/TextCleaner.app; \
	mkdir -p build; \
	ditto --norsrc --noextattr --noqtn --noacl "$$DERIVED_DATA/Build/Products/Release/TextCleaner.app" build/TextCleaner.app
	@echo "Built build/TextCleaner.app"

test:
	@set -e; \
	TEST_DIR=$$(mktemp -d); \
	trap 'rm -rf "$$TEST_DIR"' EXIT; \
	swiftc -parse-as-library TextCleaner/TextCleaner.swift TextCleaner/TextCleanerModel.swift Tests/TextCleanerTests.swift -o "$$TEST_DIR/textcleaner-tests"; \
	"$$TEST_DIR/textcleaner-tests"

clean:
	rm -rf .build build
