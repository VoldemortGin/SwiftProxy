# SwiftProxy Makefile
# Provides convenient commands for building, testing, and running the project

.PHONY: help build run test clean release install format lint

# Default target
.DEFAULT_GOAL := help

# Variables
PRODUCT_NAME := SwiftProxy
BUILD_DIR := .build
DEBUG_BUILD := $(BUILD_DIR)/debug/$(PRODUCT_NAME)
RELEASE_BUILD := $(BUILD_DIR)/release/$(PRODUCT_NAME)
INSTALL_PATH := /usr/local/bin

# Colors for output
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

## help: Show this help message
help:
	@echo "$(CYAN)SwiftProxy - Available Commands:$(NC)"
	@echo ""
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'
	@echo ""

## build: Build the project in debug mode
build:
	@echo "$(CYAN)Building $(PRODUCT_NAME) in debug mode...$(NC)"
	@swift build
	@echo "$(GREEN)✓ Build complete!$(NC)"

## run: Build and run the application
run: build
	@echo "$(CYAN)Running $(PRODUCT_NAME)...$(NC)"
	@$(DEBUG_BUILD)

## test: Run all tests
test:
	@echo "$(CYAN)Running tests...$(NC)"
	@swift test
	@echo "$(GREEN)✓ Tests complete!$(NC)"

## test-verbose: Run tests with verbose output
test-verbose:
	@echo "$(CYAN)Running tests (verbose)...$(NC)"
	@swift test --verbose

## test-unit: Run unit tests only
test-unit:
	@echo "$(CYAN)Running unit tests...$(NC)"
	@swift test --filter SwiftProxyTests

## test-integration: Run integration tests only
test-integration:
	@echo "$(CYAN)Running integration tests...$(NC)"
	@swift test --filter SwiftProxyIntegrationTests

## release: Build the project in release mode
release:
	@echo "$(CYAN)Building $(PRODUCT_NAME) in release mode...$(NC)"
	@swift build -c release
	@echo "$(GREEN)✓ Release build complete!$(NC)"
	@echo "Binary location: $(RELEASE_BUILD)"

## clean: Clean build artifacts
clean:
	@echo "$(CYAN)Cleaning build artifacts...$(NC)"
	@swift package clean
	@rm -rf $(BUILD_DIR)
	@echo "$(GREEN)✓ Clean complete!$(NC)"

## install: Install the release build to system (requires sudo)
install: release
	@echo "$(CYAN)Installing $(PRODUCT_NAME) to $(INSTALL_PATH)...$(NC)"
	@sudo cp $(RELEASE_BUILD) $(INSTALL_PATH)/
	@echo "$(GREEN)✓ Installation complete!$(NC)"
	@echo "Run '$(PRODUCT_NAME)' from anywhere"

## uninstall: Uninstall from system (requires sudo)
uninstall:
	@echo "$(CYAN)Uninstalling $(PRODUCT_NAME)...$(NC)"
	@sudo rm -f $(INSTALL_PATH)/$(PRODUCT_NAME)
	@echo "$(GREEN)✓ Uninstall complete!$(NC)"

## update: Update Swift package dependencies
update:
	@echo "$(CYAN)Updating dependencies...$(NC)"
	@swift package update
	@echo "$(GREEN)✓ Dependencies updated!$(NC)"

## resolve: Resolve Swift package dependencies
resolve:
	@echo "$(CYAN)Resolving dependencies...$(NC)"
	@swift package resolve
	@echo "$(GREEN)✓ Dependencies resolved!$(NC)"

## format: Format code (requires swift-format)
format:
	@if command -v swift-format >/dev/null 2>&1; then \
		echo "$(CYAN)Formatting code...$(NC)"; \
		swift-format -i -r SwiftProxy/ SwiftProxyTests/ SwiftProxyIntegrationTests/; \
		echo "$(GREEN)✓ Code formatted!$(NC)"; \
	else \
		echo "$(YELLOW)⚠ swift-format not installed. Skipping...$(NC)"; \
		echo "Install with: brew install swift-format"; \
	fi

## lint: Lint code (requires swiftlint)
lint:
	@if command -v swiftlint >/dev/null 2>&1; then \
		echo "$(CYAN)Linting code...$(NC)"; \
		swiftlint; \
		echo "$(GREEN)✓ Lint complete!$(NC)"; \
	else \
		echo "$(YELLOW)⚠ swiftlint not installed. Skipping...$(NC)"; \
		echo "Install with: brew install swiftlint"; \
	fi

## xcode: Generate and open Xcode project
xcode:
	@echo "$(CYAN)Opening in Xcode...$(NC)"
	@open Package.swift

## benchmark: Run performance benchmarks (if available)
benchmark:
	@echo "$(CYAN)Running benchmarks...$(NC)"
	@swift test --filter Benchmark

## coverage: Generate test coverage report
coverage:
	@echo "$(CYAN)Generating coverage report...$(NC)"
	@swift test --enable-code-coverage
	@echo "$(GREEN)✓ Coverage report generated!$(NC)"

## archive: Create distributable archive
archive: release
	@echo "$(CYAN)Creating archive...$(NC)"
	@mkdir -p dist
	@tar -czf dist/$(PRODUCT_NAME)-$(shell date +%Y%m%d).tar.gz -C $(BUILD_DIR)/release $(PRODUCT_NAME)
	@echo "$(GREEN)✓ Archive created in dist/$(NC)"

## info: Show project information
info:
	@echo "$(CYAN)SwiftProxy Project Information:$(NC)"
	@echo ""
	@echo "Product Name:    $(PRODUCT_NAME)"
	@echo "Swift Version:   $(shell swift --version | head -n 1)"
	@echo "Build Directory: $(BUILD_DIR)"
	@echo "Debug Binary:    $(DEBUG_BUILD)"
	@echo "Release Binary:  $(RELEASE_BUILD)"
	@echo ""

## doctor: Check development environment
doctor:
	@echo "$(CYAN)Checking development environment...$(NC)"
	@echo ""
	@echo -n "Swift:        "
	@if command -v swift >/dev/null 2>&1; then \
		echo "$(GREEN)✓ $(shell swift --version | head -n 1)$(NC)"; \
	else \
		echo "$(RED)✗ Not installed$(NC)"; \
	fi
	@echo -n "Xcode:        "
	@if command -v xcodebuild >/dev/null 2>&1; then \
		echo "$(GREEN)✓ $(shell xcodebuild -version | head -n 1)$(NC)"; \
	else \
		echo "$(RED)✗ Not installed$(NC)"; \
	fi
	@echo -n "swift-format: "
	@if command -v swift-format >/dev/null 2>&1; then \
		echo "$(GREEN)✓ Installed$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Not installed$(NC)"; \
	fi
	@echo -n "swiftlint:    "
	@if command -v swiftlint >/dev/null 2>&1; then \
		echo "$(GREEN)✓ Installed$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Not installed$(NC)"; \
	fi
	@echo ""
