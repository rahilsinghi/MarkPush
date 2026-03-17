// Package mdns provides mDNS/Bonjour service discovery for finding
// MarkPush iOS apps on the local network.
package mdns

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/hashicorp/mdns"
)

// ServiceType is the Bonjour service type advertised by the iOS app.
const ServiceType = "_markpush._tcp"

// Device represents a discovered MarkPush iOS app on the network.
type Device struct {
	Name string
	Host string
	Port int
	ID   string // from TXT record
}

// Discover finds MarkPush iOS apps on the local network.
// Returns the first matching device found within the timeout, or an error.
func Discover(ctx context.Context, timeout time.Duration) (*Device, error) {
	entries := make(chan *mdns.ServiceEntry, 4)
	result := make(chan *Device, 1)

	go func() {
		for entry := range entries {
			// Copy entry fields immediately — hashicorp/mdns reuses entry structs.
			entryCopy := copyEntry(entry)
			dev := parseEntry(entryCopy)
			if dev != nil {
				result <- dev
				return
			}
		}
	}()

	params := &mdns.QueryParam{
		Service:             ServiceType,
		Domain:              "local",
		Timeout:             timeout,
		Entries:             entries,
		WantUnicastResponse: false,
	}

	go func() {
		_ = mdns.Query(params)
		close(entries)
	}()

	select {
	case dev := <-result:
		return dev, nil
	case <-ctx.Done():
		return nil, fmt.Errorf("discover: %w", ctx.Err())
	case <-time.After(timeout):
		return nil, fmt.Errorf("discover: no MarkPush device found within %v", timeout)
	}
}

// DiscoverAll finds all MarkPush devices on the network within the timeout.
func DiscoverAll(ctx context.Context, timeout time.Duration) ([]*Device, error) {
	entries := make(chan *mdns.ServiceEntry, 16)
	var devices []*Device

	done := make(chan struct{})
	go func() {
		for entry := range entries {
			dev := parseEntry(entry)
			if dev != nil {
				devices = append(devices, dev)
			}
		}
		close(done)
	}()

	params := &mdns.QueryParam{
		Service:             ServiceType,
		Domain:              "local",
		Timeout:             timeout,
		Entries:             entries,
		WantUnicastResponse: false,
	}

	if err := mdns.Query(params); err != nil {
		close(entries)
		return nil, fmt.Errorf("discover all: %w", err)
	}
	close(entries)

	select {
	case <-done:
	case <-ctx.Done():
		return nil, fmt.Errorf("discover all: %w", ctx.Err())
	}

	return devices, nil
}

// copyEntry creates a shallow copy of the service entry to avoid data races
// with hashicorp/mdns which reuses entry structs across goroutines.
func copyEntry(entry *mdns.ServiceEntry) *mdns.ServiceEntry {
	if entry == nil {
		return nil
	}
	cp := *entry
	cp.InfoFields = make([]string, len(entry.InfoFields))
	copy(cp.InfoFields, entry.InfoFields)
	return &cp
}

func parseEntry(entry *mdns.ServiceEntry) *Device {
	if entry == nil || entry.Port == 0 {
		return nil
	}

	dev := &Device{
		Name: entry.Name,
		Host: entry.AddrV4.String(),
		Port: entry.Port,
	}

	// If no IPv4, try IPv6.
	if entry.AddrV4 == nil && entry.AddrV6 != nil {
		dev.Host = entry.AddrV6.String()
	}
	if entry.AddrV4 == nil && entry.AddrV6 == nil {
		return nil
	}

	// Parse TXT records for device ID.
	for _, txt := range entry.InfoFields {
		if strings.HasPrefix(txt, "id=") {
			dev.ID = strings.TrimPrefix(txt, "id=")
		}
	}

	return dev
}
