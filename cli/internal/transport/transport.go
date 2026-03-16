// Package transport defines the Transport interface and implementations
// for sending PushMessages to iOS devices.
package transport

import (
	"context"
	"encoding/json"
	"fmt"
	"io"

	"github.com/charmbracelet/lipgloss"
	"github.com/rahilsinghi/markpush/cli/internal/protocol"
)

// Transport sends a PushMessage to an iOS device.
type Transport interface {
	Send(ctx context.Context, msg *protocol.PushMessage) error
}

// WiFiTransport sends messages over local WiFi via WebSocket.
// Not implemented in Phase 1.
type WiFiTransport struct{}

// NewWiFiTransport creates a new WiFi transport.
func NewWiFiTransport() *WiFiTransport {
	return &WiFiTransport{}
}

// Send is not yet implemented for WiFi transport.
func (t *WiFiTransport) Send(_ context.Context, _ *protocol.PushMessage) error {
	return fmt.Errorf("wifi transport: not implemented (Phase 2)")
}

// CloudTransport sends messages via the Supabase cloud relay.
// Not implemented in Phase 1.
type CloudTransport struct{}

// NewCloudTransport creates a new cloud transport.
func NewCloudTransport() *CloudTransport {
	return &CloudTransport{}
}

// Send is not yet implemented for cloud transport.
func (t *CloudTransport) Send(_ context.Context, _ *protocol.PushMessage) error {
	return fmt.Errorf("cloud transport: not implemented (Phase 4)")
}

// DryRunTransport prints the PushMessage as formatted JSON without sending.
type DryRunTransport struct {
	Writer io.Writer
}

// NewDryRunTransport creates a new dry-run transport that writes to w.
func NewDryRunTransport(w io.Writer) *DryRunTransport {
	return &DryRunTransport{Writer: w}
}

// Send prints the message as formatted JSON.
func (t *DryRunTransport) Send(_ context.Context, msg *protocol.PushMessage) error {
	data, err := json.MarshalIndent(msg, "", "  ")
	if err != nil {
		return fmt.Errorf("dry-run: marshal message: %w", err)
	}

	header := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("212")).
		Render("[dry-run] Would send:")

	fmt.Fprintf(t.Writer, "%s\n%s\n", header, string(data))
	return nil
}

// Select returns the appropriate transport based on the given mode.
// Valid modes: "dry-run", "wifi", "cloud", "auto".
func Select(mode string) (Transport, error) {
	switch mode {
	case "dry-run":
		return NewDryRunTransport(nil), nil
	case "wifi":
		return NewWiFiTransport(), nil
	case "cloud":
		return NewCloudTransport(), nil
	case "auto":
		return nil, fmt.Errorf("auto transport: WiFi and cloud not yet implemented, use --dry-run")
	default:
		return nil, fmt.Errorf("unknown transport mode: %q", mode)
	}
}
