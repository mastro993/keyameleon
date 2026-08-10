# Contributing to Keyameleon

## License

Keyameleon is `GPL-3.0-only`. By contributing, you agree your contribution is
licensed under the same terms. See `LICENSE` and `THIRD_PARTY_NOTICES.md`.

## Pull requests required

Changes land on `main` only through pull requests. Direct pushes to `main` are
not the contribution path. Each PR must:

1. Pass required CI (`CI` workflow: audit, build, tests, license checks)
2. Include applicable tests for the behavior change
3. Use glossary terms from `CONTEXT.md` when naming domain concepts

## Tests

- Prefer Swift Testing under `Tests/SwiftTesting` for domain and model seams
- Use XCTest under `Tests/XCTest` for AppKit shell contracts when needed
- UI tests under `Tests/UITests` for lifecycle checks that need a running app
- Run `./Scripts/run.sh test` before requesting review

## Code of collaboration

- Keep Key Content out of saved data, logs, network output, and crash state
- Do not add analytics or automatic diagnostic upload
- Do not commit signing certificates, notarization keys, Sparkle private keys,
  or recovery material (see `docs/release/official-release.md`)

## Official Releases

Contributors do not publish Official Releases. Only a protected Semantic
Versioning tag (`vMAJOR.MINOR.PATCH`) starts the Official Release workflow, and
the `official-release` environment requires lead-maintainer approval when the
hosting plan supports environment reviewers. See `docs/release/official-release.md`
and `SECURITY.md`.
