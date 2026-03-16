// Package crypto provides AES-256-GCM encryption and PBKDF2 key derivation
// for the MarkPush protocol.
//
// Ciphertext format: nonce (12 bytes) || ciphertext || GCM auth tag (16 bytes),
// then base64-standard-encoded. Both CLI and iOS must use this same format.
package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"io"

	"golang.org/x/crypto/pbkdf2"
)

const (
	// KeySize is the required key length in bytes (256 bits).
	KeySize = 32
	// PBKDF2Iterations is the number of PBKDF2 iterations for key derivation.
	PBKDF2Iterations = 100_000
)

// Encrypt encrypts plaintext with AES-256-GCM.
// Key must be exactly 32 bytes. Returns base64-encoded ciphertext.
func Encrypt(key, plaintext []byte) (string, error) {
	if len(key) != KeySize {
		return "", fmt.Errorf("encrypt: key must be %d bytes, got %d", KeySize, len(key))
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return "", fmt.Errorf("encrypt: create cipher: %w", err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", fmt.Errorf("encrypt: create GCM: %w", err)
	}

	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", fmt.Errorf("encrypt: generate nonce: %w", err)
	}

	// Seal appends ciphertext+tag to nonce, producing: nonce || ciphertext || tag
	ciphertext := gcm.Seal(nonce, nonce, plaintext, nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// Decrypt decrypts a base64-encoded AES-256-GCM ciphertext.
// Key must be exactly 32 bytes. The encoded string must contain
// the nonce prepended to the ciphertext.
func Decrypt(key []byte, encoded string) ([]byte, error) {
	if len(key) != KeySize {
		return nil, fmt.Errorf("decrypt: key must be %d bytes, got %d", KeySize, len(key))
	}

	data, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return nil, fmt.Errorf("decrypt: base64 decode: %w", err)
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("decrypt: create cipher: %w", err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("decrypt: create GCM: %w", err)
	}

	nonceSize := gcm.NonceSize()
	if len(data) < nonceSize {
		return nil, errors.New("decrypt: ciphertext too short")
	}

	nonce, ciphertext := data[:nonceSize], data[nonceSize:]
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return nil, fmt.Errorf("decrypt: authentication failed: %w", err)
	}

	return plaintext, nil
}

// DeriveKey derives a 32-byte encryption key from a pairing secret and salt
// using PBKDF2 with SHA-256.
func DeriveKey(secret string, salt []byte) ([]byte, error) {
	if secret == "" {
		return nil, errors.New("derive key: secret must not be empty")
	}
	if len(salt) == 0 {
		return nil, errors.New("derive key: salt must not be empty")
	}

	key := pbkdf2.Key([]byte(secret), salt, PBKDF2Iterations, KeySize, sha256.New)
	return key, nil
}
