# Publish a release

Part of [Official Release](official-release.md).

Complete [one-time setup](one-time-setup.md) first.

1. Make sure the intended commit is on `main` and CI is green for it.
2. Open **Actions → Release → Run workflow** on `main`.
3. Choose the **release type**: `patch`, `minor`, or `major`. From `v0.2.3` these produce `0.2.4`, `0.3.0`, and `1.0.0`.
4. **`verify`** checks that the run is on the default branch, calculates the version from the latest Official Release tag, rejects an existing tag or Release, and waits up to 45 minutes for **Required CI gate** on the commit. It fails if CI fails, times out if CI never starts, and fails if `main` advances in the meantime.
5. Wait until **`bump`**, **`produce`**, and **`publish`** all show as pending review for `official-release`, then approve them together. Approving before all three are pending can require another approval, because approval does not carry over to jobs that become pending later.
6. **`bump`** sets `MARKETING_VERSION`, regenerates the Xcode project, and pushes `chore(release): X.Y.Z` to `main`. The commit lands before tests run, so if `produce` fails the bump stays on `main` but nothing is tagged or published.
7. **`produce`** waits for that exact bump commit, then tests, builds, signs, notarizes, staples, and checks the Sparkle signature on a fresh macOS runner, with a read-only token and no deploy key. It uploads the DMG, `appcast.xml`, and `release-evidence.json` as one workflow artifact. Any ZIP used for notarization is discarded.
8. **`publish`** runs on a fresh Ubuntu runner using scripts from the dispatch commit. It checks the evidence against the bump commit, creates the annotated tag, publishes the GitHub Release, and verifies the public DMG. It then publishes the appcast and evidence to GitHub Pages and verifies the served files. Last, `Scripts/publish-homebrew-cask.sh` sets the cask's `version` and `sha256` from the verified DMG and pushes `keyameleon X.Y.Z` to the tap. Finally it starts a rebuild of [keyameleon.app](https://keyameleon.app/), which prerenders the latest release at build time. A failed or skipped rebuild never fails the release; rerun the site's build from Cloudflare if it did not run.

**Timeouts.** `produce` polls `main` for the bump up to 180 times at 10-second intervals (30 minutes). `publish` polls for the artifact up to 180 times at 30-second intervals (90 minutes). API requests can stretch both. API errors, an unexpected `main`, and ambiguous or expired artifacts fail immediately. If `produce` fails before uploading, `publish` waits out its limit without publishing anything.

**Never push release tags by hand.** A tag push does not start the workflow, and the tag ruleset blocks it. There is no dry run; local `SKIP_NOTARIZE=1` builds are not Official Releases.

**Release notes** come from `Scripts/official-release-notes.sh`: categorized change sections, a separator, and a `Changelog` section with the full comparison and linked commits, excluding merge commits and the version bump. Entries carry pull request links and `@login` authors when GitHub has them. GitHub renders the release page's Contributors card from those mentions, so the notes contain no contributors section.
