# Official Release

## What it is

An **Official Release** is a Keyameleon version the person with release authority
publishes for users. It is:

| Property | Mechanism |
| --- | --- |
| Source-traceable | Tag `vMAJOR.MINOR.PATCH` on the public history; `release-evidence.json` binds artifact SHA-256 to that tag and commit |
| Developer ID signed | `codesign` with Developer ID Application identity |
| Secure timestamp | `--timestamp` on codesign |
| Hardened runtime | `ENABLE_HARDENED_RUNTIME=YES` / `--options=runtime` |
| Notarized | `notarytool submit --wait` |
| Stapled | `stapler staple` on the app before final zip |
| Updates | Sparkle `appcast.xml` EdDSA-signed; feed URL in Info.plist |
| Channel | Stable. Artifacts on GitHub Releases: zip, source archive, appcast, evidence |

The latest Official Release is the only **Supported Release** (`SECURITY.md`).

## License

- SPDX: `GPL-3.0-only` (`LICENSE`)
- Third-party: `THIRD_PARTY_NOTICES.md`

## Start an Official Release

1. Ensure the intended commit is on `main` and CI is green for that commit.
2. Run **Actions → Official Release → Run workflow** on `main`.
3. Set **version** to Semantic Versioning core only, for example `1.2.3`.
   Do not type a leading `v`. Pre-release values (`1.2.3-beta.1`) fail.
4. Job `verify` checks default branch, unused tag `vMAJOR.MINOR.PATCH`, and a
   successful `CI` run on that commit.
5. Job `produce` targets the `official-release` GitHub Environment.
6. Lead-maintainer approval is required when the repository plan supports
   environment required reviewers. Configure that protection under
   Settings → Environments → `official-release` → Required reviewers.
7. After approval, CI builds, signs, notarizes, staples, writes `appcast.xml`
   and `release-evidence.json`, creates the annotated tag, and publishes the
   GitHub Release. The zip is never overwritten.

A human tag push does **not** start the workflow. Do not `git push` Official
Release tags. Same version twice fails. A new version on the same `main` commit
is allowed.

Release notes are `git log` subjects since the previous Official Release tag
(no merges, no authors). First Official Release: `Initial Official Release`.
Same commit as the previous tag: `No source changes since <tag>`.

## First Official Release

Host check on 2026-08-14: Environment `official-release` exists and has **no**
secrets, **no** variables, and **no** required reviewers. Repository secrets
are empty. Branch ruleset `Main branch protection` is active (pull request +
required check `Build and test`). There is **no** tag ruleset. There are **no**
tags and **no** GitHub Releases. `produce` will fail until the secrets below
exist.

Use Official Release version `0.1.0` for the first publish (`MARKETING_VERSION`
in `project.yml`). The workflow creates tag `v0.1.0`. Do not create that tag
yourself.

### 1. Developer ID certificate (once)

1. In Apple Developer → Certificates, create **Developer ID Application**
   (not Developer ID Installer, not Apple Development).
2. Install it in the login keychain on a trusted Mac.
3. Keychain Access → My Certificates → that identity → Export… → `.p12`.
   Set a password. Never commit the file.
4. Encode it as a single line:

   ```sh
   base64 < DeveloperID.p12 | tr -d '\n' > developer-id.p12.b64
   ```

### 2. Notary API key (once)

1. [App Store Connect → Integrations → Team Keys](https://appstoreconnect.apple.com/access/integrations/api).
2. Generate an API key with access that can submit notarization (Developer or
   Admin). Download `AuthKey_<KEY_ID>.p8` once. Note **Key ID** and **Issuer ID**.
3. Team ID is the 10-character Membership ID (Xcode → Settings → Accounts, or
   Apple Developer membership).
4. Encode the key as a single line:

   ```sh
   base64 < AuthKey_<KEY_ID>.p8 | tr -d '\n' > authkey.p8.b64
   ```

### 3. Sparkle EdDSA keys (once)

Use Sparkle **2.9.5** tools (same pin as `Package.resolved`):

```sh
curl -fsSL -o Sparkle.tar.xz \
  https://github.com/sparkle-project/Sparkle/releases/download/2.9.5/Sparkle-2.9.5.tar.xz
tar -xJf Sparkle.tar.xz
./bin/generate_keys
./bin/generate_keys -x sparkle_eddsa_private.key
```

`generate_keys` prints `SUPublicEDKey` (base64). That value is
`SPARKLE_PUBLIC_ED_KEY`. The exported file is `SPARKLE_PRIVATE_ED_KEY`. Strip
a trailing newline before storing:

```sh
tr -d '\n' < sparkle_eddsa_private.key > sparkle_eddsa_private.key.one
```

Keep the Keychain copy and the export offline. Losing the private key blocks
signed updates for existing Official Release binaries.

### 4. GitHub Environment `official-release`

Already created. Settings → Environments → `official-release`:

1. **Deployment branches and tags** → Selected branches → `main` only.
   Produce runs on `workflow_dispatch` from `main` before the tag exists.
2. **Required reviewers** → lead maintainer, if the plan allows it. Private
   free-tier often cannot enable this. Then only the lead maintainer may
   dispatch.
3. **Environment secrets** (not repository secrets):

   ```sh
   gh secret set APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_P12_BASE64 \
     --env official-release < developer-id.p12.b64
   gh secret set APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD \
     --env official-release
   gh secret set APPLE_API_KEY_ID --env official-release
   gh secret set APPLE_API_ISSUER_ID --env official-release
   gh secret set APPLE_API_KEY_P8_BASE64 --env official-release < authkey.p8.b64
   gh secret set APPLE_TEAM_ID --env official-release
   gh secret set SPARKLE_PRIVATE_ED_KEY --env official-release \
     < sparkle_eddsa_private.key.one
   gh secret set SPARKLE_PUBLIC_ED_KEY --env official-release
   ```

   Password / ID secrets: `gh secret set NAME --env official-release` then paste
   at the prompt. No newline in the value.

4. Optional environment variable `CODESIGN_IDENTITY` if the identity name is
   not `Developer ID Application`. Leave unset by default.

Confirm names only (values stay hidden):

```sh
gh secret list --env official-release
```

Expect the eight names above. Then delete the local p12, p8, and key copies
from the working tree (`trash`, not git). Keep offline backups.

### 5. Tag ruleset

Settings → Rules → Rulesets → New tag ruleset:

- Name: `Official Release tags`
- Enforcement: Active
- Target tags: `v[0-9]+.[0-9]+.[0-9]+` (Official Release pattern only)
- Rules: Restrict creations, Restrict updates, Restrict deletions
- Bypass list: **GitHub Actions**, bypass mode **Always**

Humans must not create `vMAJOR.MINOR.PATCH` tags. The workflow pushes the tag
with `GITHUB_TOKEN`. If Actions cannot bypass, publish fails at `git push`.

### 6. Land this workflow on `main`

1. Merge the pull request (squash is the only allowed merge method).
2. `verify` waits up to 45 minutes for **Build and test** on that SHA.
   You may dispatch as soon as the merge commit is on `main`.
   If CI fails, `verify` fails. If CI never starts, `verify` times out.

### 7. Negative checks (optional, no tag created)

From **Actions → Official Release → Run workflow**:

| Use workflow from | version | Expected |
| --- | --- | --- |
| this feature branch | `0.1.0` | `verify` fails: not default branch |
| `main` | `v0.1.0` | `verify` fails: tag would be `vv0.1.0` |
| `main` | `0.1.0-beta.1` | `verify` fails: not SemVer core |
| `main` | `0.1.0` while CI is running | `verify` waits; continues when **Build and test** succeeds |

### 8. Publish `0.1.0`

1. Actions → Official Release → Run workflow.
2. Use workflow from: `main`.
3. version: `0.1.0` (no `v`).
4. Run workflow.
5. `verify` must go green.
6. `produce` waits on Environment `official-release`. Approve if reviewers
   are configured.
7. `produce` signs, notarizes, staples, writes notes
   (`Initial Official Release`), creates annotated tag `v0.1.0`, and creates
   the GitHub Release. There is no dry-run dispatch. `SKIP_NOTARIZE=1` local
   builds are not an Official Release.

If `produce` fails **before** the tag exists, fix the cause and re-run the
failed job or dispatch `0.1.0` again. If the tag exists and the GitHub Release
does not, re-run **failed jobs** on that run (not a new dispatch). If the
GitHub Release exists, `0.1.0` is done. The next Official Release needs a new
version.

### 9. Verify the first Official Release

```sh
TAG=v0.1.0
VERSION=0.1.0
gh release view "$TAG"
gh release download "$TAG" --dir /tmp/keyameleon-v0.1.0
cd /tmp/keyameleon-v0.1.0
shasum -a 256 -c <(jq -r '"\(.artifactSHA256)  \(.artifactFileName)"' release-evidence.json)
jq '{tag,semanticVersion,gitCommit,feedURLString}' release-evidence.json
git rev-parse "${TAG}^{commit}"   # must match gitCommit
curl -fsSL https://github.com/mastro993/Keyameleon/releases/latest/download/appcast.xml | head
unzip -l "Keyameleon-${VERSION}.zip"
unzip -q "Keyameleon-${VERSION}.zip" -d /tmp/keyameleon-app
spctl --assess --verbose /tmp/keyameleon-app/Keyameleon.app
xcrun stapler validate /tmp/keyameleon-app/Keyameleon.app
```

`evidence.tag` must be `v0.1.0`. `feedURLString` must be
`https://github.com/mastro993/Keyameleon/releases/latest/download/appcast.xml`.
The appcast enclosure URL must be
`https://github.com/mastro993/Keyameleon/releases/download/v0.1.0/Keyameleon-0.1.0.zip`.
Release notes Changes line must be `Initial Official Release`.

Install that `.app` on a clean Mac (not a Debug build). **Check for Updates…**
must start (EdDSA key is present). It must not offer a newer version than
`0.1.0`.

## Repository protection (host settings)

These controls live in GitHub settings, not in application source. The lead
maintainer **must** enable them before the first Official Release. Without them,
the workflows exist but the “protected” acceptance criteria are not enforced.

### `main` branch (Settings → Branches / Rulesets)

- Require a pull request before merging
- Require status check: `CI` / Build and test
- Restrict who can push / bypass

### Tags (Settings → Rulesets)

- Block humans from creating tags matching `v*.*.*` (Official Release pattern)
- Allow GitHub Actions (`GITHUB_TOKEN`) to create those tags
- `workflow_dispatch` is the only supported way to mint an Official Release tag

### `official-release` environment (Settings → Environments)

- Required reviewers: lead maintainer (or release-authority account)
- Deployment branches: default branch only (`main`). Produce runs from
  `workflow_dispatch` on `main` before the tag exists
- Secrets listed below exist only as environment or repository secrets — never in git

**Plan note (2026-08-10):** private free-tier API returned that required reviewers
and branch protection need a higher plan or a public repository. Until that is
enabled, only the lead maintainer may run Official Release `workflow_dispatch`,
and the environment exists without enforced approval.

## Secrets (never commit)

| Secret | Purpose |
| --- | --- |
| `APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_P12_BASE64` | Developer ID Application certificate (p12, base64) |
| `APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD` | p12 password |
| `APPLE_API_KEY_ID` | App Store Connect API key id for notarytool |
| `APPLE_API_ISSUER_ID` | API issuer id |
| `APPLE_API_KEY_P8_BASE64` | API private key `.p8` contents (base64) |
| `APPLE_TEAM_ID` | Developer team id |
| `SPARKLE_PRIVATE_ED_KEY` | Sparkle EdDSA private key (generate_appcast / sign_update) |
| `SPARKLE_PUBLIC_ED_KEY` | Sparkle EdDSA public key embedded as `SUPublicEDKey` at release build |

Optional variable: `CODESIGN_IDENTITY` (defaults to `Developer ID Application`).

Recovery material for certificates and Sparkle keys stays offline or in the
maintainer secret store — not in this repository.

### Local key material gitignore

Local files such as `*.p12`, `*.p8`, `sparkle_eddsa_private.key`, and `secrets/`
are ignored. Do not force-add them.

## Local production (maintainers)

With secrets exported in the shell:

```sh
export RELEASE_TAG=v1.2.3
# export all secrets listed above
./Scripts/official-release.sh
```

Artifacts land in `dist/`:

- `Keyameleon-<version>.zip`
- `Keyameleon-source-<version>.tar.gz`
- `appcast.xml`
- `release-evidence.json`

`SKIP_NOTARIZE=1` builds and signs without notarization. Local artifacts and a
manual GitHub Release are **not** an Official Release. Only `workflow_dispatch`
on `main` publishes one.

## Evidence verification

```sh
cd dist
jq -r '"\(.artifactSHA256)  \(.artifactFileName)"' release-evidence.json | shasum -a 256 -c -
```

Confirm `tag` / `gitCommit` match the public tag object.

## Sparkle public key in debug builds

Debug and CI builds may omit `SUPublicEDKey`. Official Release builds inject the
public key from `SPARKLE_PUBLIC_ED_KEY`. User-facing update checks require an
Official Release binary plus a published `appcast.xml`.
