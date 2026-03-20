# MarkPush LinkedIn Post Campaign

## Post 1 — The Launch (use when sharing the GitHub link)

The irony of 2025: AI can design your entire system in minutes.

You still have to read it on the same screen you coded it on.

So I built MarkPush — an open-source tool that pushes markdown from your terminal to your iPhone. One command:

markpush push README.md

Three ways to push:
- CLI: markpush push file.md
- Pipe: cat output.md | markpush push --stdin
- MCP: Claude pushes directly to your phone (npm: @markpush/mcp-server)

End-to-end encrypted. WiFi or cloud. Works offline.

The iOS app is free to build and run — no $99 Apple Developer fee needed. Clone, build in Xcode with a free account, and it's on your phone forever.

Built with Go, Swift (SwiftUI + TCA), TypeScript. Fully open source.

GitHub: https://github.com/rahilsinghi/MarkPush

#opensource #ios #swift #golang #ai #vibecoding #buildinpublic

---

## Post 2 — The MCP / Claude angle (for the AI builder audience)

Claude can now push documents directly to your iPhone.

I published @markpush/mcp-server on npm. One line to install:

claude mcp add markpush -- npx -y @markpush/mcp-server

Then just say: "Push this code review to my phone."

It encrypts the content with AES-256-GCM, sends it over Supabase Realtime, and it appears in a native iOS reader with custom typography and syntax highlighting.

6 tools. 4 prompt templates. 32 tests. All open source.

MCP is underrated. It turns Claude from a chat window into an operating system for your dev workflow.

npm: https://www.npmjs.com/package/@markpush/mcp-server
GitHub: https://github.com/rahilsinghi/MarkPush

#mcp #claudeai #anthropic #ai #npm #typescript #buildinpublic

---

## Post 3 — The "$0 iOS app" angle (for indie devs)

Hot take: The $99/yr Apple Developer fee stops more side projects from reaching phones than any technical challenge.

I built a full iOS app — SwiftUI, TCA, SwiftData, end-to-end encryption, cloud sync — and it runs on my iPhone permanently. Cost: $0.

The trick: You don't need the App Store for personal tools.

Xcode + free Personal Team = build once, use forever. No TestFlight, no App Store review, no annual fee.

Developers avoid iOS because they think they need to publish. You don't. Build it for yourself. Build it for your team. Share the source code and let others build it too.

MarkPush is open source. Clone, build, push markdown from terminal to phone.

GitHub: https://github.com/rahilsinghi/MarkPush

#ios #swift #swiftui #indiedev #opensource #buildinpublic

---

## Post 4 — The architecture deep dive (for technical audience)

Building a cross-platform encrypted push system in 2025. Here's the architecture:

Go CLI -> AES-256-GCM encrypt -> Raw TCP (WiFi) or Supabase Realtime (cloud) -> Swift iOS app -> Decrypt -> Read

Key decisions that saved weeks:
- Raw TCP over WebSocket (NWProtocolWebSocket doesn't handshake with gorilla/websocket)
- PBKDF2 key derivation from shared secret + device ID (100K iterations)
- TCA for testable iOS state management (50 tests)
- Dynamic port assignment via mDNS (no hardcoded ports, zero config)
- os.Logger instead of print() for production debugging

Stack: Go (cobra/viper), Swift (SwiftUI/TCA/SwiftData), TypeScript (MCP server), Supabase (auth + realtime + RLS)

50 TCA tests, 33 SQL assertions, 32 MCP server tests. Full E2E verified on physical device.

Everything is open source: https://github.com/rahilsinghi/MarkPush

#systemdesign #architecture #golang #swift #typescript #encryption #opensource

---

## Post 5 — The "vibe coding" narrative (personal/storytelling)

I've been vibe coding with Claude for months. It generates incredible output — docs, code reviews, architecture diagrams, meeting notes.

But I was reading all of it on my laptop. The same 14" screen I'd been staring at for 8 hours.

My phone was right there. Idle. The best reading device I own.

So I built MarkPush. Terminal to iPhone. One command. End-to-end encrypted.

Now when Claude generates a code review, I push it to my phone, grab a coffee, and read it on the couch. Context switch. Fresh eyes. Better feedback.

The tool is open source. The iOS app costs $0 to build and run. And Claude can push to it directly via MCP.

Sometimes the best developer tool isn't another VS Code extension. It's using the device that's already in your pocket.

GitHub: https://github.com/rahilsinghi/MarkPush

#vibecoding #ai #devtools #buildinpublic #opensource

---

## Posting Strategy

1. **Post 5** first (storytelling/personal) — builds curiosity, no hard sell
2. **Post 1** next day (the launch) — the main announcement with GitHub link
3. **Post 3** two days later ($0 iOS angle) — different audience, indie devs
4. **Post 2** next week (MCP/Claude angle) — targets AI builders
5. **Post 4** following week (architecture) — technical credibility

Space them 2-3 days apart. Engage with every comment. Cross-post Post 5 and Post 1 to X/Twitter as well.
