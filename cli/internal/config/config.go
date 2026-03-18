// Package config manages MarkPush CLI configuration stored in
// ~/.config/markpush/config.toml.
package config

import (
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/BurntSushi/toml"
	"github.com/google/uuid"
)

// ErrNoPairedDevice is returned when no paired device is found.
var ErrNoPairedDevice = errors.New("no paired device found")

// Config holds the CLI configuration.
type Config struct {
	DeviceID      string         `toml:"device_id"`
	DeviceName    string         `toml:"device_name"`
	TransportMode string         `toml:"transport_mode"` // "auto", "wifi", "cloud"
	Verbose       bool           `toml:"verbose"`
	ConfigDir     string         `toml:"-"` // not serialized

	Cloud   CloudConfig    `toml:"cloud"`
	Devices []PairedDevice `toml:"devices"`
}

// CloudConfig holds Supabase cloud relay configuration.
type CloudConfig struct {
	SupabaseURL string `toml:"supabase_url"`
	SupabaseKey string `toml:"supabase_key"`
	UserID      string `toml:"user_id"` // Supabase UUID of the target user
}

// PairedDevice represents a paired iOS device.
type PairedDevice struct {
	ID        string `toml:"id"`
	Name      string `toml:"name"`
	KeyBase64 string `toml:"key"`
}

// DefaultConfigDir returns the default config directory path.
func DefaultConfigDir() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("get home directory: %w", err)
	}
	return filepath.Join(home, ".config", "markpush"), nil
}

// Load reads configuration from the given path. If configDir is empty,
// the default config directory is used. Missing config files are handled
// by returning defaults.
func Load(configDir string) (*Config, error) {
	if configDir == "" {
		var err error
		configDir, err = DefaultConfigDir()
		if err != nil {
			return nil, fmt.Errorf("load config: %w", err)
		}
	}

	cfg := &Config{
		TransportMode: "auto",
		ConfigDir:     configDir,
	}

	// Set default device name from hostname.
	hostname, err := os.Hostname()
	if err == nil {
		cfg.DeviceName = hostname
	}

	configPath := filepath.Join(configDir, "config.toml")
	if _, err := os.Stat(configPath); err == nil {
		if _, err := toml.DecodeFile(configPath, cfg); err != nil {
			return nil, fmt.Errorf("load config: parse %s: %w", configPath, err)
		}
		cfg.ConfigDir = configDir
	}

	// Generate device ID on first run.
	if cfg.DeviceID == "" {
		cfg.DeviceID = uuid.New().String()
		if err := Save(cfg); err != nil {
			return nil, fmt.Errorf("load config: save initial config: %w", err)
		}
	}

	return cfg, nil
}

// Save writes the configuration to the config directory.
// Creates the directory with 0700 permissions if it doesn't exist.
// Writes the file with 0600 permissions.
func Save(cfg *Config) error {
	if err := os.MkdirAll(cfg.ConfigDir, 0700); err != nil {
		return fmt.Errorf("save config: create directory: %w", err)
	}

	configPath := filepath.Join(cfg.ConfigDir, "config.toml")
	f, err := os.OpenFile(configPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		return fmt.Errorf("save config: open file: %w", err)
	}
	defer f.Close()

	encoder := toml.NewEncoder(f)
	if err := encoder.Encode(cfg); err != nil {
		return fmt.Errorf("save config: encode: %w", err)
	}

	return nil
}

// LoadPairedDeviceKey returns the decrypted encryption key for the first
// paired device. Returns ErrNoPairedDevice if no devices are paired.
func LoadPairedDeviceKey(cfg *Config) ([]byte, error) {
	if len(cfg.Devices) == 0 {
		return nil, ErrNoPairedDevice
	}

	keyBytes, err := base64.StdEncoding.DecodeString(cfg.Devices[0].KeyBase64)
	if err != nil {
		return nil, fmt.Errorf("load paired device key: decode: %w", err)
	}

	return keyBytes, nil
}
