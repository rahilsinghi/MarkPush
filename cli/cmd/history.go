package cmd

import (
	"fmt"

	"github.com/charmbracelet/lipgloss"
	"github.com/spf13/cobra"
)

var historyCmd = &cobra.Command{
	Use:   "history",
	Short: "Show push history",
	Long:  `Display a list of previously pushed documents with timestamps and status.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		msg := lipgloss.NewStyle().
			Foreground(lipgloss.Color("214")).
			Render("⚠ Push history is not yet implemented. Coming in Phase 5.")
		fmt.Println(msg)
		return nil
	},
}

func init() {
	historyCmd.Flags().Int("limit", 20, "number of entries to show")
	historyCmd.Flags().Bool("json", false, "output as JSON")
	rootCmd.AddCommand(historyCmd)
}
