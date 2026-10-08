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

## Publish a release

Complete [one-time setup](#one-time-setup) first.

1. Make sure the intended commit is on `main` and CI is green for it.
2. Open **Actions → Release → Run workflow** on `main`.
3. Choose the **release type**: `patch`, `minor`, or `major`. From `v0.2.3` these produce `0.2.4`, `0.3.0`, and `1.0.0`.
4. **`verify`** checks that the run is on the default branch, calculates the version from the latest Official Release tag, rejects an existing tag or Release, and waits up to 45 minutes for **Required CI gate** on the commit. It fails if CI fails, times out if CI never starts, and fails if `main` advances in the meantime.
5. Wait until **`bump`**, **`produce`**, and **`publish`** all show as pending review for `official-release`, then approve them together. Approving before all three are pending can require another approval, because approval does not carry over to jobs that become pending later.
6. **`bump`** sets `MARKETING_VERSION`, regenerates the Xcode project, and pushes `chore(release): X.Y.Z` to `main`. The commit lands before tests run, so if `produce` fails the bump stays on `main` but nothing is tagged or published.
7. **`produce`** waits for that exact bump commit, then tests, builds, signs, notarizes, staples, and checks the Sparkle signature on a fresh macOS runner, with a read-only token and no deploy key. It uploads the DMG, `appcast.xml`, and `release-evidence.json` as one workflow artifact. Any ZIP used for notarization is discarded.
8. **`publish`** runs on a fresh Ubuntu runner using scripts from the dispatch commit. It checks the evidence against the bump commit, creates the annotated tag, publishes the GitHub Release, and verifies the public DMG. It then publishes the appcast and evidence to GitHub Pages and verifies the served files. Last, `Scripts/publish-homebrew-cask.sh` sets the cask's `version` and `sha256` from the verified DMG and pushes `keyameleon X.Y.Z` to the tap.

**Timeouts.** `produce` polls `main` for the bump up to 180 times at 10-second intervals (30 minutes). `publish` polls for the artifact up to 180 times at 30-second intervals (90 minutes). API requests can stretch both. API errors, an unexpected `main`, and ambiguous or expired artifacts fail immediately. If `produce` fails before uploading, `publish` waits out its limit without publishing anything.

**Never push release tags by hand.** A tag push does not start the workflow, and the tag ruleset blocks it. There is no dry run; local `SKIP_NOTARIZE=1` builds are not Official Releases.

**Release notes** come from `Scripts/official-release-notes.sh`: categorized change sections, a separator, and a `Changelog` section with the full comparison and linked commits, excluding merge commits and the version bump. Entries carry pull request links and `@login` authors when GitHub has them. GitHub renders the release page's Contributors card from those mentions, so the notes contain no contributors section.

## Retry a failed release

Fix the cause, then rerun **failed jobs** on the same run (`gh run rerun RUN_ID --failed`). Do not start a new dispatch or rerun all jobs; a new dispatch for an existing version fails. A retry may need a new approval.

- A retry reuses the bump commit only while it is still the tip of `main`.
- If the workflow artifact exists, the retry restores and validates those exact signed bytes and skips `produce`. An unreadable, ambiguous, expired, or invalid artifact stops the retry.
- A missing artifact may be rebuilt only before a tag or GitHub Release exists. After publication has begun, investigate manually instead of producing new signed bytes.
- Publication reuses a matching tag and asset, uploads a missing asset from the artifact, and deletes an empty `starter` asset left by a failed upload. It never replaces an uploaded asset or changes published evidence. A mismatched tag, asset, or evidence stops for manual investigation.
- An identical Pages retry makes no commit. The cask step makes no commit when the cask already matches, and stops without pushing if the same version has a different checksum or the cask is already newer.
- Failure before the GitHub Release leaves the previous feed in place. Failure after the Release but before Pages leaves the DMG downloadable for the retry.

## Verify a release

```sh
TAG=v1.2.3
VERSION=1.2.3
gh release view "$TAG"
gh release download "$TAG" --pattern "Keyameleon-${VERSION}.dmg" --dir /tmp/keyameleon-release
cd /tmp/keyameleon-release
curl -fsSL https://mastro993.github.io/keyameleon/appcast.xml | head
shasum -a 256 Keyameleon-${VERSION}.dmg
codesign --display --verbose=2 Keyameleon-${VERSION}.dmg
xcrun stapler validate Keyameleon-${VERSION}.dmg
hdiutil attach Keyameleon-${VERSION}.dmg -nobrowse -mountpoint /tmp/keyameleon-mounted
test -d /tmp/keyameleon-mounted/Keyameleon.app
test -L /tmp/keyameleon-mounted/Applications
xcrun stapler validate /tmp/keyameleon-mounted/Keyameleon.app
hdiutil detach /tmp/keyameleon-mounted
git rev-parse "${TAG}^{commit}"   # compare with the evidence's gitCommit
brew update && brew info --cask mastro993/tap/keyameleon   # expect VERSION
```

Download the evidence from Pages and check its hash:

```sh
curl -fsSL -o release-evidence.json \
  "https://mastro993.github.io/keyameleon/releases/${TAG}/release-evidence.json"
jq '{tag,semanticVersion,gitCommit,artifactFileName,feedURLString}' release-evidence.json
shasum -a 256 -c <(jq -r '"\(.artifactSHA256)  \(.artifactFileName)"' release-evidence.json)
```

Expect:

- `tag` is `$TAG`, and `gitCommit` is the tag's peeled commit.
- `feedURLString` is `https://mastro993.github.io/keyameleon/appcast.xml`.
- The appcast enclosure URL is `https://github.com/mastro993/Keyameleon/releases/download/TAG/Keyameleon-VERSION.dmg`.
- The release notes have categorized sections, `### Changelog`, and a full comparison link, and no `### Contributors` section.

Finally, install the app on a clean Mac, not a Debug build. **Check for Updates…** must start and must not install anything without approval.

## One-time setup

The lead maintainer must complete these steps before the first Official Release. Without the GitHub settings, the workflows still exist but their protections are not enforced.

### 1. Developer ID certificate

1. In Apple Developer → Certificates, create a **Developer ID Application** certificate (not Developer ID Installer or Apple Development).
2. Install it in the login keychain on a trusted Mac.
3. In Keychain Access → My Certificates, export the identity as a password-protected `.p12`. Never commit it.
4. Encode it on one line:

   ```sh
   base64 < DeveloperID.p12 | tr -d '\n' > developer-id.p12.b64
   ```

### 2. Notary API key

1. In [App Store Connect → Integrations → Team Keys](https://appstoreconnect.apple.com/access/integrations/api), generate a key with Developer or Admin access. Download `AuthKey_<KEY_ID>.p8` (only possible once) and note the **Key ID** and **Issuer ID**.
2. Note the 10-character **Team ID** from Xcode → Settings → Accounts or your Apple Developer membership.
3. Encode the key on one line:

   ```sh
   base64 < AuthKey_<KEY_ID>.p8 | tr -d '\n' > authkey.p8.b64
   ```

### 3. Sparkle EdDSA keys

Use the Sparkle tools that match `Package.resolved` (currently 2.10.0):

```sh
curl -fsSL -o Sparkle.tar.xz \
  https://github.com/sparkle-project/Sparkle/releases/download/2.10.0/Sparkle-2.10.0.tar.xz
tar -xJf Sparkle.tar.xz
./bin/generate_keys
./bin/generate_keys -x sparkle_eddsa_private.key
tr -d '\n' < sparkle_eddsa_private.key > sparkle_eddsa_private.key.one
```

`generate_keys` prints the public key (`SUPublicEDKey`), which becomes `SPARKLE_PUBLIC_ED_KEY`. The exported file becomes `SPARKLE_PRIVATE_ED_KEY`: the raw 44-character base64 seed only, without quotes, PEM headers, or a trailing newline. Anything else makes `generate_appcast` fail with `Private key not decoded from the argument because it isn't base64 encoded`.

Keep the Keychain copy and the export offline. Losing the private key means existing installs can no longer receive signed updates.

### 4. Deploy keys

Personal repositories cannot add GitHub Actions as a ruleset bypass actor, so the workflow pushes with deploy keys that only the protected `official-release` environment can read.

- **Release deploy key.** Create an Ed25519 deploy key named `Keyameleon Release workflow` with write access to this repository. `bump` uses it to push the version commit and `publish` to push the tag and the `gh-pages` branch. No job force-pushes.
- **Homebrew tap deploy key.** `mastro993/homebrew-tap` holds casks for several products, and each product gets its own write key, so revoking one does not affect the others. The tap has no branch rules; the key pushes to `main`.

  ```sh
  ssh-keygen -t ed25519 -N "" -C "Keyameleon Release workflow" -f keyameleon-homebrew-tap
  gh repo deploy-key add keyameleon-homebrew-tap.pub --repo mastro993/homebrew-tap \
    --title "Keyameleon Release workflow" --allow-write
  ```

The cask sets `auto_updates true`, so Sparkle remains the updater: `brew upgrade` only upgrades it when the installed app's `CFBundleShortVersionString` is older than the cask, and `livecheck` reads the Sparkle feed.

### 5. `official-release` environment

In **Settings → Environments → `official-release`**:

- **Deployment branches:** `main` only.
- **Required reviewers:** `mastro993`, with self-review allowed so the sole maintainer can approve their own dispatch, and administrator bypass disabled.
- **Environment secrets** (not repository secrets). Paste IDs and passwords at the prompt, without a trailing newline:

  ```sh
  gh secret set APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_P12_BASE64 \
    --env official-release < developer-id.p12.b64
  gh secret set APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD --env official-release
  gh secret set APPLE_API_KEY_ID --env official-release
  gh secret set APPLE_API_ISSUER_ID --env official-release
  gh secret set APPLE_API_KEY_P8_BASE64 --env official-release < authkey.p8.b64
  gh secret set APPLE_TEAM_ID --env official-release
  gh secret set SPARKLE_PRIVATE_ED_KEY --env official-release < sparkle_eddsa_private.key.one
  gh secret set SPARKLE_PUBLIC_ED_KEY --env official-release
  gh secret set RELEASE_DEPLOY_KEY --env official-release < keyameleon-release-workflow
  gh secret set HOMEBREW_TAP_DEPLOY_KEY --env official-release < keyameleon-homebrew-tap
  ```

- **Optional variable:** `CODESIGN_IDENTITY`, only if the identity is not named `Developer ID Application`.

`gh secret list --env official-release` should list the ten secrets in the [secrets table](#secrets). Then move the local `.p12`, `.p8`, and key files to the trash (never through git) and keep offline backups.

Check the live policy:

```sh
gh api repos/mastro993/Keyameleon/environments/official-release
gh api repos/mastro993/Keyameleon/environments/official-release/deployment-branch-policies
```

Expect `required_reviewers` to list `mastro993`, `prevent_self_review: false`, `can_admins_bypass: false`, and `main` as the only branch. To test the gate without changing `main`, dispatch Release, confirm that all three protected jobs wait for review, and cancel without approving. Approving pushes a real version commit.

### 6. `main` branch ruleset

Ruleset `Main branch protection`:

- Require a pull request before merging.
- Require the status check `Required CI gate`.
- Bypass actor: **Deploy keys**, mode **Always**, for the release bump. Keep every other push restricted.

### 7. Tag ruleset

Ruleset `Official Release tags`:

- Enforcement: Active
- Target tags: `v[0-9]*`
- Rules: Restrict creations, Restrict updates, Restrict deletions, Block force pushes
- Bypass actor: **Deploy keys**, mode **Always**

GitHub rulesets use globs, so this pattern also matches some invalid names; `Scripts/verify-official-release-tag.sh` enforces the exact `vMAJOR.MINOR.PATCH` format before the workflow creates a tag. `GITHUB_TOKEN` cannot bypass the ruleset, which is why the workflow pushes tags with `RELEASE_DEPLOY_KEY`.

Check the live ruleset:

```sh
gh api repos/mastro993/Keyameleon/rulesets/20859991 \
  --jq '{name, enforcement, conditions, rules, bypass_actors}'
```

Expect `enforcement: "active"`, include `["refs/tags/v[0-9]*"]` with no exclusions, the rules `creation`, `update`, `deletion`, and `non_fast_forward`, and one `DeployKey` bypass with a null ID and `always` mode.

**Still unverified.** On 2026-09-30 an ordinary account's push of a disposable tag was rejected with `GH013` (`Cannot create ref due to creations being restricted.`). That proves creation is blocked, not that updates and deletions are blocked or that the deploy key can bypass. To finish, use the release deploy key from secure storage, or an authorized workflow in the `official-release` environment, to create, update, and delete a disposable invalid-SemVer tag that matches the glob. Confirm an ordinary account cannot update or delete it, and that it is gone afterwards. Never use a valid version tag or dispatch a release for this.

### 8. GitHub Pages

**Settings → Pages:** deploy from the `gh-pages` branch, `/ (root)` folder.

`publish` pushes to `gh-pages` with `RELEASE_DEPLOY_KEY`, because [a push made with `GITHUB_TOKEN` does not trigger a Pages build](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site). Older evidence files are kept, and a retry cannot overwrite them with different bytes.

### 9. Optional negative checks

None of these creates a tag. From **Actions → Release → Run workflow**:

| Use workflow from | Release type | Expected |
| --- | --- | --- |
| A feature branch | `patch` | `verify` fails: not the default branch |
| A stale `main` selection | `patch` | `verify` fails because remote `main` advanced |
| `main` while CI is running | `patch` | `verify` waits, then continues when **Required CI gate** succeeds |
| `main` when the target tag exists | any | `verify` fails without changing `main` |

## Reference

### Secrets

| Secret | Purpose |
| --- | --- |
| `APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_P12_BASE64` | Developer ID Application certificate (`.p12`, base64) |
| `APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD` | `.p12` password |
| `APPLE_API_KEY_ID` | App Store Connect API key ID for `notarytool` |
| `APPLE_API_ISSUER_ID` | API issuer ID |
| `APPLE_API_KEY_P8_BASE64` | API private key (`.p8`, base64) |
| `APPLE_TEAM_ID` | Developer team ID |
| `SPARKLE_PRIVATE_ED_KEY` | Sparkle EdDSA private key for `generate_appcast` and `sign_update` |
| `SPARKLE_PUBLIC_ED_KEY` | Sparkle EdDSA public key, embedded as `SUPublicEDKey` |
| `RELEASE_DEPLOY_KEY` | Private half of this repository's release deploy key |
| `HOMEBREW_TAP_DEPLOY_KEY` | Private half of the write deploy key on `mastro993/homebrew-tap` |

Recovery material for certificates and Sparkle keys stays offline or in the maintainer's secret store. `.gitignore` excludes local key files such as `*.p12`, `*.p8`, `sparkle_eddsa_private.key`, and `secrets/`; never force-add them.

Only Official Release builds embed `SUPublicEDKey`. Debug and CI builds omit it and never start Sparkle, so update checks need an Official Release binary and a published appcast.

### Bundled licenses

Every build includes `Contents/Resources/Licenses/` in `Keyameleon.app`, and **Settings → About** opens these texts offline:

- `LICENSE.txt`, from the repository's `LICENSE` (SPDX `MIT`)
- `THIRD_PARTY_NOTICES.md`, from the repository file of the same name
- `Sparkle-LICENSE.txt`, the complete `LICENSE` from the resolved Sparkle binary, including its embedded component licenses

Before code signing, the Xcode build runs `Scripts/bundle-licenses.py --copy --build-dir "$BUILD_DIR"`. It finds the resolved Sparkle artifact under `SourcePackages` (for both normal and archive builds) and checks its version against `Package.resolved`. Missing or empty sources and version mismatches fail the build. No legal text is duplicated in the repository.

`Scripts/official-release.sh` runs the same check without `--copy` on the app before signing and on the app inside the DMG (mounted read-only) before signing the DMG, and also checks the embedded Sparkle framework version. It never repairs a signed app. To check an app yourself:

```sh
python3 Scripts/bundle-licenses.py \
  --app /path/to/Keyameleon.app \
  --package-root /path/to/DerivedData/SourcePackages
```

### Local production

Maintainers can produce artifacts locally with the secrets exported in the shell:

```sh
export RELEASE_TAG=v1.2.3
# export every secret in the table above
./Scripts/official-release.sh
```

This writes `Keyameleon-<version>.dmg`, `appcast.xml`, and `release-evidence.json` to `dist/`. Check the evidence with:

```sh
cd dist
jq -r '"\(.artifactSHA256)  \(.artifactFileName)"' release-evidence.json | shasum -a 256 -c -
```

`SKIP_NOTARIZE=1` signs without notarizing. Local artifacts are never an Official Release.

### Missing `v0.4.5` evidence

`v0.4.5` predates permanent evidence on Pages, and `releases/v0.4.5/release-evidence.json` has not been backfilled. Its only copy is in workflow run `36336223890` (artifact `official-release-0.4.5`, source commit `71514f9790593beda36885f6cc7aa03ba0e87e58`), which expires on 2026-12-26.

`Scripts/publish-release-pages.sh` cannot backfill it anymore, because it always publishes evidence together with the feed. With the artifact's `v0.4.5` appcast it refuses to replace the newer live feed, and with the current feed the appcast no longer matches the `v0.4.5` evidence and DMG. Backfilling needs an evidence-only publish that copies the original `release-evidence.json` byte for byte, without touching the feed. Never regenerate evidence or dispatch another release for this.
