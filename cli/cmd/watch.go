package cmd

import (
	"fmt"

	"github.com/charmbracelet/lipgloss"
	"github.com/spf13/cobra"
)

var watchCmd = &cobra.Command{
	Use:   "watch [directory]",
	Short: "Watch a directory and push changed markdown files",
	Long: `Watch a directory for changes to .md files and automatically
push them to your paired iPhone.

Example:
  markpush watch ./docs/`,
	RunE: func(cmd *cobra.Command, args []string) error {
		msg := lipgloss.NewStyle().
			Foreground(lipgloss.Color("214")).
			Render("⚠ Watch mode is not yet implemented. Coming in Phase 5.")
		fmt.Println(msg)
		return nil
	},
}

func init() {
	rootCmd.AddCommand(watchCmd)
}
