/**
 * Config store that reads/writes ~/.config/markpush/.
 * Shared with the Go CLI — both read the same config.toml and device data.
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync, chmodSync } from "node:fs";
import { join } from "node:path";
import { homedir, hostname } from "node:os";
import { randomUUID } from "node:crypto";
import TOML from "@iarna/toml";

export interface Config {
  device_id: string;
  device_name: string;
  transport_mode: string;
  cloud?: {
    supabase_url?: string;
    supabase_key?: string;
    user_id?: string;
  };
  devices?: PairedDevice[];
}

export interface PairedDevice {
  id: string;
  name: string;
  key: string; // base64-encoded AES key
}

export interface PushHistoryEntry {
  id: string;
  title: string;
  word_count: number;
  timestamp: string;
  transport: string;
  device?: string;
}

const CONFIG_DIR_NAME = ".config/markpush";

/** Get the config directory path. */
export function configDir(): string {
  return join(homedir(), CONFIG_DIR_NAME);
}

/** Ensure the config directory exists with proper permissions. */
function ensureConfigDir(): void {
  const dir = configDir();
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true, mode: 0o700 });
  }
}

/** Load config from ~/.config/markpush/config.toml. */
export function loadConfig(): Config {
  ensureConfigDir();
  const path = join(configDir(), "config.toml");

  let cfg: Partial<Config> = {};

  if (existsSync(path)) {
    const content = readFileSync(path, "utf-8");
    cfg = TOML.parse(content) as unknown as Partial<Config>;
  }

  // Apply defaults.
  if (!cfg.device_id) {
    cfg.device_id = randomUUID();
    saveConfig(cfg as Config);
  }
  if (!cfg.device_name) {
    cfg.device_name = hostname();
  }
  if (!cfg.transport_mode) {
    cfg.transport_mode = "auto";
  }

  return cfg as Config;
}

/** Save config to ~/.config/markpush/config.toml. */
export function saveConfig(cfg: Config): void {
  ensureConfigDir();
  const path = join(configDir(), "config.toml");
  const content = TOML.stringify(cfg as unknown as TOML.JsonMap);
  writeFileSync(path, content, { mode: 0o600 });
}

/** Get the encryption key for the first paired device, or null. */
export function getPairedDeviceKey(cfg: Config): { key: Buffer; deviceId: string } | null {
  if (!cfg.devices || cfg.devices.length === 0) return null;
  const device = cfg.devices[0];
  return {
    key: Buffer.from(device.key, "base64"),
    deviceId: device.id,
  };
}

/** Add a paired device to the config. */
export function addPairedDevice(cfg: Config, device: PairedDevice): Config {
  const devices = cfg.devices ? [...cfg.devices] : [];
  devices.push(device);
  const updated = { ...cfg, devices };
  saveConfig(updated);
  return updated;
}

/** Remove a paired device from the config. */
export function removePairedDevice(cfg: Config, deviceId: string): Config {
  const devices = (cfg.devices ?? []).filter((d) => d.id !== deviceId);
  const updated = { ...cfg, devices };
  saveConfig(updated);
  return updated;
}

// --- Push history (simple JSON file) ---

const HISTORY_FILE = "history.json";

/** Load push history. */
export function loadHistory(): PushHistoryEntry[] {
  const path = join(configDir(), HISTORY_FILE);
  if (!existsSync(path)) return [];
  try {
    return JSON.parse(readFileSync(path, "utf-8"));
  } catch {
    return [];
  }
}

/** Append to push history. */
export function appendHistory(entry: PushHistoryEntry): void {
  ensureConfigDir();
  const entries = loadHistory();
  entries.unshift(entry); // newest first
  // Keep last 100 entries.
  const trimmed = entries.slice(0, 100);
  writeFileSync(join(configDir(), HISTORY_FILE), JSON.stringify(trimmed, null, 2), {
    mode: 0o600,
  });
}
