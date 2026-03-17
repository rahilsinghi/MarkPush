/**
 * AES-256-GCM encryption/decryption using Node.js crypto module.
 *
 * Ciphertext format: nonce (12 bytes) || ciphertext || GCM auth tag (16 bytes),
 * then base64-standard-encoded. Must match the Go CLI and Swift iOS implementations.
 */

import { createCipheriv, createDecipheriv, randomBytes, pbkdf2Sync } from "node:crypto";

const KEY_SIZE = 32;
const NONCE_SIZE = 12;
const TAG_SIZE = 16;
const PBKDF2_ITERATIONS = 100_000;

/** Encrypt plaintext with AES-256-GCM. Returns base64-encoded ciphertext. */
export function encrypt(key: Buffer, plaintext: Buffer): string {
  if (key.length !== KEY_SIZE) {
    throw new Error(`Key must be ${KEY_SIZE} bytes, got ${key.length}`);
  }

  const nonce = randomBytes(NONCE_SIZE);
  const cipher = createCipheriv("aes-256-gcm", key, nonce);

  const encrypted = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const tag = cipher.getAuthTag();

  // Format: nonce || ciphertext || tag
  const combined = Buffer.concat([nonce, encrypted, tag]);
  return combined.toString("base64");
}

/** Decrypt base64-encoded AES-256-GCM ciphertext. */
export function decrypt(key: Buffer, encoded: string): Buffer {
  if (key.length !== KEY_SIZE) {
    throw new Error(`Key must be ${KEY_SIZE} bytes, got ${key.length}`);
  }

  const data = Buffer.from(encoded, "base64");
  if (data.length < NONCE_SIZE + TAG_SIZE) {
    throw new Error("Ciphertext too short");
  }

  const nonce = data.subarray(0, NONCE_SIZE);
  const ciphertext = data.subarray(NONCE_SIZE, data.length - TAG_SIZE);
  const tag = data.subarray(data.length - TAG_SIZE);

  const decipher = createDecipheriv("aes-256-gcm", key, nonce);
  decipher.setAuthTag(tag);

  return Buffer.concat([decipher.update(ciphertext), decipher.final()]);
}

/**
 * Derive a 32-byte key from a pairing secret using PBKDF2-SHA256.
 * Parameters match CLI and iOS: 100,000 iterations, 32-byte output.
 */
export function deriveKey(secret: string, salt: string): Buffer {
  if (!secret) throw new Error("Secret must not be empty");
  if (!salt) throw new Error("Salt must not be empty");

  return pbkdf2Sync(secret, salt, PBKDF2_ITERATIONS, KEY_SIZE, "sha256");
}
