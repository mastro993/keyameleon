# Official Releases

See [Official Release](../release/official-release.md). In short:

- A release starts only from the Release `workflow_dispatch` on `main`, choosing `patch`, `minor`, or `major` ([ADR 0004](../adr/0004-official-release-workflow-dispatch.md)). The latest release tag on `main` is the version authority. The workflow commits `MARKETING_VERSION` to `main` as `chore(release): X.Y.Z`, and the tag, evidence, DMG, and GitHub Release all point at that commit.
- Each release ships one signed, notarized DMG on GitHub Releases, with the appcast and permanent evidence on GitHub Pages ([ADR 0006](../adr/0006-dmg-only-official-release-distribution.md)), and updates the Homebrew cask in the shared `mastro993/homebrew-tap` once everything else is verified, then rebuilds keyameleon.app so the site's prerendered version, changelog, and `softwareVersion` match. The cask uses `auto_updates true`, so Sparkle stays the updater. Listing in the official `homebrew/cask` waits until the project passes Homebrew's notability audit.
- A release is immutable: an existing version fails, and retries reuse the exact signed bytes.
- The appcast holds the latest item only, without Sparkle deltas.
- Release notes come from git history since the previous release, with `@login` mentions that GitHub turns into the Contributors card. There is no `CHANGELOG.md`.
- Release scripts own tag validation and evidence generation, with Python tests in `Tests/Scripts`.
- The project is MIT licensed, and every build bundles the license texts (see [Bundled licenses](../release/reference.md#bundled-licenses)).
