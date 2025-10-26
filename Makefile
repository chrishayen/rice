.PHONY: all build clean run run-server run-debug test help install

BINARY := rice
ODIN := odin
PKG_CONFIG := pkg-config

# DES_KEY is required for LCD display encryption (must be exactly 8 bytes)
# Set RICE_DES_KEY environment variable or override with: make build DES_KEY="yourkey8"
DES_KEY ?= $(RICE_DES_KEY)

ODIN_FLAGS := -o:speed
LIBS := gtk4 libadwaita-1 cairo glib-2.0 gobject-2.0 libusb-1.0
LINKER_FLAGS := $(shell $(PKG_CONFIG) --libs $(LIBS))

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
	@echo "Building rice package..."
	$(ODIN) build . -out:$(BINARY) $(ODIN_FLAGS) -define:DES_KEY="$(DES_KEY)" -extra-linker-flags:"$(LINKER_FLAGS)"
	@echo "  ✓ rice ($$(du -h $(BINARY) | cut -f1))"
	@echo ""
	@echo "Build complete!"
	@echo ""
	@echo "Run with:"
	@echo "  make run              (GTK UI - default)"
	@echo "  make run-server       (Background service)"
	@echo "  make run-debug        (Enable debug logging)"

clean:
	@echo "Cleaning build artifacts..."
	rm -f $(BINARY)
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
	$(ODIN) test . -all-packages $(ODIN_FLAGS) -define:DES_KEY="$(DES_KEY)" -extra-linker-flags:"$(LINKER_FLAGS)"

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
