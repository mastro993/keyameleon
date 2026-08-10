# Security policy

## Supported Release

The **latest Official Release** is the only **Supported Release**.

- An Official Release is a version published for users through the stable GitHub
  Releases channel. It is source-traceable, Developer ID signed, hardened-runtime
  enabled, timestamped, notarized, and stapled.
- Older Official Releases and any non-release builds (local Debug, CI artifacts,
  forks) are **not** Supported Releases and do not receive maintenance guarantees.
- Supported macOS versions match the deployment target of the Supported Release
  (see `project.yml` / the release notes for that version).

Users should update to the latest Official Release for security fixes.

## Private vulnerability reporting

Do **not** open a public GitHub issue for security vulnerabilities.

Report privately through one of these channels:

1. **GitHub Security Advisories** for this repository  
   https://github.com/mastro993/Keyameleon/security/advisories/new
2. If advisories are unavailable, contact the lead maintainer privately using the
   email address listed on the lead maintainer’s GitHub profile.

Include:

- Affected Official Release version (or commit) when known
- Impact and reproduction steps
- Whether Key Content, Input Monitoring, or signing keys are involved

You will receive an acknowledgment when the report is received. Please give a
reasonable window for a fix and coordinated disclosure before public discussion.

## Signing and release secrets

Signing certificates, notarization credentials, Sparkle private keys, and recovery
material **must not** appear in this repository, public issues, pull requests, or
Diagnostic Bundles. See `docs/release/official-release.md`.
