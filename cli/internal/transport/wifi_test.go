package transport

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gorilla/websocket"
	"github.com/rahilsinghi/markpush/cli/internal/mdns"
	"github.com/rahilsinghi/markpush/cli/internal/protocol"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

// startTestWSServer starts a WebSocket server that receives a message
// and sends back an ack.
func startTestWSServer(t *testing.T, handler func(conn *websocket.Conn)) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Errorf("upgrade: %v", err)
			return
		}
		defer conn.Close()
		handler(conn)
	}))
	return srv
}

func parseTestServerAddr(t *testing.T, srv *httptest.Server) (string, int) {
	t.Helper()
	addr := srv.Listener.Addr().String()
	parts := strings.Split(addr, ":")
	host := parts[0]
	var port int
	if _, err := fmt.Sscanf(parts[len(parts)-1], "%d", &port); err != nil {
		t.Fatalf("parse port: %v", err)
	}
	return host, port
}

func TestWiFiSender_Send_Success(t *testing.T) {
	var received protocol.PushMessage

	srv := startTestWSServer(t, func(conn *websocket.Conn) {
		// Read the push message.
		_, data, err := conn.ReadMessage()
		if err != nil {
			t.Errorf("read: %v", err)
			return
		}
		if err := json.Unmarshal(data, &received); err != nil {
			t.Errorf("unmarshal: %v", err)
			return
		}

		// Send ack.
		ack := protocol.AckMessage{
			Version: protocol.ProtocolVersion,
			Type:    protocol.MessageTypeAck,
			RefID:   received.ID,
			Status:  "received",
		}
		if err := conn.WriteJSON(ack); err != nil {
			t.Errorf("write ack: %v", err)
		}
	})
	defer srv.Close()

	host, port := parseTestServerAddr(t, srv)
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
	srv := startTestWSServer(t, func(conn *websocket.Conn) {
		_, _, _ = conn.ReadMessage()
		ack := protocol.AckMessage{
			Version: protocol.ProtocolVersion,
			Type:    protocol.MessageTypeAck,
			Status:  "error",
		}
		_ = conn.WriteJSON(ack)
	})
	defer srv.Close()

	host, port := parseTestServerAddr(t, srv)
	dev := &mdns.Device{Host: host, Port: port}
	sender := NewWiFiSenderWithDevice(dev)

	err := sender.Send(context.Background(), testMessage())
	if err == nil {
		t.Error("expected error for error ack")
	}
}

func TestWiFiSender_Send_NoAck(t *testing.T) {
	srv := startTestWSServer(t, func(conn *websocket.Conn) {
		_, _, _ = conn.ReadMessage()
		// Close without sending ack.
	})
	defer srv.Close()

	host, port := parseTestServerAddr(t, srv)
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
