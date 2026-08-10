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
| Channel | Single GitHub Releases channel for zip, source archive, appcast, evidence |

The latest Official Release is the only **Supported Release** (`SECURITY.md`).

## License

- SPDX: `GPL-3.0-only` (`LICENSE`)
- Third-party: `THIRD_PARTY_NOTICES.md`

## Start an Official Release

1. Ensure `main` is green and the intended commit is reviewed.
2. Create and push an annotated tag that matches Semantic Versioning core only:

   ```sh
   git tag -a v1.2.3 -m "Keyameleon 1.2.3"
   git push origin v1.2.3
   ```

3. The `Official Release` workflow runs only for tags matching `v[0-9]+.[0-9]+.[0-9]+`.
4. Job `produce` targets the `official-release` GitHub Environment.
5. Lead-maintainer approval is required when the repository plan supports
   environment required reviewers. Configure that protection under  
   Settings → Environments → `official-release` → Required reviewers.
6. After approval, CI builds, signs, notarizes, staples, generates the appcast,
   writes evidence, and publishes the GitHub Release.

Pre-release tags (`v1.2.3-beta.1`) and bare versions (`1.2.3`) do **not** start
the workflow.

## Repository protection (host settings)

These controls live in GitHub settings, not in application source. The lead
maintainer **must** enable them before the first Official Release. Without them,
the workflows exist but the “protected” acceptance criteria are not enforced.

### `main` branch (Settings → Branches / Rulesets)

- Require a pull request before merging
- Require status checks: `CI` / Build and test, and `DCO`
- Restrict who can push / bypass

### Tags (Settings → Rulesets)

- Restrict who can create tags matching `v*.*.*` (Official Release pattern) to the
  lead maintainer / release-authority account

### `official-release` environment (Settings → Environments)

- Required reviewers: lead maintainer (or release-authority account)
- Deployment branches/tags: limit to Official Release tags when the UI allows
- Secrets listed below exist only as environment or repository secrets — never in git

**Plan note (2026-08-10):** private free-tier API returned that required reviewers
and branch protection need a higher plan or a public repository. Until that is
enabled, only the lead maintainer must push Official Release tags, and the
environment exists without enforced approval.
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

`SKIP_NOTARIZE=1` builds and signs without notarization (not an Official Release).

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
