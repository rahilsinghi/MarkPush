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

	// Extract JSON from output (after the header line).
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
	tr, err := Select("dry-run")
	if err != nil {
		t.Fatalf("Select: %v", err)
	}
	if _, ok := tr.(*DryRunTransport); !ok {
		t.Errorf("expected *DryRunTransport, got %T", tr)
	}
}

func TestSelect_WiFi(t *testing.T) {
	tr, err := Select("wifi")
	if err != nil {
		t.Fatalf("Select: %v", err)
	}
	if _, ok := tr.(*WiFiSender); !ok {
		t.Errorf("expected *WiFiSender, got %T", tr)
	}
}

func TestSelect_Cloud(t *testing.T) {
	tr, err := Select("cloud")
	if err != nil {
		t.Fatalf("Select: %v", err)
	}
	if _, ok := tr.(*CloudTransport); !ok {
		t.Errorf("expected *CloudTransport, got %T", tr)
	}
}

func TestSelect_Auto(t *testing.T) {
	// Auto falls back to cloud when no device is found.
	tr, err := Select("auto")
	if err != nil {
		t.Fatalf("Select auto: %v", err)
	}
	// Should fall back to cloud since no mDNS device is on the network.
	if _, ok := tr.(*CloudTransport); !ok {
		t.Errorf("expected *CloudTransport fallback, got %T", tr)
	}
}

func TestSelect_Unknown(t *testing.T) {
	_, err := Select("carrier-pigeon")
	if err == nil {
		t.Error("unknown mode should return error")
	}
}

func TestCloudTransport_NotImplemented(t *testing.T) {
	tr := NewCloudTransport()
	err := tr.Send(context.Background(), testMessage())
	if err == nil {
		t.Error("Cloud send should return not-implemented error")
	}
	if !strings.Contains(err.Error(), "not implemented") {
		t.Errorf("error = %q, should contain 'not implemented'", err)
	}
}
