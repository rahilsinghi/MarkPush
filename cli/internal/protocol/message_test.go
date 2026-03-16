package protocol

import (
	"encoding/base64"
	"encoding/json"
	"testing"
	"time"
)

func TestNewPushMessage(t *testing.T) {
	content := []byte("# Hello\n\nSome words here")
	msg := NewPushMessage("", content, []string{"test"}, "claude", "sender-1", "MacBook")

	if msg.Version != ProtocolVersion {
		t.Errorf("Version = %q, want %q", msg.Version, ProtocolVersion)
	}
	if msg.Type != MessageTypePush {
		t.Errorf("Type = %q, want %q", msg.Type, MessageTypePush)
	}
	if msg.ID == "" {
		t.Error("ID should not be empty")
	}
	if time.Since(msg.Timestamp) > 5*time.Second {
		t.Error("Timestamp should be recent")
	}
	if msg.Title != "Hello" {
		t.Errorf("Title = %q, want %q", msg.Title, "Hello")
	}
	if msg.WordCount != 5 {
		t.Errorf("WordCount = %d, want 5", msg.WordCount)
	}
	if msg.Encrypted {
		t.Error("Encrypted should be false by default")
	}

	decoded, err := base64.StdEncoding.DecodeString(msg.Content)
	if err != nil {
		t.Fatalf("Content is not valid base64: %v", err)
	}
	if string(decoded) != string(content) {
		t.Errorf("Decoded content = %q, want %q", decoded, content)
	}
}

func TestNewPushMessage_ExplicitTitle(t *testing.T) {
	msg := NewPushMessage("Override", []byte("# Ignored"), nil, "", "s", "n")
	if msg.Title != "Override" {
		t.Errorf("Title = %q, want %q", msg.Title, "Override")
	}
}

func TestPushMessageJSON_RoundTrip(t *testing.T) {
	msg := NewPushMessage("Test", []byte("content"), []string{"a", "b"}, "claude", "s1", "host")

	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	// Verify JSON keys match the contract.
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}
	requiredKeys := []string{"version", "type", "id", "timestamp", "title", "word_count", "content", "encrypted", "sender_id", "sender_name"}
	for _, key := range requiredKeys {
		if _, ok := raw[key]; !ok {
			t.Errorf("JSON missing required key %q", key)
		}
	}

	var decoded PushMessage
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if decoded.Title != msg.Title {
		t.Errorf("round-trip Title = %q, want %q", decoded.Title, msg.Title)
	}
	if decoded.WordCount != msg.WordCount {
		t.Errorf("round-trip WordCount = %d, want %d", decoded.WordCount, msg.WordCount)
	}
}

func TestAckMessageJSON_RoundTrip(t *testing.T) {
	msg := AckMessage{
		Version:   ProtocolVersion,
		Type:      MessageTypeAck,
		ID:        "ack-1",
		Timestamp: time.Now(),
		RefID:     "push-1",
		Status:    "received",
	}

	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}
	for _, key := range []string{"ref_id", "status"} {
		if _, ok := raw[key]; !ok {
			t.Errorf("JSON missing required key %q", key)
		}
	}

	var decoded AckMessage
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if decoded.RefID != msg.RefID {
		t.Errorf("round-trip RefID = %q, want %q", decoded.RefID, msg.RefID)
	}
}

func TestPairInitMessageJSON_RoundTrip(t *testing.T) {
	msg := PairInitMessage{
		Version:    "1",
		Secret:     "c2VjcmV0",
		Host:       "192.168.1.42",
		Port:       54321,
		SenderID:   "cli-1",
		SenderName: "MacBook",
	}

	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	// Verify short JSON keys.
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("Unmarshal to map: %v", err)
	}
	for _, key := range []string{"v", "s", "h", "p", "id", "name"} {
		if _, ok := raw[key]; !ok {
			t.Errorf("JSON missing short key %q", key)
		}
	}

	var decoded PairInitMessage
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal: %v", err)
	}
	if decoded.Port != msg.Port {
		t.Errorf("round-trip Port = %d, want %d", decoded.Port, msg.Port)
	}
}

func TestExtractTitle(t *testing.T) {
	tests := []struct {
		name     string
		markdown string
		want     string
	}{
		{"H1 heading", "# Hello World\nBody text", "Hello World"},
		{"only H2", "## Only H2\nBody", "Untitled"},
		{"no heading", "Just plain text", "Untitled"},
		{"first of multiple H1s", "# First\n# Second", "First"},
		{"whitespace before hash", "   # Indented", "Untitled"}, // indented code, not a heading
		{"empty input", "", "Untitled"},
		{"H1 with extra spaces", "#   Spacey Title  ", "Spacey Title"},
		{"H1 after content", "Some text\n# Late Heading", "Late Heading"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ExtractTitle([]byte(tt.markdown))
			if got != tt.want {
				t.Errorf("ExtractTitle() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestCountWords(t *testing.T) {
	tests := []struct {
		name     string
		markdown string
		want     int
	}{
		{"simple", "hello world", 2},
		{"with heading", "# Heading\n\nParagraph with five words here", 7},
		{"empty", "", 0},
		{"whitespace only", "   \n\n  \t  ", 0},
		{"single word", "hello", 1},
		{"code block", "```go\nfunc main() {}\n```", 5},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := CountWords([]byte(tt.markdown))
			if got != tt.want {
				t.Errorf("CountWords() = %d, want %d", got, tt.want)
			}
		})
	}
}
