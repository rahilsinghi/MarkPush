package transport

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/rahilsinghi/markpush/cli/internal/protocol"
)

// CloudSender sends messages via the Supabase cloud relay.
type CloudSender struct {
	SupabaseURL string
	SupabaseKey string
	ReceiverID  string
}

// NewCloudSender creates a cloud transport with the given Supabase credentials.
func NewCloudSender(supabaseURL, supabaseKey, receiverID string) *CloudSender {
	return &CloudSender{
		SupabaseURL: supabaseURL,
		SupabaseKey: supabaseKey,
		ReceiverID:  receiverID,
	}
}

// Send posts an encrypted push message to the Supabase cloud relay.
func (t *CloudSender) Send(ctx context.Context, msg *protocol.PushMessage) error {
	payload, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("cloud send: marshal message: %w", err)
	}

	body := map[string]interface{}{
		"sender_id":   msg.SenderID,
		"receiver_id": t.ReceiverID,
		"payload":     string(payload),
	}

	b, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("cloud send: marshal body: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		t.SupabaseURL+"/rest/v1/pushes", bytes.NewReader(b))
	if err != nil {
		return fmt.Errorf("cloud send: create request: %w", err)
	}

	req.Header.Set("apikey", t.SupabaseKey)
	req.Header.Set("Authorization", "Bearer "+t.SupabaseKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Prefer", "return=minimal")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("cloud send: request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("cloud send: HTTP %d", resp.StatusCode)
	}

	return nil
}
