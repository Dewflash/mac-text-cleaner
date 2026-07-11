.PHONY: verify build test clean

verify: build test

build:
	xcodebuild -scheme TextCleaner -configuration Release -derivedDataPath .build/DerivedData -quiet build

test:
	@mkdir -p .build
	swiftc -parse-as-library TextCleaner/TextCleaner.swift TextCleaner/TextCleanerModel.swift Tests/TextCleanerTests.swift -o .build/textcleaner-tests
	.build/textcleaner-tests

clean:
	rm -rf .build
