package qr

import (
	"strings"
	"testing"
)

func TestGenerate_ValidData(t *testing.T) {
	result, err := Generate("https://example.com")
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}
	if result == "" {
		t.Error("expected non-empty QR output")
	}
	// Should contain block characters.
	if !strings.ContainsAny(result, "\u2588\u2580\u2584") {
		t.Error("output should contain Unicode block characters")
	}
}

func TestGenerate_EmptyData(t *testing.T) {
	_, err := Generate("")
	if err == nil {
		t.Error("expected error for empty data")
	}
}

func TestGenerate_JSONPayload(t *testing.T) {
	payload := `{"v":"1","s":"dGVzdC1zZWNyZXQ=","h":"192.168.1.42","p":54321,"id":"cli-1","name":"Mac"}`
	result, err := Generate(payload)
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}
	if result == "" {
		t.Error("expected non-empty QR output")
	}
}

func TestRenderBitmap(t *testing.T) {
	bitmap := [][]bool{
		{true, false, true},
		{false, true, false},
	}
	result := renderBitmap(bitmap)
	if result == "" {
		t.Error("expected non-empty render output")
	}
	// Two rows collapsed into one line + newline.
	lines := strings.Split(strings.TrimRight(result, "\n"), "\n")
	if len(lines) != 1 {
		t.Errorf("expected 1 line for 2-row bitmap, got %d", len(lines))
	}
}

func TestRenderBitmap_OddRows(t *testing.T) {
	bitmap := [][]bool{
		{true, true},
		{true, true},
		{false, true}, // odd row — bottom is implicitly false
	}
	result := renderBitmap(bitmap)
	lines := strings.Split(strings.TrimRight(result, "\n"), "\n")
	if len(lines) != 2 {
		t.Errorf("expected 2 lines for 3-row bitmap, got %d", len(lines))
	}
}
