// Package qr generates QR codes for terminal display.
// Not yet implemented — will use go-qrcode in Phase 2.
package qr

import "fmt"

// Generate creates a QR code from data and returns a terminal-renderable string.
func Generate(data string) (string, error) {
	return "", fmt.Errorf("qr: not implemented (Phase 2)")
}
