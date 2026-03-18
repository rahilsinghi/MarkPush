package cmd

import (
	"fmt"

	"github.com/rahilsinghi/markpush/cli/internal/config"
	"github.com/spf13/cobra"
)

var configCmd = &cobra.Command{
	Use:   "config",
	Short: "Manage MarkPush configuration",
	Long:  `View and manage CLI configuration.`,
}

var configShowCmd = &cobra.Command{
	Use:   "show",
	Short: "Show current configuration",
	RunE: func(cmd *cobra.Command, args []string) error {
		cfg, err := config.Load("")
		if err != nil {
			return fmt.Errorf("load config: %w", err)
		}

		kv := func(key, value string) string {
			return dimStyle.Render(fmt.Sprintf("%-15s", key)) + "  " + boldStyle.Render(value)
		}

		card := renderCard(
			"",
			brandStyle.Render("Configuration"),
			"",
			kv("Device ID", cfg.DeviceID),
			kv("Device Name", cfg.DeviceName),
			kv("Transport", cfg.TransportMode),
			kv("Config", cfg.ConfigDir),
			kv("Paired Devices", fmt.Sprintf("%d", len(cfg.Devices))),
			"",
		)
		fmt.Println(card)
		return nil
	},
}

var configPathCmd = &cobra.Command{
	Use:   "path",
	Short: "Print config directory path",
	RunE: func(cmd *cobra.Command, args []string) error {
		dir, err := config.DefaultConfigDir()
		if err != nil {
			return err
		}
		fmt.Println(dir)
		return nil
	},
}

func init() {
	configCmd.AddCommand(configShowCmd)
	configCmd.AddCommand(configPathCmd)
	rootCmd.AddCommand(configCmd)
}
