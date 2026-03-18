package transport

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCloudSender_Send_Success(t *testing.T) {
	var receivedBody map[string]interface{}

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/rest/v1/pushes" {
			t.Errorf("unexpected path: %s", r.URL.Path)
		}
		if r.Header.Get("apikey") != "test-key" {
			t.Errorf("apikey = %q, want %q", r.Header.Get("apikey"), "test-key")
		}
		if r.Header.Get("Content-Type") != "application/json" {
			t.Errorf("Content-Type = %q, want %q", r.Header.Get("Content-Type"), "application/json")
		}

		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &receivedBody)

		w.WriteHeader(http.StatusCreated)
	}))
	defer srv.Close()

	sender := NewCloudSender(srv.URL, "test-key", "receiver-1", "")
	msg := testMessage()

	err := sender.Send(context.Background(), msg)
	if err != nil {
		t.Fatalf("Send: %v", err)
	}

	if receivedBody["sender_id"] != msg.SenderID {
		t.Errorf("sender_id = %v, want %v", receivedBody["sender_id"], msg.SenderID)
	}
	if receivedBody["receiver_id"] != "receiver-1" {
		t.Errorf("receiver_id = %v, want %v", receivedBody["receiver_id"], "receiver-1")
	}
}

func TestCloudSender_Send_ServerError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()

	sender := NewCloudSender(srv.URL, "key", "recv", "")
	err := sender.Send(context.Background(), testMessage())
	if err == nil {
		t.Error("expected error for 500 response")
	}
}

func TestCloudSender_Send_ConnectionRefused(t *testing.T) {
	sender := NewCloudSender("http://127.0.0.1:1", "key", "recv", "")
	err := sender.Send(context.Background(), testMessage())
	if err == nil {
		t.Error("expected error for connection refused")
	}
}
