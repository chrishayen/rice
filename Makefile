.PHONY: all build clean run run-server run-debug test help install

BINARY := rice
ZIG := zig

all: build

build:
	@echo "Building Fan Control Application..."
	@echo ""
	@echo "Building rice package..."
	$(ZIG) build
	@echo "  ✓ rice ($$(du -h zig-out/bin/$(BINARY) | cut -f1))"
	@echo ""
	@echo "Build complete!"
	@echo ""
	@echo "Run with:"
	@echo "  make run              (GTK UI - default)"
	@echo "  make run-server       (Background service)"
	@echo "  make run-debug        (Enable debug logging)"

clean:
	@echo "Cleaning build artifacts..."
	rm -rf zig-out zig-cache
	@echo "Done!"

run: build
	./zig-out/bin/$(BINARY)

run-server: build
	./zig-out/bin/$(BINARY) --server

run-debug: build
	./zig-out/bin/$(BINARY) --debug

test:
	@echo "Running all tests..."
	$(ZIG) build test

install: build
	@echo "Installing $(BINARY) to /usr/local/bin..."
	sudo install -m 755 zig-out/bin/$(BINARY) /usr/local/bin/
	@echo "Done!"

help:
	@echo "Available targets:"
	@echo "  make build                      - Build the fan control application"
	@echo "  make test                       - Run tests"
	@echo "  make clean                      - Remove build artifacts"
	@echo "  make run                        - Build and run with GTK UI (default)"
	@echo "  make run-server                 - Build and run as background service"
	@echo "  make run-debug                  - Build and run with debug logging"
	@echo "  make install                    - Build and install to /usr/local/bin"
	@echo "  make help                       - Show this help message"
