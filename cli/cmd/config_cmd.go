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

		fmt.Printf("device_id      = %q\n", cfg.DeviceID)
		fmt.Printf("device_name    = %q\n", cfg.DeviceName)
		fmt.Printf("transport_mode = %q\n", cfg.TransportMode)
		fmt.Printf("config_dir     = %q\n", cfg.ConfigDir)
		fmt.Printf("paired_devices = %d\n", len(cfg.Devices))
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
