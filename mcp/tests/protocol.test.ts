import { describe, it, expect } from "vitest";
import { extractTitle, countWords, buildPushMessage } from "../src/protocol/messages.js";

describe("extractTitle", () => {
  it("extracts H1 heading", () => {
    expect(extractTitle("# Hello World\nBody")).toBe("Hello World");
  });

  it("returns Untitled for no heading", () => {
    expect(extractTitle("Just plain text")).toBe("Untitled");
  });

  it("returns Untitled for H2 only", () => {
    expect(extractTitle("## Only H2")).toBe("Untitled");
  });

  it("takes first H1 when multiple", () => {
    expect(extractTitle("# First\n# Second")).toBe("First");
  });

  it("handles empty input", () => {
    expect(extractTitle("")).toBe("Untitled");
  });

  it("trims whitespace", () => {
    expect(extractTitle("#   Spacey Title  ")).toBe("Spacey Title");
  });

  it("finds H1 after other content", () => {
    expect(extractTitle("Some text\n# Late Heading")).toBe("Late Heading");
  });
});

describe("countWords", () => {
  it("counts simple words", () => {
    expect(countWords("hello world")).toBe(2);
  });

  it("counts words with markdown", () => {
    expect(countWords("# Heading\n\nParagraph here")).toBe(4);
  });

  it("returns 0 for empty", () => {
    expect(countWords("")).toBe(0);
  });

  it("returns 0 for whitespace only", () => {
    expect(countWords("   \n\n  \t  ")).toBe(0);
  });

  it("counts single word", () => {
    expect(countWords("hello")).toBe(1);
  });
});

describe("buildPushMessage", () => {
  it("builds with auto-detected title", () => {
    const msg = buildPushMessage({
      content: "# My Doc\n\nSome content here",
      senderID: "s1",
      senderName: "host",
    });

    expect(msg.title).toBe("My Doc");
    expect(msg.version).toBe("1");
    expect(msg.type).toBe("push");
    expect(msg.word_count).toBe(6);
    expect(msg.encrypted).toBe(false);
    expect(msg.source).toBe("claude");
    expect(msg.id).toBeTruthy();
  });

  it("uses explicit title over auto-detected", () => {
    const msg = buildPushMessage({
      content: "# Original",
      title: "Override",
      senderID: "s1",
      senderName: "host",
    });

    expect(msg.title).toBe("Override");
  });

  it("base64 encodes content", () => {
    const msg = buildPushMessage({
      content: "hello",
      senderID: "s1",
      senderName: "host",
    });

    const decoded = Buffer.from(msg.content, "base64").toString("utf-8");
    expect(decoded).toBe("hello");
  });

  it("includes tags and source", () => {
    const msg = buildPushMessage({
      content: "test",
      tags: ["a", "b"],
      source: "cursor",
      senderID: "s1",
      senderName: "host",
    });

    expect(msg.tags).toEqual(["a", "b"]);
    expect(msg.source).toBe("cursor");
  });
});
