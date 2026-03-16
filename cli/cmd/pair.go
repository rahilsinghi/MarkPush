package cmd

import (
	"fmt"

	"github.com/charmbracelet/lipgloss"
	"github.com/spf13/cobra"
)

var pairCmd = &cobra.Command{
	Use:   "pair",
	Short: "Pair with an iOS device via QR code",
	Long: `Generate a QR code in the terminal for your iPhone to scan.
This establishes a secure, encrypted connection between devices.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		msg := lipgloss.NewStyle().
			Foreground(lipgloss.Color("214")).
			Render("⚠ Pairing is not yet implemented. Coming in Phase 2.")
		fmt.Println(msg)
		return nil
	},
}

func init() {
	rootCmd.AddCommand(pairCmd)
}
