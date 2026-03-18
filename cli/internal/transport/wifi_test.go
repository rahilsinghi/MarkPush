package transport

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"strings"
	"testing"

	"github.com/rahilsinghi/markpush/cli/internal/mdns"
	"github.com/rahilsinghi/markpush/cli/internal/protocol"
)

// startTestTCPServer starts a TCP server that receives a message and sends back an ack.
func startTestTCPServer(t *testing.T, handler func(conn net.Conn)) (string, int) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	t.Cleanup(func() { ln.Close() })

	go func() {
		conn, err := ln.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		handler(conn)
	}()

	addr := ln.Addr().String()
	parts := strings.Split(addr, ":")
	host := parts[0]
	var port int
	fmt.Sscanf(parts[len(parts)-1], "%d", &port)
	return host, port
}

func TestWiFiSender_Send_Success(t *testing.T) {
	var received protocol.PushMessage

	host, port := startTestTCPServer(t, func(conn net.Conn) {
		buf := make([]byte, 65536)
		n, err := conn.Read(buf)
		if err != nil {
			t.Errorf("read: %v", err)
			return
		}
		if err := json.Unmarshal(buf[:n], &received); err != nil {
			t.Errorf("unmarshal: %v", err)
			return
		}

		ack := protocol.AckMessage{
			Version: protocol.ProtocolVersion,
			Type:    protocol.MessageTypeAck,
			RefID:   received.ID,
			Status:  "received",
		}
		data, _ := json.Marshal(ack)
		conn.Write(data)
	})

	dev := &mdns.Device{Host: host, Port: port, Name: "test", ID: "test-id"}
	sender := NewWiFiSenderWithDevice(dev)

	msg := testMessage()
	err := sender.Send(context.Background(), msg)
	if err != nil {
		t.Fatalf("Send: %v", err)
	}

	if received.Title != msg.Title {
		t.Errorf("received Title = %q, want %q", received.Title, msg.Title)
	}
	if received.ID != msg.ID {
		t.Errorf("received ID = %q, want %q", received.ID, msg.ID)
	}
}

func TestWiFiSender_Send_ErrorAck(t *testing.T) {
	host, port := startTestTCPServer(t, func(conn net.Conn) {
		buf := make([]byte, 65536)
		conn.Read(buf)

		ack := protocol.AckMessage{
			Version: protocol.ProtocolVersion,
			Type:    protocol.MessageTypeAck,
			Status:  "error",
		}
		data, _ := json.Marshal(ack)
		conn.Write(data)
	})

	dev := &mdns.Device{Host: host, Port: port}
	sender := NewWiFiSenderWithDevice(dev)

	err := sender.Send(context.Background(), testMessage())
	if err == nil {
		t.Error("expected error for error ack")
	}
}

func TestWiFiSender_Send_NoAck(t *testing.T) {
	host, port := startTestTCPServer(t, func(conn net.Conn) {
		buf := make([]byte, 65536)
		conn.Read(buf)
		// Close without sending ack.
	})

	dev := &mdns.Device{Host: host, Port: port}
	sender := NewWiFiSenderWithDevice(dev)

	// Should succeed even without ack (best-effort).
	err := sender.Send(context.Background(), testMessage())
	if err != nil {
		t.Errorf("Send without ack should succeed, got: %v", err)
	}
}

func TestWiFiSender_Send_ConnectionRefused(t *testing.T) {
	dev := &mdns.Device{Host: "127.0.0.1", Port: 1} // nothing listening
	sender := NewWiFiSenderWithDevice(dev)

	err := sender.Send(context.Background(), testMessage())
	if err == nil {
		t.Error("expected error when connection refused")
	}
}

func TestNewWiFiSender(t *testing.T) {
	sender := NewWiFiSender()
	if sender.DiscoveryTimeout != DefaultDiscoveryTimeout {
		t.Errorf("timeout = %v, want %v", sender.DiscoveryTimeout, DefaultDiscoveryTimeout)
	}
}
