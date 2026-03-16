package config

import (
	"encoding/base64"
	"os"
	"path/filepath"
	"testing"
)

func TestLoad_DefaultsWhenNoFile(t *testing.T) {
	dir := t.TempDir()
	cfg, err := Load(dir)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}

	if cfg.DeviceID == "" {
		t.Error("DeviceID should be auto-generated")
	}
	if cfg.TransportMode != "auto" {
		t.Errorf("TransportMode = %q, want %q", cfg.TransportMode, "auto")
	}
	if cfg.DeviceName == "" {
		t.Error("DeviceName should default to hostname")
	}
	if cfg.ConfigDir != dir {
		t.Errorf("ConfigDir = %q, want %q", cfg.ConfigDir, dir)
	}
}

func TestLoad_FromTOMLFile(t *testing.T) {
	dir := t.TempDir()
	content := `device_id = "custom-id"
device_name = "CustomHost"
transport_mode = "wifi"
`
	if err := os.WriteFile(filepath.Join(dir, "config.toml"), []byte(content), 0600); err != nil {
		t.Fatalf("write config: %v", err)
	}

	cfg, err := Load(dir)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}

	if cfg.DeviceID != "custom-id" {
		t.Errorf("DeviceID = %q, want %q", cfg.DeviceID, "custom-id")
	}
	if cfg.DeviceName != "CustomHost" {
		t.Errorf("DeviceName = %q, want %q", cfg.DeviceName, "CustomHost")
	}
	if cfg.TransportMode != "wifi" {
		t.Errorf("TransportMode = %q, want %q", cfg.TransportMode, "wifi")
	}
}

func TestLoad_CreatesConfigDir(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "nested", "config")
	cfg, err := Load(dir)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}

	// Should have created the directory (via Save for device ID).
	info, err := os.Stat(dir)
	if err != nil {
		t.Fatalf("Stat config dir: %v", err)
	}
	if !info.IsDir() {
		t.Error("config dir should be a directory")
	}
	if cfg.DeviceID == "" {
		t.Error("DeviceID should be auto-generated")
	}
}

func TestSave_RoundTrip(t *testing.T) {
	dir := t.TempDir()
	original, err := Load(dir)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}

	original.TransportMode = "cloud"
	if err := Save(original); err != nil {
		t.Fatalf("Save: %v", err)
	}

	reloaded, err := Load(dir)
	if err != nil {
		t.Fatalf("Load after save: %v", err)
	}

	if reloaded.DeviceID != original.DeviceID {
		t.Errorf("DeviceID = %q, want %q", reloaded.DeviceID, original.DeviceID)
	}
	if reloaded.TransportMode != "cloud" {
		t.Errorf("TransportMode = %q, want %q", reloaded.TransportMode, "cloud")
	}
}

func TestSave_FilePermissions(t *testing.T) {
	dir := t.TempDir()
	cfg := &Config{
		DeviceID:      "test",
		TransportMode: "auto",
		ConfigDir:     dir,
	}

	if err := Save(cfg); err != nil {
		t.Fatalf("Save: %v", err)
	}

	info, err := os.Stat(filepath.Join(dir, "config.toml"))
	if err != nil {
		t.Fatalf("Stat: %v", err)
	}

	perm := info.Mode().Perm()
	if perm != 0600 {
		t.Errorf("file permissions = %o, want 0600", perm)
	}
}

func TestLoadPairedDeviceKey_NoPairedDevice(t *testing.T) {
	cfg := &Config{}
	_, err := LoadPairedDeviceKey(cfg)
	if err != ErrNoPairedDevice {
		t.Errorf("error = %v, want ErrNoPairedDevice", err)
	}
}

func TestLoadPairedDeviceKey_WithPairedDevice(t *testing.T) {
	key := make([]byte, 32)
	for i := range key {
		key[i] = byte(i)
	}
	encoded := base64.StdEncoding.EncodeToString(key)

	cfg := &Config{
		Devices: []PairedDevice{
			{ID: "dev-1", Name: "iPhone", KeyBase64: encoded},
		},
	}

	got, err := LoadPairedDeviceKey(cfg)
	if err != nil {
		t.Fatalf("LoadPairedDeviceKey: %v", err)
	}
	if len(got) != 32 {
		t.Errorf("key length = %d, want 32", len(got))
	}
	if got[0] != 0 || got[31] != 31 {
		t.Error("key bytes don't match expected values")
	}
}

func TestLoadPairedDeviceKey_InvalidBase64(t *testing.T) {
	cfg := &Config{
		Devices: []PairedDevice{
			{ID: "dev-1", Name: "iPhone", KeyBase64: "!!!invalid!!!"},
		},
	}
	_, err := LoadPairedDeviceKey(cfg)
	if err == nil {
		t.Error("expected error for invalid base64 key")
	}
}

func TestLoad_CloudConfig(t *testing.T) {
	dir := t.TempDir()
	content := `device_id = "test"
device_name = "Host"
transport_mode = "cloud"

[cloud]
supabase_url = "https://test.supabase.co"
supabase_key = "test-key"

[[devices]]
id = "iphone-1"
name = "iPhone"
key = "dGVzdA=="
`
	if err := os.WriteFile(filepath.Join(dir, "config.toml"), []byte(content), 0600); err != nil {
		t.Fatalf("write config: %v", err)
	}

	cfg, err := Load(dir)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}

	if cfg.Cloud.SupabaseURL != "https://test.supabase.co" {
		t.Errorf("SupabaseURL = %q, want %q", cfg.Cloud.SupabaseURL, "https://test.supabase.co")
	}
	if len(cfg.Devices) != 1 {
		t.Errorf("Devices count = %d, want 1", len(cfg.Devices))
	}
	if cfg.Devices[0].Name != "iPhone" {
		t.Errorf("Device name = %q, want %q", cfg.Devices[0].Name, "iPhone")
	}
}

func TestLoad_InvalidTOML(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "config.toml"), []byte("{{invalid toml"), 0600); err != nil {
		t.Fatalf("write config: %v", err)
	}

	_, err := Load(dir)
	if err == nil {
		t.Error("expected error for invalid TOML")
	}
}

func TestDefaultConfigDir(t *testing.T) {
	dir, err := DefaultConfigDir()
	if err != nil {
		t.Fatalf("DefaultConfigDir: %v", err)
	}
	if dir == "" {
		t.Error("DefaultConfigDir should not return empty string")
	}
	if !filepath.IsAbs(dir) {
		t.Errorf("DefaultConfigDir should return absolute path, got %q", dir)
	}
}

func TestSave_DirPermissions(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "new-dir")
	cfg := &Config{
		DeviceID:      "test",
		TransportMode: "auto",
		ConfigDir:     dir,
	}

	if err := Save(cfg); err != nil {
		t.Fatalf("Save: %v", err)
	}

	info, err := os.Stat(dir)
	if err != nil {
		t.Fatalf("Stat: %v", err)
	}

	perm := info.Mode().Perm()
	if perm != 0700 {
		t.Errorf("dir permissions = %o, want 0700", perm)
	}
}
