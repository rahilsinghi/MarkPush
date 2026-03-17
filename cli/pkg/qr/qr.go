// Package qr generates QR codes for terminal display using Unicode block characters.
package qr

import (
	"fmt"
	"strings"

	qrcode "github.com/skip2/go-qrcode"
)

// Generate creates a QR code from data and returns a terminal-renderable string
// using Unicode block characters (works in any terminal with UTF-8 support).
func Generate(data string) (string, error) {
	qr, err := qrcode.New(data, qrcode.Medium)
	if err != nil {
		return "", fmt.Errorf("generate qr: %w", err)
	}

	bitmap := qr.Bitmap()
	return renderBitmap(bitmap), nil
}

// renderBitmap converts a boolean bitmap to a terminal string using
// Unicode half-block characters. Each character represents two vertical pixels.
func renderBitmap(bitmap [][]bool) string {
	var sb strings.Builder
	rows := len(bitmap)

	for y := 0; y < rows; y += 2 {
		for x := 0; x < len(bitmap[y]); x++ {
			top := bitmap[y][x]
			bottom := false
			if y+1 < rows {
				bottom = bitmap[y+1][x]
			}

			switch {
			case top && bottom:
				sb.WriteRune('\u2588') // █ full block
			case top && !bottom:
				sb.WriteRune('\u2580') // ▀ upper half
			case !top && bottom:
				sb.WriteRune('\u2584') // ▄ lower half
			default:
				sb.WriteRune(' ')
			}
		}
		sb.WriteRune('\n')
	}

	return sb.String()
}
