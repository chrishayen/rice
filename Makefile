.PHONY: all build clean run run-server run-debug test help install

BINARY := zig-out/bin/rice

# DES_KEY is required for LCD display encryption (must be exactly 8 bytes)
# Set RICE_DES_KEY environment variable or override with: make build DES_KEY="yourkey8"
DES_KEY ?= $(RICE_DES_KEY)

all: build

build:
ifeq ($(strip $(DES_KEY)),)
	@echo "ERROR: DES_KEY not set!"
	@echo "The LCD display requires a DES encryption key (exactly 8 bytes)."
	@echo ""
	@echo "Build with either:"
	@echo "  export RICE_DES_KEY=\"yourkey8\" && make build"
	@echo "  make build DES_KEY=\"yourkey8\""
	@echo ""
	@exit 1
endif
	@echo "Building Fan Control Application..."
	@echo ""
	zig build -DDES_KEY="$(DES_KEY)"
	@echo ""
	@echo "Build complete!"
	@echo ""
	@echo "Run with:"
	@echo "  make run              (GTK UI - default)"
	@echo "  make run-server       (Background service)"
	@echo "  make run-debug        (Enable debug logging)"

clean:
	@echo "Cleaning build artifacts..."
	rm -f rice
	rm -rf zig-out .zig-cache libs/tinyuz/*.a
	@echo "Done!"

run: build
	./$(BINARY)

run-server: build
	./$(BINARY) --server

run-debug: build
	./$(BINARY) --debug

test:
ifeq ($(strip $(DES_KEY)),)
	@echo "ERROR: DES_KEY not set!"
	@echo "The LCD display requires a DES encryption key (exactly 8 bytes)."
	@echo ""
	@echo "Run tests with either:"
	@echo "  export RICE_DES_KEY=\"yourkey8\" && make test"
	@echo "  make test DES_KEY=\"yourkey8\""
	@echo ""
	@exit 1
endif
	@echo "Running all tests..."
	zig build test -DDES_KEY="$(DES_KEY)"

install: build
	@echo "Installing $(BINARY) to /usr/local/bin..."
	sudo install -m 755 $(BINARY) /usr/local/bin/
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
	@echo ""
	@echo "DES Key Configuration:"
	@echo "  Set RICE_DES_KEY environment variable (exactly 8 bytes):"
	@echo "    export RICE_DES_KEY=\"yourkey8\""
	@echo "  Or override with:"
	@echo "    make build DES_KEY=\"yourkey8\""
	@echo "    make test DES_KEY=\"yourkey8\""
