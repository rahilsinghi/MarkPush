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

// Options holds configuration for transport selection.
type Options struct {
	SupabaseURL string
	SupabaseKey string
	ReceiverID  string
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
func Select(mode string, opts Options) (Transport, error) {
	switch mode {
	case "dry-run":
		return NewDryRunTransport(nil), nil
	case "wifi":
		return NewWiFiSender(), nil
	case "cloud":
		return newCloud(opts)
	case "auto":
		return selectAuto(opts)
	default:
		return nil, fmt.Errorf("unknown transport mode: %q", mode)
	}
}

func newCloud(opts Options) (Transport, error) {
	if opts.SupabaseURL == "" || opts.SupabaseKey == "" {
		return nil, fmt.Errorf("cloud transport: supabase_url and supabase_key required in config")
	}
	return NewCloudSender(opts.SupabaseURL, opts.SupabaseKey, opts.ReceiverID), nil
}

// selectAuto tries mDNS discovery for 2 seconds. If a device is found,
// uses WiFi. Otherwise falls back to cloud.
func selectAuto(opts Options) (Transport, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	dev, err := mdns.Discover(ctx, 2*time.Second)
	if err == nil && dev != nil {
		return NewWiFiSenderWithDevice(dev), nil
	}

	// Fallback to cloud if configured.
	if opts.SupabaseURL != "" && opts.SupabaseKey != "" {
		return NewCloudSender(opts.SupabaseURL, opts.SupabaseKey, opts.ReceiverID), nil
	}

	return nil, fmt.Errorf("no device found on WiFi and cloud not configured; use --dry-run or configure cloud relay")
}
