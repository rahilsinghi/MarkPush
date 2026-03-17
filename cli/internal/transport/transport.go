// Package transport defines the Transport interface and implementations
// for sending PushMessages to iOS devices.
package transport

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"time"

	"github.com/charmbracelet/lipgloss"
	"github.com/rahilsinghi/markpush/cli/internal/mdns"
	"github.com/rahilsinghi/markpush/cli/internal/protocol"
)

// Transport sends a PushMessage to an iOS device.
type Transport interface {
	Send(ctx context.Context, msg *protocol.PushMessage) error
}

// CloudTransport sends messages via the Supabase cloud relay.
// Not implemented yet.
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
// In "auto" mode, it tries WiFi discovery first and falls back to cloud.
func Select(mode string) (Transport, error) {
	switch mode {
	case "dry-run":
		return NewDryRunTransport(nil), nil
	case "wifi":
		return NewWiFiSender(), nil
	case "cloud":
		return NewCloudTransport(), nil
	case "auto":
		return selectAuto()
	default:
		return nil, fmt.Errorf("unknown transport mode: %q", mode)
	}
}

// selectAuto tries mDNS discovery for 2 seconds. If a device is found,
// uses WiFi. Otherwise falls back to cloud.
func selectAuto() (Transport, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	dev, err := mdns.Discover(ctx, 2*time.Second)
	if err == nil && dev != nil {
		return NewWiFiSenderWithDevice(dev), nil
	}

	// Fallback to cloud.
	return NewCloudTransport(), nil
}
