package crypto

import (
	"crypto/rand"
	"encoding/base64"
	"strings"
	"testing"
)

func randomKey(t *testing.T) []byte {
	t.Helper()
	key := make([]byte, KeySize)
	if _, err := rand.Read(key); err != nil {
		t.Fatalf("generate random key: %v", err)
	}
	return key
}

func TestEncryptDecrypt_RoundTrip(t *testing.T) {
	tests := []struct {
		name      string
		plaintext string
	}{
		{"empty", ""},
		{"short", "hello"},
		{"markdown", "# Hello World\n\nThis is a **test** document with `code`."},
		{"long", strings.Repeat("Lorem ipsum dolor sit amet. ", 100)},
	}

	key := randomKey(t)

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			encrypted, err := Encrypt(key, []byte(tt.plaintext))
			if err != nil {
				t.Fatalf("Encrypt: %v", err)
			}

			decrypted, err := Decrypt(key, encrypted)
			if err != nil {
				t.Fatalf("Decrypt: %v", err)
			}

			if string(decrypted) != tt.plaintext {
				t.Errorf("round-trip failed: got %q, want %q", decrypted, tt.plaintext)
			}
		})
	}
}

func TestEncrypt_DifferentNonces(t *testing.T) {
	key := randomKey(t)
	plaintext := []byte("same content")

	a, err := Encrypt(key, plaintext)
	if err != nil {
		t.Fatalf("Encrypt a: %v", err)
	}
	b, err := Encrypt(key, plaintext)
	if err != nil {
		t.Fatalf("Encrypt b: %v", err)
	}

	if a == b {
		t.Error("encrypting same plaintext twice should produce different ciphertexts (random nonce)")
	}
}

func TestEncrypt_InvalidKeyLength(t *testing.T) {
	tests := []struct {
		name    string
		keySize int
	}{
		{"empty", 0},
		{"16 bytes", 16},
		{"31 bytes", 31},
		{"33 bytes", 33},
		{"64 bytes", 64},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			key := make([]byte, tt.keySize)
			_, err := Encrypt(key, []byte("test"))
			if err == nil {
				t.Error("expected error for invalid key length")
			}
		})
	}
}

func TestDecrypt_InvalidInput(t *testing.T) {
	key := randomKey(t)

	tests := []struct {
		name    string
		encoded string
	}{
		{"empty string", ""},
		{"not base64", "!!!not-base64!!!"},
		{"too short", base64.StdEncoding.EncodeToString([]byte("short"))},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := Decrypt(key, tt.encoded)
			if err == nil {
				t.Error("expected error for invalid input")
			}
		})
	}
}

func TestDecrypt_TamperedCiphertext(t *testing.T) {
	key := randomKey(t)
	encrypted, err := Encrypt(key, []byte("sensitive data"))
	if err != nil {
		t.Fatalf("Encrypt: %v", err)
	}

	// Flip a byte in the ciphertext.
	data, _ := base64.StdEncoding.DecodeString(encrypted)
	data[len(data)-1] ^= 0xFF
	tampered := base64.StdEncoding.EncodeToString(data)

	_, err = Decrypt(key, tampered)
	if err == nil {
		t.Error("expected error when decrypting tampered ciphertext")
	}
}

func TestDecrypt_WrongKey(t *testing.T) {
	keyA := randomKey(t)
	keyB := randomKey(t)

	encrypted, err := Encrypt(keyA, []byte("secret"))
	if err != nil {
		t.Fatalf("Encrypt: %v", err)
	}

	_, err = Decrypt(keyB, encrypted)
	if err == nil {
		t.Error("expected error when decrypting with wrong key")
	}
}

func TestDeriveKey_Deterministic(t *testing.T) {
	secret := "test-secret"
	salt := []byte("test-salt")

	a, err := DeriveKey(secret, salt)
	if err != nil {
		t.Fatalf("DeriveKey a: %v", err)
	}
	b, err := DeriveKey(secret, salt)
	if err != nil {
		t.Fatalf("DeriveKey b: %v", err)
	}

	if string(a) != string(b) {
		t.Error("same inputs should produce same key")
	}
}

func TestDeriveKey_DifferentSalts(t *testing.T) {
	secret := "test-secret"

	a, err := DeriveKey(secret, []byte("salt-a"))
	if err != nil {
		t.Fatalf("DeriveKey a: %v", err)
	}
	b, err := DeriveKey(secret, []byte("salt-b"))
	if err != nil {
		t.Fatalf("DeriveKey b: %v", err)
	}

	if string(a) == string(b) {
		t.Error("different salts should produce different keys")
	}
}

func TestDeriveKey_EmptyInputs(t *testing.T) {
	if _, err := DeriveKey("", []byte("salt")); err == nil {
		t.Error("expected error for empty secret")
	}
	if _, err := DeriveKey("secret", nil); err == nil {
		t.Error("expected error for nil salt")
	}
	if _, err := DeriveKey("secret", []byte{}); err == nil {
		t.Error("expected error for empty salt")
	}
}

func TestDeriveKey_Length(t *testing.T) {
	key, err := DeriveKey("secret", []byte("salt"))
	if err != nil {
		t.Fatalf("DeriveKey: %v", err)
	}
	if len(key) != KeySize {
		t.Errorf("key length = %d, want %d", len(key), KeySize)
	}
}

func TestEncrypt_NonceLayout(t *testing.T) {
	key := randomKey(t)
	encrypted, err := Encrypt(key, []byte("test"))
	if err != nil {
		t.Fatalf("Encrypt: %v", err)
	}

	data, err := base64.StdEncoding.DecodeString(encrypted)
	if err != nil {
		t.Fatalf("base64 decode: %v", err)
	}

	// AES-GCM nonce is 12 bytes. Minimum output: 12 (nonce) + 0 (plaintext) + 16 (tag) = 28
	if len(data) < 28 {
		t.Errorf("ciphertext too short: %d bytes, expected at least 28", len(data))
	}
}
