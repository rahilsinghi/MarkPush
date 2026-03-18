package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var historyCmd = &cobra.Command{
	Use:   "history",
	Short: "Show push history",
	Long:  `Display a list of previously pushed documents with timestamps and status.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		card := renderCard(
			"",
			warnStyle.Render("⚠ Push history is not yet implemented"),
			subtleStyle.Render("Coming soon"),
			"",
		)
		fmt.Fprintln(os.Stderr, card)
		return nil
	},
}

func init() {
	historyCmd.Flags().Int("limit", 20, "number of entries to show")
	historyCmd.Flags().Bool("json", false, "output as JSON")
	rootCmd.AddCommand(historyCmd)
}
