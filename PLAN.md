# Plan: USB Serial Number Addressing + Complete LCD/LED Separation

## Overview
Transform the UI from unified device management to completely separate LCD and LED systems, with USB serial number addressing for LCD devices.

## Background

### Current Problem
- UI uses unstable USB bus/address for LCD devices
- LCD and LED systems are coupled through a unified Device struct
- LCD device selection depends on RF device enumeration
- Single device list used for both LED effects and LCD configuration

### Target Architecture
- LED system: RF devices identified by MAC address
- LCD system: USB devices identified by serial number
- Complete separation: independent device lists, enumeration, and UI panels
- Context-aware device selection (LCD panel shows only LCD devices, LED panel shows only LED devices)

---

## Part 1: Create Separate Device Data Structures

### 1.1 Define LED-specific device struct (ui.odin)
- [ ] Create `LED_Device` struct with RF-only fields:
  - mac_str: string
  - rx_type: u8
  - channel: u8
  - bound: bool
  - led_count: int
  - fan_count: int
  - dev_type_name: string
- [ ] Remove LCD-related fields

### 1.2 Define LCD-specific device struct (ui.odin)
- [ ] Create `LCD_Device` struct with USB fields:
  - serial_number: string
  - fan_count: int
  - fan_types: [4]u8
  - friendly_name: string (for display)
- [ ] No RF fields (no rx_type, channel, mac_str)

### 1.3 Update App_State (ui.odin)
- [ ] Replace `devices: [dynamic]Device` with `led_devices: [dynamic]LED_Device`
- [ ] Add `lcd_devices: [dynamic]LCD_Device`
- [ ] Remove `usb_lcd_devices` array
- [ ] Update references throughout codebase

### 1.4 Write tests
- [ ] Test LED_Device struct creation
- [ ] Test LCD_Device struct creation
- [ ] `make test`

---

## Part 2: Separate Device Enumeration

### 2.1 Create independent LCD device enumeration
- [ ] Refactor `enumerate_usb_lcd_devices()` to populate `state.lcd_devices`
- [ ] Use `get_usb_serial_number()` for each USB device
- [ ] Build LCD device list independent of RF device list
- [ ] Remove rx_type mapping logic
- [ ] Extract friendly name generation for display

### 2.2 Create LED device polling
- [ ] Rename/refactor `poll_devices_from_service()` to `poll_led_devices()`
- [ ] Populate `state.led_devices` from IPC Get_Devices response
- [ ] Remove LCD-related logic (has_lcd flag processing)
- [ ] Remove usb_serial_number copying

### 2.3 Update rebuild_device_list
- [ ] Call `poll_led_devices()` for LED enumeration
- [ ] Call `enumerate_lcd_devices()` for LCD enumeration
- [ ] Ensure no cross-dependencies between calls

### 2.4 Write tests
- [ ] Test LCD enumeration returns correct serial numbers
- [ ] Test LED polling returns correct RF devices
- [ ] Test independent enumeration (no coupling)
- [ ] `make test`

---

## Part 3: Separate UI Panels

### 3.1 Make Devices Panel LED-only (ui_devices_panel.odin)
- [ ] Rename panel header to "LED Devices"
- [ ] Update to use `state.led_devices` exclusively
- [ ] Remove LCD awareness from device cards
- [ ] Show RF-specific info only:
  - Channel
  - Bind status
  - LED count
  - Fan count

### 3.2 Update LCD Display Panel (ui.odin)
- [ ] Create independent LCD device dropdown
- [ ] Use `state.lcd_devices` as data source
- [ ] Display format: serial number or friendly name
- [ ] Selection stores serial_number (not device index)
- [ ] Remove dependency on LED device list

### 3.3 Update device cards (ui_device_card.odin)
- [ ] Remove `has_lcd` checks
- [ ] Remove LCD-aware friendly names
- [ ] LED-focused display only

### 3.4 Write tests
- [ ] Test LED device panel shows correct devices
- [ ] Test LCD dropdown shows correct devices
- [ ] Test device selection independence
- [ ] `make test`

---

## Part 4: Update IPC Interactions

### 4.1 LED effects
- [ ] Update effect application to use `LED_Device` from `led_devices` list
- [ ] Pass mac_str, rx_type, channel as before
- [ ] Remove LCD-related checks

### 4.2 LCD playback
- [ ] Update playback start to use `LCD_Device` from `lcd_devices` list
- [ ] Pass serial_number directly (IPC already uses serial numbers)
- [ ] Remove rx_type to USB device lookup logic
- [ ] Use serial_number for fan index lookup

### 4.3 Write tests
- [ ] Test LED effect IPC with LED_Device
- [ ] Test LCD playback IPC with serial number
- [ ] `make test`

---

## Part 5: Clean Up Coupling

### 5.1 Remove has_lcd from RF cache
- [ ] Remove `has_lcd` flag from `Device_Cache_Entry` (device_cache.odin)
- [ ] Remove `usb_serial_number` from `RF_Device_Info` (led.odin)
- [ ] Update device cache serialization (devices.json)
- [ ] LCD detection no longer part of LED system

### 5.2 Update configuration storage
- [ ] Verify devices.json becomes LED/RF-only
- [ ] Verify lcd_config.json remains LCD-only (already using serial numbers)
- [ ] No coupling between config files

### 5.3 Write tests
- [ ] Test device cache serialization (LED-only)
- [ ] Test LCD config serialization (serial numbers)
- [ ] `make test`

---

## Part 6: Final Cleanup and Verification

### 6.1 Remove unused code
- [ ] Remove old unified `Device` struct if not used
- [ ] Remove `USB_LCD_Device` struct
- [ ] Clean up any leftover coupling logic

### 6.2 Update variable names
- [ ] Ensure all variable names reflect LED/LCD separation
- [ ] Update comments to reflect new architecture

### 6.3 Write tests
- [ ] `make test` - all tests pass
- [ ] Manual test: LED device enumeration
- [ ] Manual test: LED effects application
- [ ] Manual test: LCD device enumeration
- [ ] Manual test: LCD configuration
- [ ] Manual test: Unplug/replug USB device (serial number persistence)
- [ ] Manual test: Reboot system (serial number persistence)

---

## Testing Strategy

After each major change:
1. `make build` to verify compilation
2. `make test` to run automated tests
3. Manual testing as appropriate

Final verification:
- LED device enumeration works independently
- LCD device enumeration works independently
- LED effects can be applied
- LCD playback can be started
- LCD devices identified correctly after unplug/replug
- LCD configuration persists across reboots
- No coupling between LED and LCD systems

---

## Expected Outcome

### Before
- One unified device list mixing RF and USB concerns
- LCD selection depends on RF device enumeration
- has_lcd flag couples systems
- USB bus/address (unstable across reboots)

### After
- Two independent systems:
  - LED system: RF devices (MAC address) → LED effects
  - LCD system: USB devices (serial number) → LCD playback
- Context-aware device selection
- LCD panel shows only LCD devices
- LED panel shows only LED devices
- Stable serial number addressing for LCD devices
