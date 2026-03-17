package mdns

import (
	"net"
	"testing"

	"github.com/hashicorp/mdns"
)

func TestParseEntry_Valid(t *testing.T) {
	entry := &mdns.ServiceEntry{
		Name:   "MarkPush on iPhone._markpush._tcp.local.",
		AddrV4: net.IPv4(192, 168, 1, 42),
		Port:   49152,
		InfoFields: []string{
			"id=iphone-uuid-123",
			"v=1",
		},
	}

	dev := parseEntry(entry)
	if dev == nil {
		t.Fatal("expected device, got nil")
	}
	if dev.Host != "192.168.1.42" {
		t.Errorf("Host = %q, want %q", dev.Host, "192.168.1.42")
	}
	if dev.Port != 49152 {
		t.Errorf("Port = %d, want 49152", dev.Port)
	}
	if dev.ID != "iphone-uuid-123" {
		t.Errorf("ID = %q, want %q", dev.ID, "iphone-uuid-123")
	}
}

func TestParseEntry_IPv6Only(t *testing.T) {
	entry := &mdns.ServiceEntry{
		Name:   "MarkPush._markpush._tcp.local.",
		AddrV6: net.ParseIP("fe80::1"),
		Port:   49152,
	}

	dev := parseEntry(entry)
	if dev == nil {
		t.Fatal("expected device, got nil")
	}
	if dev.Host != "fe80::1" {
		t.Errorf("Host = %q, want %q", dev.Host, "fe80::1")
	}
}

func TestParseEntry_NilEntry(t *testing.T) {
	dev := parseEntry(nil)
	if dev != nil {
		t.Error("expected nil for nil entry")
	}
}

func TestParseEntry_ZeroPort(t *testing.T) {
	entry := &mdns.ServiceEntry{
		AddrV4: net.IPv4(192, 168, 1, 1),
		Port:   0,
	}
	dev := parseEntry(entry)
	if dev != nil {
		t.Error("expected nil for zero port")
	}
}

func TestParseEntry_NoAddress(t *testing.T) {
	entry := &mdns.ServiceEntry{
		Name: "test",
		Port: 49152,
	}
	dev := parseEntry(entry)
	if dev != nil {
		t.Error("expected nil when no address available")
	}
}

func TestParseEntry_NoTXTRecords(t *testing.T) {
	entry := &mdns.ServiceEntry{
		AddrV4: net.IPv4(10, 0, 0, 1),
		Port:   49152,
	}
	dev := parseEntry(entry)
	if dev == nil {
		t.Fatal("expected device even without TXT records")
	}
	if dev.ID != "" {
		t.Errorf("ID = %q, want empty", dev.ID)
	}
}
