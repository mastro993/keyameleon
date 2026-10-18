# Official Release

An **Official Release** is a Keyameleon version that the lead maintainer publishes for users. Only the Release `workflow_dispatch` on `main` creates one ([ADR 0004](../adr/0004-official-release-workflow-dispatch.md)). Local builds, CI artifacts, and manually created GitHub Releases are never Official Releases.

| Property | Mechanism |
| --- | --- |
| Source-traceable | Annotated tag `vMAJOR.MINOR.PATCH`; `release-evidence.json` binds the DMG's SHA-256 to that tag and commit |
| Developer ID signed | `codesign` with the Developer ID Application identity and `--timestamp` |
| Hardened runtime | `ENABLE_HARDENED_RUNTIME=YES` / `--options=runtime` |
| Notarized and stapled | `notarytool submit --wait`, then `stapler staple` on the app and the DMG |
| Updates | EdDSA-signed Sparkle `appcast.xml`; feed URL in `Info.plist` |
| Channel | Stable, the only Channel |

The DMG holds a universal `Keyameleon.app` (Apple silicon and Intel, macOS 26 or later) and an Applications shortcut. The latest Official Release is the only Supported Release ([`SECURITY.md`](../../SECURITY.md)).

Each release publishes to three places ([ADR 0006](../adr/0006-dmg-only-official-release-distribution.md)):

- **GitHub Release:** `Keyameleon-<version>.dmg` only, plus GitHub's generated source links.
- **GitHub Pages:** the latest `appcast.xml` and every release's `releases/<tag>/release-evidence.json`, kept indefinitely.
- **Homebrew:** the `keyameleon` cask in [`mastro993/homebrew-tap`](https://github.com/mastro993/homebrew-tap), pointing at the same DMG.

Do not modify the `v0.1.0` release or its old feed. Installed `v0.1.0` copies, and `0.4.0` and `0.4.1` copies that shipped a mistyped feed URL, need one manual install of a newer DMG before they can update themselves.

## Guides

- [Publish a release](publish-a-release.md)
- [Retry a failed release](retry-a-failed-release.md)
- [Verify a release](verify-a-release.md)
- [One-time setup](one-time-setup.md)
- [Reference](reference.md)
