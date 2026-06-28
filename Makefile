# Task shortcuts for Lumixor (Qt5/CMake). Run `make` or `make help`.
PREFIX     ?= $(HOME)/.local
BUILD_TYPE ?= Release
JOBS       ?= $(shell nproc 2>/dev/null || echo 4)
# ponytail: prefer Ninja when installed (faster on the Pi), else cmake default
GEN        := $(shell command -v ninja >/dev/null 2>&1 && echo "-G Ninja")

.PHONY: help deps build run install clean rebuild test

help: ## list targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | sed 's/:.*## / - /' | sort

deps: ## install system build dependencies (apt/zypper/brew)
	./scripts/install-build-dependencies.sh

build: build/CMakeCache.txt ## incremental build
	cmake --build build -j$(JOBS)

build/CMakeCache.txt:
	cmake -B build $(GEN) -DCMAKE_BUILD_TYPE=$(BUILD_TYPE) -DCMAKE_INSTALL_PREFIX=$(PREFIX)

run: build ## build, then run the app
	./build/lumixor-qt

install: build ## build, then install to ~/.local
	cmake --install build

clean: ## remove the build directory
	rm -rf build

rebuild: clean build ## wipe, reconfigure, build

test: ## build and run unit tests (ctest)
	cmake -B build $(GEN) -DBUILD_TESTS=ON -DCMAKE_BUILD_TYPE=$(BUILD_TYPE) -DCMAKE_INSTALL_PREFIX=$(PREFIX)
	cmake --build build -j$(JOBS)
	ctest --test-dir build --output-on-failure
