// Package cmd implements the CLI commands for markpush.
package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var (
	cfgFile string
	verbose bool
	version = "dev"
)

var rootCmd = &cobra.Command{
	Use:   "markpush",
	Short: "Push markdown from your terminal to your iPhone",
	Long: `MarkPush pushes markdown files from your terminal to a native iOS reader app.
Works over local WiFi (zero-config) or cloud relay (when remote).

  markpush push README.md
  echo "# Hello" | markpush push --stdin
  markpush push --watch ./docs/`,
	SilenceUsage:  true,
	SilenceErrors: true,
}

// Execute runs the root command.
func Execute() error {
	return rootCmd.Execute()
}

// SetVersion sets the CLI version string (injected at build time).
func SetVersion(v string) {
	version = v
	rootCmd.Version = v
}

func init() {
	cobra.OnInitialize(initConfig)
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default ~/.config/markpush/config.toml)")
	rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "verbose output")

	// Show branded banner before root help.
	defaultHelp := rootCmd.HelpFunc()
	rootCmd.SetHelpFunc(func(cmd *cobra.Command, args []string) {
		if cmd == rootCmd {
			fmt.Fprintln(cmd.OutOrStdout(), renderBanner())
			fmt.Fprintln(cmd.OutOrStdout())
		}
		defaultHelp(cmd, args)
	})
}

func initConfig() {
	if cfgFile != "" {
		viper.SetConfigFile(cfgFile)
	} else {
		home, err := os.UserHomeDir()
		if err != nil {
			fmt.Fprintf(os.Stderr, "warning: could not determine home directory: %v\n", err)
			return
		}
		configDir := filepath.Join(home, ".config", "markpush")
		viper.AddConfigPath(configDir)
		viper.SetConfigName("config")
		viper.SetConfigType("toml")
	}

	viper.SetEnvPrefix("MARKPUSH")
	viper.AutomaticEnv()

	// Ignore error if config file doesn't exist yet — defaults are fine.
	_ = viper.ReadInConfig()
}
