/**
 * Register MCP prompt templates.
 * These appear as reusable prompts in Claude Code that the LLM can use.
 */

import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

export function registerPrompts(server: McpServer) {
  server.prompt(
    "code-review",
    "Generate a formatted code review document",
    {
      code: z.string().describe("The code to review"),
      language: z.string().describe("Programming language"),
      context: z.string().optional().describe("Additional context about the code"),
    },
    ({ code, language, context }) => ({
      messages: [{
        role: "user",
        content: {
          type: "text",
          text: [
            "Review the following code and produce a structured markdown document with:",
            "1. A brief summary",
            "2. Issues found (tagged by severity: CRITICAL, HIGH, MEDIUM, LOW)",
            "3. Suggestions for improvement",
            "4. Overall assessment",
            "",
            context ? `Context: ${context}` : "",
            "",
            `\`\`\`${language}`,
            code,
            "```",
            "",
            "After generating the review, use the push_markdown tool to send it to the user's phone.",
          ].filter(Boolean).join("\n"),
        },
      }],
    }),
  );

  server.prompt(
    "meeting-notes",
    "Generate structured meeting notes",
    {
      topic: z.string().describe("Meeting topic"),
      attendees: z.string().describe("Comma-separated list of attendees"),
      notes: z.string().describe("Raw meeting notes or transcript"),
    },
    ({ topic, attendees, notes }) => ({
      messages: [{
        role: "user",
        content: {
          type: "text",
          text: [
            `Organize these meeting notes into a structured markdown document:`,
            ``,
            `**Topic:** ${topic}`,
            `**Attendees:** ${attendees}`,
            ``,
            `Raw notes:`,
            notes,
            ``,
            "Include sections: Key Points, Decisions Made, Action Items (with owners).",
            "After generating, use push_markdown to send to the user's phone.",
          ].join("\n"),
        },
      }],
    }),
  );

  server.prompt(
    "daily-summary",
    "Generate a daily standup summary",
    {
      completed: z.string().describe("What was completed today"),
      blockers: z.string().optional().describe("Any blockers or issues"),
      plan: z.string().optional().describe("Plan for tomorrow"),
    },
    ({ completed, blockers, plan }) => ({
      messages: [{
        role: "user",
        content: {
          type: "text",
          text: [
            "Create a concise daily summary markdown document from:",
            "",
            `**Completed:** ${completed}`,
            blockers ? `**Blockers:** ${blockers}` : "",
            plan ? `**Tomorrow:** ${plan}` : "",
            "",
            "Format as a clean daily standup summary with checkmarks.",
            "After generating, use push_markdown to send to the user's phone.",
          ].filter(Boolean).join("\n"),
        },
      }],
    }),
  );

  server.prompt(
    "bug-report",
    "Generate a structured bug report",
    {
      title: z.string().describe("Bug title"),
      steps: z.string().describe("Steps to reproduce (one per line)"),
      expected: z.string().describe("Expected behavior"),
      actual: z.string().describe("Actual behavior"),
    },
    ({ title, steps, expected, actual }) => ({
      messages: [{
        role: "user",
        content: {
          type: "text",
          text: [
            "Create a structured bug report markdown document:",
            "",
            `**Title:** ${title}`,
            `**Steps:** ${steps}`,
            `**Expected:** ${expected}`,
            `**Actual:** ${actual}`,
            "",
            "Include severity assessment and environment details if inferrable.",
            "After generating, use push_markdown to send to the user's phone.",
          ].join("\n"),
        },
      }],
    }),
  );
}
