.PHONY: build-shared build-macos build-ios test test-shared test-macos test-ios lint clean

# Build targets
build-shared:
	cd shared && swift build

build-macos: build-shared
	cd macos && swift build

build-ios: build-shared
	cd ios && swift build

# Test targets
test-shared:
	cd shared && swift test

test-macos:
	cd macos && swift test

test-ios:
	cd ios && swift test

test: test-shared test-macos test-ios

# Lint
lint:
	/opt/homebrew/bin/swiftlint lint --config .swiftlint.yml

# Clean
clean:
	cd shared && swift package clean
	cd macos && swift package clean
	cd ios && swift package clean
