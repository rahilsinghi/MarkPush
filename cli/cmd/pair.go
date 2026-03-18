package cmd

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"time"

	"github.com/rahilsinghi/markpush/cli/internal/config"
	mpcrypto "github.com/rahilsinghi/markpush/cli/internal/crypto"
	"github.com/rahilsinghi/markpush/cli/internal/protocol"
	"github.com/rahilsinghi/markpush/cli/pkg/qr"
	"github.com/spf13/cobra"
)

var pairCmd = &cobra.Command{
	Use:   "pair",
	Short: "Pair with an iOS device via QR code",
	Long: `Generate a QR code in the terminal for your iPhone to scan.
This establishes a secure, encrypted connection between devices.

The QR code contains a one-time pairing secret. After scanning,
both devices derive a shared AES-256 encryption key.`,
	RunE: runPair,
}

func init() {
	pairCmd.Flags().Duration("timeout", 2*time.Minute, "how long to wait for pairing")
	rootCmd.AddCommand(pairCmd)
}

// pairResponse is the payload the iOS app sends to complete pairing.
type pairResponse struct {
	DeviceID   string `json:"device_id"`
	DeviceName string `json:"device_name"`
}

func runPair(cmd *cobra.Command, _ []string) error {
	timeout, _ := cmd.Flags().GetDuration("timeout")

	cfg, err := config.Load("")
	if err != nil {
		return fmt.Errorf("load config: %w", err)
	}

	// Generate pairing secret.
	secret := make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, secret); err != nil {
		return fmt.Errorf("generate secret: %w", err)
	}
	secretB64 := base64.StdEncoding.EncodeToString(secret)

	// Find local IP.
	localIP, err := getLocalIP()
	if err != nil {
		return fmt.Errorf("get local IP: %w", err)
	}

	// Start ephemeral HTTP server for pairing handshake.
	listener, err := net.Listen("tcp", ":0")
	if err != nil {
		return fmt.Errorf("start pairing server: %w", err)
	}
	port := listener.Addr().(*net.TCPAddr).Port

	// Build QR payload.
	payload := protocol.PairInitMessage{
		Version:    protocol.ProtocolVersion,
		Secret:     secretB64,
		Host:       localIP,
		Port:       port,
		SenderID:   cfg.DeviceID,
		SenderName: cfg.DeviceName,
	}
	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal pairing payload: %w", err)
	}

	// Generate and display QR code.
	qrStr, err := qr.Generate(string(payloadJSON))
	if err != nil {
		return fmt.Errorf("generate QR code: %w", err)
	}

	fmt.Fprintf(os.Stderr, "\n%s\n\n", brandStyle.Render("Scan with MarkPush iOS app:"))
	fmt.Fprint(os.Stderr, qrStr)
	fmt.Fprintf(os.Stderr, "\n%s\n", subtleStyle.Render(fmt.Sprintf("Listening on %s:%d — waiting for device...", localIP, port)))

	// Handle pairing request.
	resultCh := make(chan pairResponse, 1)
	errCh := make(chan error, 1)

	mux := http.NewServeMux()
	mux.HandleFunc("/pair", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var resp pairResponse
		if err := json.NewDecoder(r.Body).Decode(&resp); err != nil {
			http.Error(w, "invalid request", http.StatusBadRequest)
			errCh <- fmt.Errorf("decode pairing response: %w", err)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]bool{"confirmed": true})

		resultCh <- resp
	})

	srv := &http.Server{Handler: mux}

	go func() {
		if err := srv.Serve(listener); err != nil && err != http.ErrServerClosed {
			errCh <- fmt.Errorf("pairing server: %w", err)
		}
	}()

	// Wait for pairing or timeout.
	ctx, cancel := context.WithTimeout(cmd.Context(), timeout)
	defer cancel()
	defer srv.Shutdown(context.Background())

	select {
	case resp := <-resultCh:
		// Derive shared key.
		key, err := mpcrypto.DeriveKey(secretB64, []byte(resp.DeviceID))
		if err != nil {
			return fmt.Errorf("derive key: %w", err)
		}

		// Save paired device.
		device := config.PairedDevice{
			ID:        resp.DeviceID,
			Name:      resp.DeviceName,
			KeyBase64: base64.StdEncoding.EncodeToString(key),
		}
		cfg.Devices = append(cfg.Devices, device)
		if err := config.Save(cfg); err != nil {
			return fmt.Errorf("save config: %w", err)
		}

		card := renderCard(
			"",
			fmt.Sprintf("%s Paired with %s", successStyle.Render("✓"), boldStyle.Render(resp.DeviceName)),
			dimStyle.Render("AES-256 encrypted link established"),
			dimStyle.Render("Key saved to ~/.config/markpush/"),
			"",
		)
		fmt.Fprintf(os.Stderr, "\n%s\n", card)
		return nil

	case err := <-errCh:
		return err

	case <-ctx.Done():
		return fmt.Errorf("pairing timed out after %v", timeout)
	}
}

// getLocalIP returns the preferred outbound local IP address.
func getLocalIP() (string, error) {
	conn, err := net.Dial("udp", "8.8.8.8:80")
	if err != nil {
		return "", fmt.Errorf("determine local IP: %w", err)
	}
	defer conn.Close()

	addr := conn.LocalAddr().(*net.UDPAddr)
	return addr.IP.String(), nil
}
