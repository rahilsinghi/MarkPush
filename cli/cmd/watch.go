package cmd

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/fsnotify/fsnotify"
	"github.com/rahilsinghi/markpush/cli/internal/config"
	"github.com/rahilsinghi/markpush/cli/internal/transport"
	"github.com/spf13/cobra"
)

var watchCmd = &cobra.Command{
	Use:   "watch [directory]",
	Short: "Watch a directory and push changed markdown files",
	Long: `Watch a directory for changes to .md files and automatically
push them to your paired iPhone.

Example:
  markpush watch ./docs/
  markpush watch ./docs/ --dry-run`,
	Args: cobra.ExactArgs(1),
	RunE: runWatch,
}

func init() {
	watchCmd.Flags().Bool("dry-run", false, "print what would be sent, don't send")
	watchCmd.Flags().StringSlice("tag", nil, "tags for pushed documents (repeatable)")
	watchCmd.Flags().String("source", "", "source tag (e.g. 'claude')")
	watchCmd.Flags().Duration("debounce", 300*time.Millisecond, "debounce delay for file changes")
	rootCmd.AddCommand(watchCmd)
}

func runWatch(cmd *cobra.Command, args []string) error {
	dir := args[0]
	dryRun, _ := cmd.Flags().GetBool("dry-run")
	tags, _ := cmd.Flags().GetStringSlice("tag")
	source, _ := cmd.Flags().GetString("source")
	debounce, _ := cmd.Flags().GetDuration("debounce")

	// Verify directory exists.
	info, err := os.Stat(dir)
	if err != nil {
		return fmt.Errorf("watch: %w", err)
	}
	if !info.IsDir() {
		return fmt.Errorf("watch: %s is not a directory", dir)
	}

	cfg, err := config.Load("")
	if err != nil {
		return fmt.Errorf("watch: load config: %w", err)
	}

	absDir, _ := filepath.Abs(dir)
	header := renderCard(
		fmt.Sprintf("%s %s", brandStyle.Render("Watching"), boldStyle.Render(absDir)),
		subtleStyle.Render("Ctrl+C to stop"),
	)
	fmt.Fprintln(os.Stderr, header)
	fmt.Fprintln(os.Stderr)

	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		return fmt.Errorf("watch: create watcher: %w", err)
	}
	defer watcher.Close()

	// Watch the directory and subdirectories.
	if err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return watcher.Add(path)
		}
		return nil
	}); err != nil {
		return fmt.Errorf("watch: add directory: %w", err)
	}

	// Debounce timer map: file path -> last event time.
	pending := make(map[string]time.Time)
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	ctx := cmd.Context()

	for {
		select {
		case <-ctx.Done():
			return nil

		case event, ok := <-watcher.Events:
			if !ok {
				return nil
			}
			if !isMarkdownFile(event.Name) {
				continue
			}
			if event.Has(fsnotify.Write) || event.Has(fsnotify.Create) {
				pending[event.Name] = time.Now()
			}

		case err, ok := <-watcher.Errors:
			if !ok {
				return nil
			}
			fmt.Fprintf(os.Stderr, "watch error: %v\n", err)

		case now := <-ticker.C:
			for path, eventTime := range pending {
				if now.Sub(eventTime) < debounce {
					continue
				}
				delete(pending, path)

				// Push the file.
				pushOpts := pushOptions{
					Tags:   tags,
					Source: source,
					DryRun: dryRun,
				}
				if err := pushFile(ctx, path, pushOpts, cfg); err != nil {
					fmt.Fprintf(os.Stderr, "push %s: %v\n", filepath.Base(path), err)
				}
			}
		}
	}
}

func pushFile(ctx context.Context, path string, opts pushOptions, cfg *config.Config) error {
	f, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("open: %w", err)
	}
	defer f.Close()

	msg, err := buildPushMessage(f, opts, cfg)
	if err != nil {
		return err
	}

	mode := resolveTransportMode(opts)
	var tr transport.Transport
	if mode == "dry-run" {
		tr = transport.NewDryRunTransport(os.Stdout)
	} else {
		transportOpts := transport.Options{
			SupabaseURL: cfg.Cloud.SupabaseURL,
			SupabaseKey: cfg.Cloud.SupabaseKey,
		}
		if len(cfg.Devices) > 0 {
			transportOpts.ReceiverID = cfg.Devices[0].ID
		}
		tr, err = transport.Select(mode, transportOpts)
		if err != nil {
			return err
		}
	}

	if err := tr.Send(ctx, msg); err != nil {
		return fmt.Errorf("send: %w", err)
	}

	now := time.Now().Format("15:04:05")
	ts := subtleStyle.Render(now)
	check := successStyle.Render("✓ Pushed")
	fmt.Fprintf(os.Stderr, "  %s  %s %q (%s words)\n", ts, check, msg.Title, formatNumber(msg.WordCount))
	return nil
}

func isMarkdownFile(path string) bool {
	ext := strings.ToLower(filepath.Ext(path))
	return ext == ".md" || ext == ".markdown" || ext == ".mdown"
}
