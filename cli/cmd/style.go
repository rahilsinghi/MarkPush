package cmd

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// Brand colors derived from the MarkPush design system.
var (
	brandColor   = lipgloss.Color("63")  // Indigo — primary brand
	successColor = lipgloss.Color("78")  // Green — success states
	warnColor    = lipgloss.Color("214") // Gold — warnings
	subtleColor  = lipgloss.Color("241") // Gray — supporting text
	dimColor     = lipgloss.Color("245") // Light gray — secondary info
)

// Reusable text styles.
var (
	brandStyle   = lipgloss.NewStyle().Bold(true).Foreground(brandColor)
	successStyle = lipgloss.NewStyle().Bold(true).Foreground(successColor)
	warnStyle    = lipgloss.NewStyle().Foreground(warnColor)
	subtleStyle  = lipgloss.NewStyle().Foreground(subtleColor)
	dimStyle     = lipgloss.NewStyle().Foreground(dimColor)
	boldStyle    = lipgloss.NewStyle().Bold(true)
)

// cardStyle renders content inside a rounded border in brand indigo.
var cardStyle = lipgloss.NewStyle().
	Border(lipgloss.RoundedBorder()).
	BorderForeground(brandColor).
	Padding(0, 2)

// renderBanner returns the branded startup banner.
func renderBanner() string {
	mark := brandStyle.Render("#↑")
	name := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("255")).
		Render("M A R K P U S H")
	tag := dimStyle.Render("Push markdown to your iPhone")
	ver := subtleStyle.Render("v" + version)

	content := fmt.Sprintf("\n%s  %s\n    %s\n    %s\n", mark, name, tag, ver)
	return cardStyle.Render(content)
}

// renderCard wraps lines inside a branded card.
func renderCard(lines ...string) string {
	return cardStyle.Render(strings.Join(lines, "\n"))
}

// formatNumber adds commas to an integer (e.g., 1234 -> "1,234").
func formatNumber(n int) string {
	s := strconv.Itoa(n)
	if len(s) <= 3 {
		return s
	}

	result := make([]byte, 0, len(s)+(len(s)-1)/3)
	offset := len(s) % 3
	if offset == 0 {
		offset = 3
	}
	result = append(result, s[:offset]...)
	for i := offset; i < len(s); i += 3 {
		result = append(result, ',')
		result = append(result, s[i:i+3]...)
	}
	return string(result)
}
