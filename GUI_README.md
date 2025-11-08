# Lian Li Fan Control GUI

Two native Odin implementations of the fan control GUI - choose based on your preference!

## Versions

### 1. Raylib Version (`fan_control_gui`)
- **File**: `fan_control_gui.odin`
- **Size**: ~1.2 MB (standalone)
- **Dependencies**: None (statically linked)
- **Look**: Custom UI with immediate mode rendering
- **Best for**: Portability, no system dependencies

**Features**:
- Smooth 60 FPS rendering
- Custom controls and widgets
- Hexagonal LED preview with glow effects
- Real-time animation (30 FPS for effects)
- Compact binary

### 2. GTK4 + libadwaita Version (`fan_control_gtk`)
- **File**: `fan_control_gtk.odin`
- **Size**: ~200 KB (dynamically linked)
- **Dependencies**: GTK4, libadwaita-1, Cairo, GLib
- **Look**: Modern GNOME/Adwaita design
- **Best for**: Desktop integration, native GNOME look & feel

**Features**:
- Modern libadwaita widgets (AdwApplicationWindow, AdwHeaderBar, AdwPreferencesGroup, AdwActionRow)
- Rounded corners and modern spacing
- System theme integration
- Tabbed interface with AdwTabView (modern tab bar)
- Cairo-based LED preview with hexagonal fans
- Smaller binary (uses system libraries)
- "card" CSS class for device list
- "pill" and "suggested-action" CSS for buttons

## Building

```bash
# Build both versions
./build_gui.sh

# Or build individually:

# Raylib version
odin build fan_control_gui.odin -file

# GTK version
odin build fan_control_gtk.odin -file -extra-linker-flags:"$(pkg-config --libs gtk4 cairo glib-2.0 gobject-2.0)"
```

## Running

```bash
# Raylib version
./fan_control_gui

# GTK version
./fan_control_gtk
```

## Dependencies

### Raylib Version
- None! Fully standalone binary
- Raylib is statically linked via Odin's vendor package

### GTK + libadwaita Version
On Arch Linux:
```bash
sudo pacman -S gtk4 libadwaita cairo glib2
```

On Ubuntu/Debian:
```bash
sudo apt install libgtk-4-dev libadwaita-1-dev libcairo2-dev libglib2.0-dev
```

## Features (Both Versions)

### Device Management
- Device list sidebar
- Shows MAC address, type (SL-LCD/TL), channel, bound status
- LED count per device
- Refresh button to query devices

### LED Effects (7 implemented)
1. **Static Color** - Solid color
2. **Rainbow** - Rainbow gradient
3. **Alternating** - Two colors alternating
4. **Alternating Spin** - Rotating pattern (60 frames)
5. **Rainbow Morph** - Shifting rainbow (100 frames)
6. **Breathing** - Fade in/out (60 frames)
7. **Meteor** - Colorful meteor with tail

### Controls
- Effect selector (radio buttons)
- Color pickers (primary + secondary)
- Brightness slider (0-100%)
- Preview button (shows effect in real-time)
- Apply button (sends to hardware via Python `sl_led.py`)

### LED Preview
- Hexagonal fan visualization
- LEDs arranged along hexagon edges
- Supports SL-LCD (40 LEDs) and TL (26 LEDs) fans
- Glow effects for bright LEDs
- Animation support (Raylib only for now)
- Grid layout for multiple fans

### Additional Tabs
- LCD Display (placeholder)
- Settings (shows RF channel)

## Architecture

Both versions use the same backend:
- Call Python `sl_led.py` via subprocess for hardware control
- USB/RF communication handled by existing Python code
- GUI is pure Odin, zero Python dependencies for UI

## Comparison

| Feature | Raylib | GTK4 + libadwaita |
|---------|--------|-------------------|
| Binary size | 1.2 MB | 200 KB |
| Dependencies | None | GTK4, libadwaita, Cairo |
| FPS | 60 | ~60 (GTK vsync) |
| Theme | Custom | Modern GNOME/Adwaita |
| Animation | ✓ Real-time | Static preview only |
| Startup | Instant | ~100ms |
| Portability | ★★★★★ | ★★★☆☆ |
| Native look | ★★☆☆☆ | ★★★★★ |
| Modern design | ★★★☆☆ | ★★★★★ |

## Status

- ✅ Device management
- ✅ Effect selection
- ✅ LED preview rendering
- ✅ 7 effects implemented
- ⏳ Animation in GTK version
- ⏳ Real device querying (currently mock data)
- ⏳ Effect application (skeleton in place)
- ⏳ LCD display control
- ⏳ Advanced settings

## Screenshots

Run either version to see:
- Left sidebar: Device list with 3 mock devices
- Right panel: Effect controls + hexagonal LED preview
- Bottom: Preview and Apply buttons

## Development

The GUIs are written in pure Odin:
- No C interop complexity (except GTK FFI)
- Memory managed with Odin's allocators
- Type-safe with Odin's strong type system
- Fast compile times (~1 second)

## Next Steps

1. Implement remaining effects (runway, wave, meteor shower, twinkle)
2. Add real device querying (call `sl_led.py query`)
3. Wire up Apply button to execute `sl_led.py` commands
4. Add animation support to GTK version (GLib timeout)
5. Implement LCD display tab
6. Add RF channel configuration
7. Save/load user presets

## License

Same as parent project
