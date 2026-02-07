.PHONY: build-shared build-macos build-ios test test-shared test-macos lint clean

# Build targets
build-shared:
	cd shared && swift build

build-macos: build-shared
	cd macos && swift build

build-ios:
	@echo "iOS target is a placeholder -- no build configured yet"

# Test targets
test-shared:
	cd shared && swift test

test-macos:
	cd macos && swift test

test: test-shared test-macos

# Lint
lint:
	/opt/homebrew/bin/swiftlint lint --config .swiftlint.yml

# Clean
clean:
	cd shared && swift package clean
	cd macos && swift package clean
