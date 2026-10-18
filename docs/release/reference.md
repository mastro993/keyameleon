# Reference

Part of [Official Release](official-release.md).

## Secrets

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
| `KEYAMELEON_WEB_DEPLOY_HOOK` | Cloudflare Workers Builds deploy hook URL that rebuilds keyameleon.app from `mastro993/Keyameleon-web` `main` |

Recovery material for certificates and Sparkle keys stays offline or in the maintainer's secret store. `.gitignore` excludes local key files such as `*.p12`, `*.p8`, `sparkle_eddsa_private.key`, and `secrets/`; never force-add them.

Only Official Release builds embed `SUPublicEDKey`. Debug and CI builds omit it and never start Sparkle, so update checks need an Official Release binary and a published appcast.

## Bundled licenses

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

## Local production

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

## Missing `v0.4.5` evidence

`v0.4.5` predates permanent evidence on Pages, and `releases/v0.4.5/release-evidence.json` has not been backfilled. Its only copy is in workflow run `36336223890` (artifact `official-release-0.4.5`, source commit `71514f9790593beda36885f6cc7aa03ba0e87e58`), which expires on 2026-12-26.

`Scripts/publish-release-pages.sh` cannot backfill it anymore, because it always publishes evidence together with the feed. With the artifact's `v0.4.5` appcast it refuses to replace the newer live feed, and with the current feed the appcast no longer matches the `v0.4.5` evidence and DMG. Backfilling needs an evidence-only publish that copies the original `release-evidence.json` byte for byte, without touching the feed. Never regenerate evidence or dispatch another release for this.
