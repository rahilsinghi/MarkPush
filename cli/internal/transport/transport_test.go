package transport

import (
	"bytes"
	"context"
	"encoding/json"
	"strings"
	"testing"

	"github.com/rahilsinghi/markpush/cli/internal/protocol"
)

func testMessage() *protocol.PushMessage {
	msg := protocol.NewPushMessage("Test", []byte("# Test\n\nHello world"), nil, "test", "s1", "host")
	return &msg
}

func TestDryRunTransport_Send(t *testing.T) {
	var buf bytes.Buffer
	tr := NewDryRunTransport(&buf)
	msg := testMessage()

	if err := tr.Send(context.Background(), msg); err != nil {
		t.Fatalf("Send: %v", err)
	}

	output := buf.String()
	if !strings.Contains(output, "dry-run") {
		t.Error("output should contain 'dry-run' header")
	}

	lines := strings.SplitN(output, "\n", 2)
	if len(lines) < 2 {
		t.Fatal("output should have header + JSON")
	}

	var decoded protocol.PushMessage
	if err := json.Unmarshal([]byte(lines[1]), &decoded); err != nil {
		t.Fatalf("output is not valid JSON: %v", err)
	}
	if decoded.Title != "Test" {
		t.Errorf("Title = %q, want %q", decoded.Title, "Test")
	}
}

func TestSelect_DryRun(t *testing.T) {
	tr, err := Select("dry-run", Options{})
	if err != nil {
		t.Fatalf("Select: %v", err)
	}
	if _, ok := tr.(*DryRunTransport); !ok {
		t.Errorf("expected *DryRunTransport, got %T", tr)
	}
}

func TestSelect_WiFi(t *testing.T) {
	tr, err := Select("wifi", Options{})
	if err != nil {
		t.Fatalf("Select: %v", err)
	}
	if _, ok := tr.(*WiFiSender); !ok {
		t.Errorf("expected *WiFiSender, got %T", tr)
	}
}

func TestSelect_Cloud(t *testing.T) {
	tr, err := Select("cloud", Options{
		SupabaseURL: "https://test.supabase.co",
		SupabaseKey: "test-key",
		ReceiverID:  "recv-1",
	})
	if err != nil {
		t.Fatalf("Select: %v", err)
	}
	if _, ok := tr.(*CloudSender); !ok {
		t.Errorf("expected *CloudSender, got %T", tr)
	}
}

func TestSelect_Cloud_MissingConfig(t *testing.T) {
	_, err := Select("cloud", Options{})
	if err == nil {
		t.Error("expected error when cloud config is missing")
	}
}

func TestSelect_Auto(t *testing.T) {
	// Auto mode does real mDNS discovery. On a network with a MarkPush device,
	// it returns WiFiSender; without one, it returns an error (no cloud config).
	// Either outcome is valid — we just verify it doesn't panic.
	tr, err := Select("auto", Options{})
	if err != nil {
		// Expected when no device on network and no cloud config.
		return
	}
	// If a device was found, we should get a WiFiSender.
	if _, ok := tr.(*WiFiSender); !ok {
		t.Errorf("auto with WiFi device should return *WiFiSender, got %T", tr)
	}
}

func TestSelect_Unknown(t *testing.T) {
	_, err := Select("carrier-pigeon", Options{})
	if err == nil {
		t.Error("unknown mode should return error")
	}
}
