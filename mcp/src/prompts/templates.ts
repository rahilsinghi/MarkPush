/**
 * Pre-built markdown templates for common document types.
 * Used by the push_template tool.
 */

export const TEMPLATE_NAMES = ["code-review", "meeting-notes", "daily-summary", "bug-report"] as const;
export type TemplateName = (typeof TEMPLATE_NAMES)[number];

export function renderTemplate(name: string, data: Record<string, unknown>): string {
  switch (name) {
    case "code-review":
      return renderCodeReview(data);
    case "meeting-notes":
      return renderMeetingNotes(data);
    case "daily-summary":
      return renderDailySummary(data);
    case "bug-report":
      return renderBugReport(data);
    default:
      throw new Error(`Unknown template: ${name}. Available: ${TEMPLATE_NAMES.join(", ")}`);
  }
}

function renderCodeReview(data: Record<string, unknown>): string {
  const code = String(data.code ?? "");
  const language = String(data.language ?? "");
  const context = data.context ? String(data.context) : undefined;
  const summary = String(data.summary ?? "Code review");
  const issues = Array.isArray(data.issues) ? data.issues : [];
  const suggestions = Array.isArray(data.suggestions) ? data.suggestions : [];

  let md = `# Code Review: ${summary}\n\n`;
  if (context) md += `> ${context}\n\n`;

  if (code) {
    md += `## Code\n\n\`\`\`${language}\n${code}\n\`\`\`\n\n`;
  }

  if (issues.length > 0) {
    md += `## Issues Found\n\n`;
    for (const issue of issues) {
      const i = typeof issue === "object" && issue !== null ? issue as Record<string, unknown> : { description: String(issue) };
      const severity = i.severity ? `**[${String(i.severity).toUpperCase()}]** ` : "";
      md += `- ${severity}${i.description ?? String(issue)}\n`;
    }
    md += "\n";
  }

  if (suggestions.length > 0) {
    md += `## Suggestions\n\n`;
    for (const s of suggestions) {
      md += `- ${String(s)}\n`;
    }
    md += "\n";
  }

  return md;
}

function renderMeetingNotes(data: Record<string, unknown>): string {
  const topic = String(data.topic ?? "Meeting Notes");
  const date = String(data.date ?? new Date().toLocaleDateString());
  const attendees = Array.isArray(data.attendees) ? data.attendees.map(String) : [];
  const keyPoints = Array.isArray(data.key_points) ? data.key_points.map(String) : [];
  const actionItems = Array.isArray(data.action_items) ? data.action_items.map(String) : [];
  const decisions = Array.isArray(data.decisions) ? data.decisions.map(String) : [];

  let md = `# ${topic}\n\n**Date:** ${date}\n`;

  if (attendees.length > 0) {
    md += `**Attendees:** ${attendees.join(", ")}\n`;
  }
  md += "\n";

  if (keyPoints.length > 0) {
    md += `## Key Points\n\n`;
    for (const p of keyPoints) md += `- ${p}\n`;
    md += "\n";
  }

  if (decisions.length > 0) {
    md += `## Decisions\n\n`;
    for (const d of decisions) md += `- ✅ ${d}\n`;
    md += "\n";
  }

  if (actionItems.length > 0) {
    md += `## Action Items\n\n`;
    for (const a of actionItems) md += `- [ ] ${a}\n`;
    md += "\n";
  }

  return md;
}

function renderDailySummary(data: Record<string, unknown>): string {
  const date = String(data.date ?? new Date().toLocaleDateString());
  const completed = Array.isArray(data.tasks_completed) ? data.tasks_completed.map(String) : [];
  const blockers = Array.isArray(data.blockers) ? data.blockers.map(String) : [];
  const tomorrow = Array.isArray(data.tomorrow) ? data.tomorrow.map(String) : [];

  let md = `# Daily Summary — ${date}\n\n`;

  if (completed.length > 0) {
    md += `## Completed\n\n`;
    for (const t of completed) md += `- ✅ ${t}\n`;
    md += "\n";
  }

  if (blockers.length > 0) {
    md += `## Blockers\n\n`;
    for (const b of blockers) md += `- ⚠️ ${b}\n`;
    md += "\n";
  }

  if (tomorrow.length > 0) {
    md += `## Plan for Tomorrow\n\n`;
    for (const t of tomorrow) md += `- ${t}\n`;
    md += "\n";
  }

  return md;
}

function renderBugReport(data: Record<string, unknown>): string {
  const title = String(data.title ?? "Bug Report");
  const steps = Array.isArray(data.steps) ? data.steps.map(String) : [];
  const expected = String(data.expected ?? "");
  const actual = String(data.actual ?? "");
  const severity = data.severity ? String(data.severity) : undefined;
  const environment = data.environment ? String(data.environment) : undefined;

  let md = `# Bug: ${title}\n\n`;
  if (severity) md += `**Severity:** ${severity}\n`;
  if (environment) md += `**Environment:** ${environment}\n`;
  md += "\n";

  if (steps.length > 0) {
    md += `## Steps to Reproduce\n\n`;
    steps.forEach((s, i) => (md += `${i + 1}. ${s}\n`));
    md += "\n";
  }

  if (expected) md += `## Expected Behavior\n\n${expected}\n\n`;
  if (actual) md += `## Actual Behavior\n\n${actual}\n\n`;

  return md;
}
