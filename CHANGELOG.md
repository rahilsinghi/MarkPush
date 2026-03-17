# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Project foundation: README, LICENSE, CLAUDE.md, contributing guidelines
- Repository structure and build configuration
- **CLI Tool (Go):** cobra commands (push, pair, watch, history, config),
  protocol types, AES-256-GCM encryption, PBKDF2 key derivation, Viper config
- **WiFi Transport:** mDNS/Bonjour discovery, WebSocket push with ack
- **Pairing:** QR code generation in terminal, ephemeral HTTP pairing server,
  shared key derivation and storage
- **Watch Mode:** fsnotify-based directory watcher with debounce, auto-push
  on .md file changes
- **Cloud Transport:** Supabase REST API sender, auto-select (WiFi first,
  cloud fallback)
- **iOS App (SwiftUI + TCA):** Feed, Reader, Library, Pairing, Settings features,
  SwiftData models, WiFi/Cloud receivers, CryptoKit encryption, Keychain storage
- **Cloud Relay:** Supabase schema with RLS, realtime subscriptions, 7-day TTL
- **CI/CD:** GitHub Actions for Go and iOS, GoReleaser config
- Release script for tagged releases
