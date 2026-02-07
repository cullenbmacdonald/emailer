# Emailer Server Makefile
# Standard targets: build, test, lint, fmt, run, clean

BINARY_NAME := server
BINARY_DIR := bin
CMD_PATH := ./cmd/server

# Build info (injected via ldflags)
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT_HASH ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_TIME ?= $(shell date -u '+%Y-%m-%dT%H:%M:%SZ')

# Go build flags
LDFLAGS := -ldflags "\
	-X main.version=$(VERSION) \
	-X main.commitHash=$(COMMIT_HASH) \
	-X main.buildTime=$(BUILD_TIME) \
	-s -w"

.PHONY: build test lint fmt run clean tidy

## build: Compile the server binary (static, no CGO)
build:
	CGO_ENABLED=0 go build $(LDFLAGS) -o $(BINARY_DIR)/$(BINARY_NAME) $(CMD_PATH)

## test: Run all tests with race detector
test:
	go test -race -count=1 ./...

## lint: Run golangci-lint and go vet
lint:
	go vet ./...
	golangci-lint run

## fmt: Format all Go source files
fmt:
	gofmt -s -w .

## run: Build and run the server
run: build
	./$(BINARY_DIR)/$(BINARY_NAME)

## clean: Remove build artifacts
clean:
	rm -rf $(BINARY_DIR)
	go clean -cache -testcache

## tidy: Tidy go module dependencies
tidy:
	go mod tidy
