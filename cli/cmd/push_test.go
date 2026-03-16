package cmd

import (
	"encoding/base64"
	"encoding/json"
	"strings"
	"testing"

	"github.com/rahilsinghi/markpush/cli/internal/config"
	"github.com/rahilsinghi/markpush/cli/internal/protocol"
)

func TestBuildPushMessage_FromReader(t *testing.T) {
	input := strings.NewReader("# Hello\n\nSome words here")
	opts := pushOptions{}
	cfg := &config.Config{DeviceID: "test-device", DeviceName: "TestHost"}

	msg, err := buildPushMessage(input, opts, cfg)
	if err != nil {
		t.Fatalf("buildPushMessage: %v", err)
	}

	if msg.Title != "Hello" {
		t.Errorf("Title = %q, want %q", msg.Title, "Hello")
	}
	if msg.WordCount != 5 {
		t.Errorf("WordCount = %d, want 5", msg.WordCount)
	}
	if msg.SenderID != "test-device" {
		t.Errorf("SenderID = %q, want %q", msg.SenderID, "test-device")
	}
	if msg.Encrypted {
		t.Error("should not be encrypted without paired device")
	}
}

func TestBuildPushMessage_TitleOverride(t *testing.T) {
	input := strings.NewReader("# Original")
	opts := pushOptions{Title: "Override"}
	cfg := &config.Config{DeviceID: "d", DeviceName: "h"}

	msg, err := buildPushMessage(input, opts, cfg)
	if err != nil {
		t.Fatalf("buildPushMessage: %v", err)
	}

	if msg.Title != "Override" {
		t.Errorf("Title = %q, want %q", msg.Title, "Override")
	}
}

func TestBuildPushMessage_Tags(t *testing.T) {
	input := strings.NewReader("content")
	opts := pushOptions{Tags: []string{"backend", "auth"}}
	cfg := &config.Config{DeviceID: "d", DeviceName: "h"}

	msg, err := buildPushMessage(input, opts, cfg)
	if err != nil {
		t.Fatalf("buildPushMessage: %v", err)
	}

	if len(msg.Tags) != 2 || msg.Tags[0] != "backend" || msg.Tags[1] != "auth" {
		t.Errorf("Tags = %v, want [backend auth]", msg.Tags)
	}
}

func TestBuildPushMessage_Source(t *testing.T) {
	input := strings.NewReader("content")
	opts := pushOptions{Source: "claude"}
	cfg := &config.Config{DeviceID: "d", DeviceName: "h"}

	msg, err := buildPushMessage(input, opts, cfg)
	if err != nil {
		t.Fatalf("buildPushMessage: %v", err)
	}

	if msg.Source != "claude" {
		t.Errorf("Source = %q, want %q", msg.Source, "claude")
	}
}

func TestBuildPushMessage_EmptyInput(t *testing.T) {
	input := strings.NewReader("")
	opts := pushOptions{}
	cfg := &config.Config{DeviceID: "d", DeviceName: "h"}

	msg, err := buildPushMessage(input, opts, cfg)
	if err != nil {
		t.Fatalf("buildPushMessage: %v", err)
	}

	if msg.Title != "Untitled" {
		t.Errorf("Title = %q, want %q", msg.Title, "Untitled")
	}
	if msg.WordCount != 0 {
		t.Errorf("WordCount = %d, want 0", msg.WordCount)
	}
}

func TestBuildPushMessage_Encryption(t *testing.T) {
	content := "# Secret Doc"
	input := strings.NewReader(content)

	// Create a config with a paired device key.
	key := make([]byte, 32)
	for i := range key {
		key[i] = byte(i)
	}

	opts := pushOptions{}
	cfg := &config.Config{
		DeviceID:   "d",
		DeviceName: "h",
		Devices: []config.PairedDevice{
			{ID: "iphone", Name: "iPhone", KeyBase64: base64.StdEncoding.EncodeToString(key)},
		},
	}

	msg, err := buildPushMessage(input, opts, cfg)
	if err != nil {
		t.Fatalf("buildPushMessage: %v", err)
	}

	if !msg.Encrypted {
		t.Error("Encrypted should be true when key is available")
	}

	// The content should be different from plain base64.
	plainBase64 := base64.StdEncoding.EncodeToString([]byte(content))
	if msg.Content == plainBase64 {
		t.Error("encrypted content should differ from plain base64")
	}
}

func TestBuildPushMessage_NoEncryptionKey(t *testing.T) {
	content := "# Hello"
	input := strings.NewReader(content)
	opts := pushOptions{}
	cfg := &config.Config{DeviceID: "d", DeviceName: "h"}

	msg, err := buildPushMessage(input, opts, cfg)
	if err != nil {
		t.Fatalf("buildPushMessage: %v", err)
	}

	if msg.Encrypted {
		t.Error("Encrypted should be false without paired device")
	}

	decoded, err := base64.StdEncoding.DecodeString(msg.Content)
	if err != nil {
		t.Fatalf("decode content: %v", err)
	}
	if string(decoded) != content {
		t.Errorf("decoded content = %q, want %q", decoded, content)
	}
}

func TestBuildPushMessage_ContentRoundTrip(t *testing.T) {
	content := "# Full Document\n\nWith **markdown** and `code`.\n\n```go\nfunc main() {}\n```"
	input := strings.NewReader(content)
	opts := pushOptions{}
	cfg := &config.Config{DeviceID: "d", DeviceName: "h"}

	msg, err := buildPushMessage(input, opts, cfg)
	if err != nil {
		t.Fatalf("buildPushMessage: %v", err)
	}

	decoded, err := base64.StdEncoding.DecodeString(msg.Content)
	if err != nil {
		t.Fatalf("decode: %v", err)
	}
	if string(decoded) != content {
		t.Errorf("round-trip content mismatch")
	}
}

func TestBuildPushMessage_ValidJSON(t *testing.T) {
	input := strings.NewReader("# Test")
	opts := pushOptions{Tags: []string{"a"}, Source: "test"}
	cfg := &config.Config{DeviceID: "d", DeviceName: "h"}

	msg, err := buildPushMessage(input, opts, cfg)
	if err != nil {
		t.Fatalf("buildPushMessage: %v", err)
	}

	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}

	var decoded protocol.PushMessage
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if decoded.Title != "Test" {
		t.Errorf("JSON round-trip title = %q, want %q", decoded.Title, "Test")
	}
}

func TestResolveTransportMode(t *testing.T) {
	tests := []struct {
		name string
		opts pushOptions
		want string
	}{
		{"dry-run", pushOptions{DryRun: true}, "dry-run"},
		{"wifi", pushOptions{ForceWiFi: true}, "wifi"},
		{"cloud", pushOptions{ForceCloud: true}, "cloud"},
		{"auto", pushOptions{}, "auto"},
		{"dry-run wins", pushOptions{DryRun: true, ForceWiFi: true}, "dry-run"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := resolveTransportMode(tt.opts)
			if got != tt.want {
				t.Errorf("resolveTransportMode() = %q, want %q", got, tt.want)
			}
		})
	}
}
