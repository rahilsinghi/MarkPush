package transport

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"time"

	"github.com/rahilsinghi/markpush/cli/internal/mdns"
	"github.com/rahilsinghi/markpush/cli/internal/protocol"
)

const (
	// DefaultDiscoveryTimeout is the time to wait for mDNS discovery.
	DefaultDiscoveryTimeout = 2 * time.Second
	// WriteTimeout is the TCP write deadline.
	WriteTimeout = 10 * time.Second
)

// WiFiSender sends messages over local WiFi via raw TCP.
// It discovers the iOS app on the network using mDNS, then connects
// via TCP to push the message as JSON.
type WiFiSender struct {
	DiscoveryTimeout time.Duration
	// device can be pre-set to skip discovery (used by auto-select).
	device *mdns.Device
}

// NewWiFiSender creates a WiFi transport with default settings.
func NewWiFiSender() *WiFiSender {
	return &WiFiSender{
		DiscoveryTimeout: DefaultDiscoveryTimeout,
	}
}

// NewWiFiSenderWithDevice creates a WiFi transport targeting a specific device.
func NewWiFiSenderWithDevice(dev *mdns.Device) *WiFiSender {
	return &WiFiSender{
		DiscoveryTimeout: DefaultDiscoveryTimeout,
		device:           dev,
	}
}

// Send discovers the iOS device (if not already known), connects via TCP,
// sends the push message as JSON, and waits for an acknowledgment.
func (t *WiFiSender) Send(ctx context.Context, msg *protocol.PushMessage) error {
	dev := t.device
	if dev == nil {
		var err error
		dev, err = mdns.Discover(ctx, t.DiscoveryTimeout)
		if err != nil {
			return fmt.Errorf("wifi send: %w", err)
		}
	}

	addr := fmt.Sprintf("%s:%d", dev.Host, dev.Port)
	dialer := net.Dialer{Timeout: WriteTimeout}
	conn, err := dialer.DialContext(ctx, "tcp", addr)
	if err != nil {
		return fmt.Errorf("wifi send: connect to %s: %w", addr, err)
	}
	defer conn.Close()

	if err := conn.SetWriteDeadline(time.Now().Add(WriteTimeout)); err != nil {
		return fmt.Errorf("wifi send: set deadline: %w", err)
	}

	payload, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("wifi send: marshal message: %w", err)
	}

	if _, err := conn.Write(payload); err != nil {
		return fmt.Errorf("wifi send: write message: %w", err)
	}

	// Wait for acknowledgment.
	if err := conn.SetReadDeadline(time.Now().Add(WriteTimeout)); err != nil {
		return fmt.Errorf("wifi send: set read deadline: %w", err)
	}

	buf := make([]byte, 4096)
	n, err := conn.Read(buf)
	if err != nil {
		// Not fatal — message was sent, ack is best-effort.
		return nil
	}

	var ack protocol.AckMessage
	if err := json.Unmarshal(buf[:n], &ack); err != nil {
		return nil // ack parsing failure is non-fatal
	}

	if ack.Status == "error" {
		return fmt.Errorf("wifi send: device reported error for message %s", msg.ID)
	}

	return nil
}
