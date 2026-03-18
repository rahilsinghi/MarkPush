package cmd

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"

	"strings"

	"github.com/rahilsinghi/markpush/cli/internal/config"
	mpcrypto "github.com/rahilsinghi/markpush/cli/internal/crypto"
	"github.com/rahilsinghi/markpush/cli/internal/protocol"
	"github.com/rahilsinghi/markpush/cli/internal/transport"
	"github.com/spf13/cobra"
)

var pushCmd = &cobra.Command{
	Use:   "push [file]",
	Short: "Push a markdown file to your iPhone",
	Long: `Push a markdown file to your paired iPhone over WiFi or cloud relay.

Examples:
  markpush push README.md
  markpush push --title "Auth Design" --tag backend architecture.md
  cat output.md | markpush push --stdin
  markpush push README.md --dry-run`,
	RunE: runPush,
}

func init() {
	pushCmd.Flags().String("title", "", "override document title")
	pushCmd.Flags().StringSlice("tag", nil, "tags for the document (repeatable)")
	pushCmd.Flags().Bool("stdin", false, "read from stdin instead of file")
	pushCmd.Flags().Bool("wifi", false, "force WiFi transport")
	pushCmd.Flags().Bool("cloud", false, "force cloud transport")
	pushCmd.Flags().Bool("dry-run", false, "print what would be sent, don't send")
	pushCmd.Flags().String("source", "", "source tag (e.g. 'claude', 'cursor')")
	rootCmd.AddCommand(pushCmd)
}

// pushOptions holds the parsed flags for the push command.
type pushOptions struct {
	Title      string
	Tags       []string
	Source     string
	Stdin      bool
	ForceWiFi  bool
	ForceCloud bool
	DryRun     bool
}

func runPush(cmd *cobra.Command, args []string) error {
	opts := pushOptions{
		Title:      mustGetString(cmd, "title"),
		Tags:       mustGetStringSlice(cmd, "tag"),
		Source:     mustGetString(cmd, "source"),
		Stdin:      mustGetBool(cmd, "stdin"),
		ForceWiFi:  mustGetBool(cmd, "wifi"),
		ForceCloud: mustGetBool(cmd, "cloud"),
		DryRun:     mustGetBool(cmd, "dry-run"),
	}

	// Read input.
	var input io.Reader
	if opts.Stdin {
		input = os.Stdin
	} else {
		if len(args) == 0 {
			return fmt.Errorf("provide a file path or use --stdin to read from pipe")
		}
		f, err := os.Open(args[0])
		if err != nil {
			return fmt.Errorf("open file: %w", err)
		}
		defer f.Close()
		input = f
	}

	// Load config for device identity.
	cfg, err := config.Load("")
	if err != nil {
		return fmt.Errorf("load config: %w", err)
	}

	// Build message.
	msg, err := buildPushMessage(input, opts, cfg)
	if err != nil {
		return err
	}

	// Select transport.
	mode := resolveTransportMode(opts)
	var tr transport.Transport
	if mode == "dry-run" {
		tr = transport.NewDryRunTransport(os.Stdout)
	} else {
		transportOpts := transport.Options{
			SupabaseURL: cfg.Cloud.SupabaseURL,
			SupabaseKey: cfg.Cloud.SupabaseKey,
			UserID:      cfg.Cloud.UserID,
		}
		// Use first paired device as receiver.
		if len(cfg.Devices) > 0 {
			transportOpts.ReceiverID = cfg.Devices[0].ID
		}
		tr, err = transport.Select(mode, transportOpts)
		if err != nil {
			return err
		}
	}

	// Send.
	if err := tr.Send(context.Background(), msg); err != nil {
		return fmt.Errorf("send: %w", err)
	}

	if !opts.DryRun {
		deviceName := "device"
		if len(cfg.Devices) > 0 {
			deviceName = cfg.Devices[0].Name
		}

		check := successStyle.Render("✓")
		device := boldStyle.Render(deviceName)
		arrow := subtleStyle.Render("━━━▶")

		lines := []string{
			"",
			fmt.Sprintf("%s Pushed", check),
			fmt.Sprintf("terminal %s %s", arrow, device),
			"",
			fmt.Sprintf(`"%s"`, msg.Title),
		}

		details := fmt.Sprintf("%s words", formatNumber(msg.WordCount))
		if msg.Encrypted {
			details += " · encrypted"
		}
		lines = append(lines, dimStyle.Render(details))

		if len(opts.Tags) > 0 {
			lines = append(lines, dimStyle.Render("Tags: "+strings.Join(opts.Tags, ", ")))
		}

		lines = append(lines, "")
		fmt.Fprintln(os.Stderr, renderCard(lines...))
	}

	return nil
}

// buildPushMessage reads content and constructs a PushMessage.
func buildPushMessage(input io.Reader, opts pushOptions, cfg *config.Config) (*protocol.PushMessage, error) {
	content, err := io.ReadAll(input)
	if err != nil {
		return nil, fmt.Errorf("read input: %w", err)
	}

	msg := protocol.NewPushMessage(opts.Title, content, opts.Tags, opts.Source, cfg.DeviceID, cfg.DeviceName)

	// Encrypt if a paired device key is available.
	key, err := config.LoadPairedDeviceKey(cfg)
	if err != nil && !errors.Is(err, config.ErrNoPairedDevice) {
		return nil, fmt.Errorf("load encryption key: %w", err)
	}
	if key != nil {
		encrypted, err := mpcrypto.Encrypt(key, content)
		if err != nil {
			return nil, fmt.Errorf("encrypt content: %w", err)
		}
		msg.Content = encrypted
		msg.Encrypted = true
	}

	return &msg, nil
}

func resolveTransportMode(opts pushOptions) string {
	if opts.DryRun {
		return "dry-run"
	}
	if opts.ForceWiFi {
		return "wifi"
	}
	if opts.ForceCloud {
		return "cloud"
	}
	return "auto"
}

func mustGetString(cmd *cobra.Command, name string) string {
	v, _ := cmd.Flags().GetString(name)
	return v
}

func mustGetStringSlice(cmd *cobra.Command, name string) []string {
	v, _ := cmd.Flags().GetStringSlice(name)
	return v
}

func mustGetBool(cmd *cobra.Command, name string) bool {
	v, _ := cmd.Flags().GetBool(name)
	return v
}
