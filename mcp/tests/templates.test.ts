import { describe, it, expect } from "vitest";
import { renderTemplate } from "../src/prompts/templates.js";

describe("renderTemplate", () => {
  it("renders code-review", () => {
    const md = renderTemplate("code-review", {
      code: 'console.log("hello")',
      language: "javascript",
      summary: "Logger review",
      issues: [{ severity: "low", description: "Use structured logging" }],
      suggestions: ["Replace with pino"],
    });

    expect(md).toContain("# Code Review: Logger review");
    expect(md).toContain("```javascript");
    expect(md).toContain("[LOW]");
    expect(md).toContain("Replace with pino");
  });

  it("renders meeting-notes", () => {
    const md = renderTemplate("meeting-notes", {
      topic: "Sprint Planning",
      date: "2026-03-16",
      attendees: ["Alice", "Bob"],
      key_points: ["Discussed auth flow"],
      action_items: ["Alice: write spec"],
      decisions: ["Use OAuth2"],
    });

    expect(md).toContain("# Sprint Planning");
    expect(md).toContain("Alice, Bob");
    expect(md).toContain("Discussed auth flow");
    expect(md).toContain("- [ ] Alice: write spec");
    expect(md).toContain("Use OAuth2");
  });

  it("renders daily-summary", () => {
    const md = renderTemplate("daily-summary", {
      tasks_completed: ["Fixed auth bug", "Reviewed PR #42"],
      blockers: ["CI is slow"],
      tomorrow: ["Deploy v2"],
    });

    expect(md).toContain("# Daily Summary");
    expect(md).toContain("Fixed auth bug");
    expect(md).toContain("CI is slow");
    expect(md).toContain("Deploy v2");
  });

  it("renders bug-report", () => {
    const md = renderTemplate("bug-report", {
      title: "Login crash",
      steps: ["Open app", "Tap login", "Enter credentials"],
      expected: "Redirects to dashboard",
      actual: "App crashes",
      severity: "Critical",
    });

    expect(md).toContain("# Bug: Login crash");
    expect(md).toContain("1. Open app");
    expect(md).toContain("Critical");
    expect(md).toContain("App crashes");
  });

  it("throws for unknown template", () => {
    expect(() => renderTemplate("unknown", {})).toThrow("Unknown template");
  });
});
