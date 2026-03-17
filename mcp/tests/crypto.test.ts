import { describe, it, expect } from "vitest";
import { encrypt, decrypt, deriveKey } from "../src/crypto/aes.js";
import { randomBytes } from "node:crypto";

describe("AES-256-GCM", () => {
  const key = randomBytes(32);

  it("encrypt/decrypt round-trip", () => {
    const plaintext = Buffer.from("# Hello World\n\nThis is **markdown**.");
    const encrypted = encrypt(key, plaintext);
    const decrypted = decrypt(key, encrypted);
    expect(decrypted.toString("utf-8")).toBe(plaintext.toString("utf-8"));
  });

  it("encrypts empty content", () => {
    const encrypted = encrypt(key, Buffer.from(""));
    const decrypted = decrypt(key, encrypted);
    expect(decrypted.toString("utf-8")).toBe("");
  });

  it("produces different ciphertext for same plaintext", () => {
    const plaintext = Buffer.from("same content");
    const a = encrypt(key, plaintext);
    const b = encrypt(key, plaintext);
    expect(a).not.toBe(b);
  });

  it("rejects invalid key length", () => {
    expect(() => encrypt(Buffer.alloc(16), Buffer.from("test"))).toThrow();
    expect(() => encrypt(Buffer.alloc(33), Buffer.from("test"))).toThrow();
  });

  it("rejects tampered ciphertext", () => {
    const encrypted = encrypt(key, Buffer.from("secret"));
    const data = Buffer.from(encrypted, "base64");
    data[data.length - 1] ^= 0xff;
    expect(() => decrypt(key, data.toString("base64"))).toThrow();
  });

  it("rejects wrong key", () => {
    const encrypted = encrypt(key, Buffer.from("secret"));
    const wrongKey = randomBytes(32);
    expect(() => decrypt(wrongKey, encrypted)).toThrow();
  });

  it("output has correct format: nonce(12) + ciphertext + tag(16)", () => {
    const encrypted = encrypt(key, Buffer.from("test"));
    const data = Buffer.from(encrypted, "base64");
    // Minimum: 12 (nonce) + 0 (empty plaintext would still have tag) + 16 (tag) = 28
    expect(data.length).toBeGreaterThanOrEqual(28);
  });
});

describe("PBKDF2 key derivation", () => {
  it("produces deterministic output", () => {
    const a = deriveKey("secret", "salt");
    const b = deriveKey("secret", "salt");
    expect(a.equals(b)).toBe(true);
  });

  it("produces 32-byte key", () => {
    const key = deriveKey("secret", "salt");
    expect(key.length).toBe(32);
  });

  it("different salts produce different keys", () => {
    const a = deriveKey("secret", "salt-a");
    const b = deriveKey("secret", "salt-b");
    expect(a.equals(b)).toBe(false);
  });

  it("rejects empty inputs", () => {
    expect(() => deriveKey("", "salt")).toThrow();
    expect(() => deriveKey("secret", "")).toThrow();
  });
});
