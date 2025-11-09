package main

import "core:testing"
import "core:fmt"
import des "../libs/des"

// Test DES PKCS7 padding
@(test)
test_pkcs7_padding :: proc(t: ^testing.T) {
	// Test padding 504 bytes to 512
	data := make([]u8, 504)
	defer delete(data)

	padded := des.pkcs7_pad(data, des.DES_BLOCK_SIZE)
	defer delete(padded)

	testing.expect(t, len(padded) == 512, "504 bytes should pad to 512 bytes")

	// Last 8 bytes should all be 0x08
	for i in 504..<512 {
		testing.expect(t, padded[i] == 0x08, "PKCS7 padding should be 0x08")
	}
}

// Test DES PKCS7 unpadding
@(test)
test_pkcs7_unpadding :: proc(t: ^testing.T) {
	// Create data with PKCS7 padding
	padded := make([]u8, 512)
	defer delete(padded)

	// Fill first 504 bytes with test data
	for i in 0..<504 {
		padded[i] = u8(i % 256)
	}

	// Add PKCS7 padding (8 bytes of 0x08)
	for i in 504..<512 {
		padded[i] = 0x08
	}

	// Unpad
	unpadded, ok := des.pkcs7_unpad(padded)
	testing.expect(t, ok, "Unpadding should succeed")
	testing.expect(t, len(unpadded) == 504, "Should unpad to 504 bytes")

	// Verify data matches
	for i in 0..<504 {
		testing.expect(t, unpadded[i] == u8(i % 256), "Data should match after unpadding")
	}
}

// Test DES encryption/decryption roundtrip
@(test)
test_des_cbc_roundtrip :: proc(t: ^testing.T) {
	key := [8]u8{0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08}
	iv := [8]u8{0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}

	// Test data (must be multiple of 8 bytes for DES)
	plaintext := [16]u8{
		0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x44, 0x45,
		0x53, 0x20, 0x54, 0x65, 0x73, 0x74, 0x21, 0x00,
	}

	// Encrypt
	ciphertext := make([]u8, len(plaintext))
	defer delete(ciphertext)
	des.des_cbc_encrypt(plaintext[:], ciphertext, key[:], iv[:])

	// Decrypt
	decrypted := make([]u8, len(plaintext))
	defer delete(decrypted)
	des.des_cbc_decrypt(ciphertext, decrypted, key[:], iv[:])

	// Verify
	for i in 0..<len(plaintext) {
		testing.expect(t, decrypted[i] == plaintext[i], "Decrypted data should match plaintext")
	}
}

// Test DES encryption produces different output than plaintext
@(test)
test_des_encryption_changes_data :: proc(t: ^testing.T) {
	key := [8]u8{'s', 'l', 'v', '3', 't', 'u', 'z', 'x'}
	iv := key

	plaintext := make([]u8, 512)
	defer delete(plaintext)

	// Fill with known pattern
	for i in 0..<len(plaintext) {
		plaintext[i] = u8(i % 256)
	}

	// Encrypt
	ciphertext := make([]u8, len(plaintext))
	defer delete(ciphertext)
	des.des_cbc_encrypt(plaintext, ciphertext, key[:], iv[:])

	// Ciphertext should be different from plaintext
	all_same := true
	for i in 0..<len(plaintext) {
		if ciphertext[i] != plaintext[i] {
			all_same = false
			break
		}
	}

	testing.expect(t, !all_same, "Ciphertext should be different from plaintext")
}

// Test LCD protocol constants
@(test)
test_lcd_protocol_constants :: proc(t: ^testing.T) {
	// DES block size
	testing.expect(t, des.DES_BLOCK_SIZE == 8, "DES block size should be 8 bytes")

	// Expected sizes for LCD protocol
	EXPECTED_HEADER_SIZE :: 512
	EXPECTED_FRAME_SIZE :: 102400
	EXPECTED_MAX_JPEG_SIZE :: 101888

	testing.expect(t, EXPECTED_HEADER_SIZE == 512, "Header should be 512 bytes")
	testing.expect(t, EXPECTED_FRAME_SIZE == 102400, "Frame should be 102400 bytes")
	testing.expect(t, EXPECTED_MAX_JPEG_SIZE == EXPECTED_FRAME_SIZE - EXPECTED_HEADER_SIZE,
		"Max JPEG size should be frame size minus header size")
}

// Test PKCS7 padding edge case - data already multiple of block size
@(test)
test_pkcs7_padding_full_block :: proc(t: ^testing.T) {
	// 512 bytes (already multiple of 8)
	data := make([]u8, 512)
	defer delete(data)

	padded := des.pkcs7_pad(data, des.DES_BLOCK_SIZE)
	defer delete(padded)

	// Should add a full block of padding (8 bytes)
	testing.expect(t, len(padded) == 520, "512 bytes should pad to 520 bytes (add full block)")

	// All padding bytes should be 0x08
	for i in 512..<520 {
		testing.expect(t, padded[i] == 0x08, "PKCS7 padding should be 0x08")
	}
}
