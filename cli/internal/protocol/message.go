// Package protocol defines the shared message types for the MarkPush protocol.
package protocol

import (
	"encoding/base64"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
)

// Protocol version.
const ProtocolVersion = "1"

// Message type constants.
const (
	MessageTypePush     = "push"
	MessageTypePairInit = "pair_init"
	MessageTypePairAck  = "pair_ack"
	MessageTypePing     = "ping"
	MessageTypePong     = "pong"
	MessageTypeAck      = "ack"
	MessageTypeError    = "error"
)

// PushMessage is the primary payload sent from CLI to iOS app.
type PushMessage struct {
	Version   string    `json:"version"`
	Type      string    `json:"type"`
	ID        string    `json:"id"`
	Timestamp time.Time `json:"timestamp"`

	Title     string   `json:"title"`
	Tags      []string `json:"tags,omitempty"`
	Source    string   `json:"source,omitempty"`
	WordCount int      `json:"word_count"`

	Content   string `json:"content"`
	Encrypted bool   `json:"encrypted"`

	SenderID   string `json:"sender_id"`
	SenderName string `json:"sender_name"`
}

// AckMessage acknowledges receipt of a push message.
type AckMessage struct {
	Version   string    `json:"version"`
	Type      string    `json:"type"`
	ID        string    `json:"id"`
	Timestamp time.Time `json:"timestamp"`

	RefID  string `json:"ref_id"`
	Status string `json:"status"`
}

// PairInitMessage is the QR code payload for device pairing.
// Uses short JSON keys to minimize QR code size.
type PairInitMessage struct {
	Version    string `json:"v"`
	Secret     string `json:"s"`
	Host       string `json:"h"`
	Port       int    `json:"p"`
	SenderID   string `json:"id"`
	SenderName string `json:"name"`
}

// NewPushMessage creates a new PushMessage with generated ID and timestamp.
// Content is base64-encoded. Title is extracted from the first H1 heading
// unless an explicit title is provided.
func NewPushMessage(title string, content []byte, tags []string, source, senderID, senderName string) PushMessage {
	if title == "" {
		title = ExtractTitle(content)
	}

	return PushMessage{
		Version:    ProtocolVersion,
		Type:       MessageTypePush,
		ID:         uuid.New().String(),
		Timestamp:  time.Now(),
		Title:      title,
		Tags:       tags,
		Source:     source,
		WordCount:  CountWords(content),
		Content:    base64.StdEncoding.EncodeToString(content),
		Encrypted:  false,
		SenderID:   senderID,
		SenderName: senderName,
	}
}

var h1Regex = regexp.MustCompile(`(?m)^#\s+(.+)$`)

// ExtractTitle returns the text of the first H1 heading in the markdown.
// Returns "Untitled" if no H1 is found.
func ExtractTitle(markdown []byte) string {
	match := h1Regex.FindSubmatch(markdown)
	if match == nil {
		return "Untitled"
	}
	return strings.TrimSpace(string(match[1]))
}

// CountWords returns the number of whitespace-delimited words in the markdown.
func CountWords(markdown []byte) int {
	fields := strings.Fields(string(markdown))
	return len(fields)
}
