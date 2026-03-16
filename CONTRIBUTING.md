# Contributing to MarkPush

Thanks for your interest in contributing! Here's how to get started.

## Development Setup

1. **Fork and clone** the repository
2. **Install prerequisites:**
   - Go 1.22+ (for CLI)
   - Xcode 16+ (for iOS)
   - `golangci-lint` for Go linting
   - `swiftlint` and `swiftformat` for Swift
3. **Run the dev setup script:**
   ```bash
   ./scripts/dev-setup.sh
   ```

## Making Changes

1. Create a branch from `main`: `git checkout -b feat/your-feature`
2. Make your changes
3. Write or update tests (80%+ coverage required)
4. Run tests:
   ```bash
   make test    # Go tests
   make lint    # Go lint
   ```
5. Commit using conventional commits:
   ```
   feat: add watch mode for directory monitoring
   fix: handle empty markdown files gracefully
   docs: update pairing protocol documentation
   ```
6. Open a pull request against `main`

## Commit Message Format

```
<type>: <description>

<optional body>
```

**Types:** `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`

## Code Style

### Go
- Follow standard Go conventions (`gofmt`, `go vet`)
- Wrap errors: `fmt.Errorf("context: %w", err)`
- Table-driven tests
- All exported functions need godoc comments

### Swift
- SwiftUI only (no UIKit for new code)
- TCA pattern for all features
- `async/await` only (no Combine, no completion handlers)
- Run `swiftformat` before committing

## Reporting Bugs

Open an issue with:
- Steps to reproduce
- Expected vs actual behavior
- OS and version info
- CLI version (`markpush --version`)

## Feature Requests

Open an issue describing:
- The problem you're trying to solve
- Your proposed solution
- Any alternatives you've considered
