# Lian Li SL 120 LCD Fan Protocol Documentation

This document describes the USB protocol for controlling LCD screens on Lian Li SL 120 LCD fans.

## Hardware Information

- **Vendor ID**: `0x1cbe`
- **Product ID**: `0x0005`
- **Device Type**: Lian Li SL-LCD wired controller
- **OUT Endpoint**: `0x01`
- **IN Endpoint**: `0x81`

## LCD Display Specifications

- **Resolution**: 400x400 pixels
- **Format**: JPEG (recommended quality: 85-95%)
- **Frame Size**: Exactly 102,400 bytes (padded)
- **Supported Commands**: JPEG (101), PNG (102), H264 (13), Brightness (2), Rotation (1), Stop (120)

## Protocol Structure

### Frame Format

Every LCD frame consists of:

1. **Encrypted Header** (512 bytes) - DES-CBC encrypted metadata
2. **JPEG Data** (variable, max 101,888 bytes) - Raw JPEG image data
3. **Zero Padding** (if needed) - Pad to exactly 102,400 bytes total

```
┌─────────────────┬──────────────────┬─────────────────┐
│  Encrypted      │   JPEG Data      │  Zero Padding   │
│  Header         │   (variable)     │   (if needed)   │
│  512 bytes      │  max 101,888 B   │                 │
└─────────────────┴──────────────────┴─────────────────┘
        ↑                                    ↑
        └────────────────────────────────────┘
              Total: 102,400 bytes
```

## Header Encryption

### Plaintext Header Structure (504 bytes)

Before encryption, the header is structured as follows:

| Offset | Size | Field        | Description                           |
|--------|------|--------------|---------------------------------------|
| 0      | 1    | Command      | Command code (101 for JPEG)           |
| 1      | 1    | Reserved     | Always 0x00                           |
| 2      | 2    | Magic        | Always 0x1a, 0x6d (little-endian)     |
| 4      | 4    | Timestamp    | Current time in milliseconds (LE)     |
| 8      | 4    | Image Size   | JPEG size in bytes (big-endian)       |
| 12     | 492  | Reserved     | All zeros                             |

**Total: 504 bytes**

### Encryption Process

The header encryption follows these exact steps:

1. **Create 504-byte plaintext buffer**
   - Fill bytes 0-11 with command data (as shown above)
   - Fill bytes 12-503 with zeros

2. **Apply PKCS7 padding**
   - Pad the 504 bytes to 512 bytes using PKCS7
   - This adds 8 bytes with value `0x08`
   - Result: 512 bytes total

3. **Encrypt with DES-CBC**
   - **Algorithm**: DES (Data Encryption Standard)
   - **Mode**: CBC (Cipher Block Chaining)
   - **Key**: `slv3tuzx` (8 ASCII bytes)
   - **IV**: Same as key (`slv3tuzx`)
   - **Block size**: 8 bytes
   - Encrypt all 512 bytes

4. **Result**: 512-byte encrypted header

### PKCS7 Padding Example

```
Original: [504 bytes of data]
Padded:   [504 bytes of data][0x08][0x08][0x08][0x08][0x08][0x08][0x08][0x08]
          └─────────────────┘└───────────────────────────────────────────────┘
             504 bytes                    8 bytes padding

Total: 512 bytes (64 blocks of 8 bytes each)
```

**Why PKCS7 padding is critical:**
- Zero padding does NOT work
- The device expects proper PKCS7 padding
- Padding value = number of padding bytes added (always 0x08 for this protocol)

## Command Codes

| Code | Name       | Description                    |
|------|------------|--------------------------------|
| 1    | Rotate     | Set LCD rotation (0-3)         |
| 2    | Brightness | Set brightness level (0-100)   |
| 13   | H264       | H264 video frame               |
| 101  | JPEG       | Display JPEG image             |
| 102  | PNG        | Display PNG image              |
| 120  | Stop       | Stop video playback            |

## Image Format Details

### JPEG Encoding

Recommended settings for best results:
- **Quality**: 85-95%
- **Format**: Progressive JPEG or Baseline
- **Color space**: RGB
- **Resolution**: 400x400 pixels
- **Max file size**: 101,888 bytes

### Image Processing Pipeline

```
Source Image
    ↓
Resize to 400x400
    ↓
Convert to RGB
    ↓
Encode as JPEG (quality 85-95%)
    ↓
Check size ≤ 101,888 bytes
    ↓
Build frame (header + JPEG + padding)
    ↓
Send via USB
```

## USB Communication

### Sending Frames

1. Build the frame:
   ```
   Header (512 bytes) + JPEG data + Zero padding = 102,400 bytes
   ```

2. Send via bulk transfer:
   - **Endpoint**: OUT (0x01)
   - **Size**: 102,400 bytes (always exact)
   - **Timeout**: 5000ms

3. Read acknowledgment:
   - **Endpoint**: IN (0x81)
   - **Size**: 512 bytes
   - **Timeout**: 1000ms
   - Ignore timeout errors (device may not always respond)

### Frame Timing

For smooth video playback:
- **Target FPS**: 20-30 fps recommended
- **Frame interval**: 33-50ms (calculated as 1000ms / fps)
- **Acknowledgment**: Must drain IN endpoint after each frame

## Implementation Notes

### Critical Requirements

1. **Frame size must be exactly 102,400 bytes**
   - Not variable length
   - Pad with zeros if needed
   - Truncate is not recommended (check size before building frame)

2. **Use PKCS7 padding for header encryption**
   - NOT zero padding
   - 504 bytes plaintext → 512 bytes with PKCS7
   - Padding byte value must equal number of padding bytes

3. **Encryption parameters must match exactly**
   - Key: `slv3tuzx` (8 ASCII bytes)
   - IV: Same as key
   - Mode: DES-CBC
   - Block size: 8 bytes

4. **Image size must be ≤ 101,888 bytes**
   - This is FRAME_SIZE (102,400) - HEADER_SIZE (512)
   - Larger images will fail or be rejected

### Common Pitfalls

❌ **WRONG**: Using zero padding instead of PKCS7
```
[504 bytes][0x00][0x00][0x00][0x00][0x00][0x00][0x00][0x00]
```

✅ **CORRECT**: Using PKCS7 padding
```
[504 bytes][0x08][0x08][0x08][0x08][0x08][0x08][0x08][0x08]
```

❌ **WRONG**: Variable frame size
```
Header (512) + JPEG (50,000) = 50,512 bytes
```

✅ **CORRECT**: Fixed frame size with padding
```
Header (512) + JPEG (50,000) + Padding (51,888) = 102,400 bytes
```

❌ **WRONG**: Adding magic footer bytes after encryption
```
Encrypt 504 bytes → Copy to 512-byte buffer → Add 0xA1, 0x1A at end
```

✅ **CORRECT**: Just encrypt 512 PKCS7-padded bytes
```
504 bytes → PKCS7 pad to 512 → Encrypt all 512 bytes
```

## Example: Building a Frame

```odin
import des "libs/des"

// 1. Create plaintext header (504 bytes)
plaintext: [504]u8
plaintext[0] = 101                    // JPEG command
plaintext[2] = 0x1a                   // Magic bytes
plaintext[3] = 0x6d
// ... set timestamp (bytes 4-7)
// ... set JPEG size (bytes 8-11, big-endian)
// Bytes 12-503 are zeros

// 2. Apply PKCS7 padding (504 → 512 bytes)
padded := des.pkcs7_pad(plaintext[:], des.DES_BLOCK_SIZE)
defer delete(padded)

// 3. Encrypt with DES-CBC
DES_KEY := [8]u8{'s', 'l', 'v', '3', 't', 'u', 'z', 'x'}
DES_IV := DES_KEY  // IV is same as key

encrypted := make([]u8, len(padded))
defer delete(encrypted)
des.des_cbc_encrypt(padded, encrypted, DES_KEY[:], DES_IV[:])

// 4. Build complete frame (102,400 bytes)
frame := make([]u8, 102400)
copy(frame[0:512], encrypted)           // Copy encrypted header
copy(frame[512:512+jpeg_len], jpeg_data) // Copy JPEG data
// Remaining bytes are zero-padded

// 5. Send frame via USB
libusb_bulk_transfer(handle, 0x01, frame, 102400, &transferred, 5000)

// 6. Read acknowledgment (drain IN endpoint)
response: [512]u8
libusb_bulk_transfer(handle, 0x81, response[:], 512, &transferred, 1000)
```

## Video Playback

For playing video or animations on the LCD:

1. **Pre-process frames**:
   - Extract frames from video at target FPS
   - Resize each frame to 400x400
   - Encode as JPEG with consistent quality
   - Save frames as numbered files (frame_0001.jpg, frame_0002.jpg, etc.)

2. **Playback loop**:
   - Load each frame in sequence
   - Build and send complete frame (header + JPEG + padding)
   - Read acknowledgment from IN endpoint
   - Wait for frame interval (e.g., 33ms for 30fps)
   - Repeat for next frame

3. **Performance tips**:
   - Pre-load next frame while displaying current frame
   - Use double buffering
   - Monitor USB transfer times
   - Adjust FPS if frames are dropping

## Device Discovery

To find LCD devices on the USB bus:

```odin
// Enumerate all USB devices
devices := libusb_get_device_list(ctx, &list)

for each device in devices {
    desc := libusb_get_device_descriptor(device)

    // Check if this is an LCD controller
    if desc.idVendor == 0x1cbe && desc.idProduct == 0x0005 {
        bus := libusb_get_bus_number(device)
        address := libusb_get_device_address(device)

        // This is an LCD device
        // Store bus and address for later use
    }
}
```

## References

- Working Python implementation: `~/Code/fans/play_contra.py`
- Protocol documentation: `~/Code/fans/SUCCESS.md`
- Header generation: `~/Code/fans/generate_header.py`

## Revision History

- **2025-11-08**: Initial documentation
  - Documented LCD protocol based on reverse-engineered Python implementation
  - Clarified PKCS7 padding requirement
  - Added frame structure and encryption details
