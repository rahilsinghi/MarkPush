VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")

.PHONY: build test lint clean install help

## CLI targets

build: ## Build the CLI binary
	cd cli && go build -ldflags="-s -w -X main.version=$(VERSION)" -o ../bin/markpush .

test: ## Run all Go tests with race detection
	cd cli && go test ./... -race -coverprofile=coverage.out

coverage: test ## Show test coverage in browser
	cd cli && go tool cover -html=coverage.out -o coverage.html
	open cli/coverage.html

lint: ## Run Go linter
	cd cli && golangci-lint run

install: ## Install CLI to GOPATH
	cd cli && go install .

clean: ## Remove build artifacts
	rm -rf bin/ cli/coverage.out cli/coverage.html dist/

## iOS targets (requires Xcode)

ios-build: ## Build iOS app for simulator
	xcodebuild build -project ios/MarkPush.xcodeproj -scheme MarkPush -destination 'platform=iOS Simulator,name=iPhone 16' | xcbeautify

ios-test: ## Run iOS tests
	xcodebuild test -project ios/MarkPush.xcodeproj -scheme MarkPush -destination 'platform=iOS Simulator,name=iPhone 16' | xcbeautify

## All

all: lint test build ## Lint, test, and build everything

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
