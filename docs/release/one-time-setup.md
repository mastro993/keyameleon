# One-time setup

Part of [Official Release](official-release.md).

The lead maintainer must complete these steps before the first Official Release. Without the GitHub settings, the workflows still exist but their protections are not enforced.

## 1. Developer ID certificate

1. In Apple Developer → Certificates, create a **Developer ID Application** certificate (not Developer ID Installer or Apple Development).
2. Install it in the login keychain on a trusted Mac.
3. In Keychain Access → My Certificates, export the identity as a password-protected `.p12`. Never commit it.
4. Encode it on one line:

   ```sh
   base64 < DeveloperID.p12 | tr -d '\n' > developer-id.p12.b64
   ```

## 2. Notary API key

1. In [App Store Connect → Integrations → Team Keys](https://appstoreconnect.apple.com/access/integrations/api), generate a key with Developer or Admin access. Download `AuthKey_<KEY_ID>.p8` (only possible once) and note the **Key ID** and **Issuer ID**.
2. Note the 10-character **Team ID** from Xcode → Settings → Accounts or your Apple Developer membership.
3. Encode the key on one line:

   ```sh
   base64 < AuthKey_<KEY_ID>.p8 | tr -d '\n' > authkey.p8.b64
   ```

## 3. Sparkle EdDSA keys

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

## 4. Deploy keys

Personal repositories cannot add GitHub Actions as a ruleset bypass actor, so the workflow pushes with deploy keys that only the protected `official-release` environment can read.

- **Release deploy key.** Create an Ed25519 deploy key named `Keyameleon Release workflow` with write access to this repository. `bump` uses it to push the version commit and `publish` to push the tag and the `gh-pages` branch. No job force-pushes.
- **Homebrew tap deploy key.** `mastro993/homebrew-tap` holds casks for several products, and each product gets its own write key, so revoking one does not affect the others. The tap has no branch rules; the key pushes to `main`.

  ```sh
  ssh-keygen -t ed25519 -N "" -C "Keyameleon Release workflow" -f keyameleon-homebrew-tap
  gh repo deploy-key add keyameleon-homebrew-tap.pub --repo mastro993/homebrew-tap \
    --title "Keyameleon Release workflow" --allow-write
  ```

The cask sets `auto_updates true`, so Sparkle remains the updater: `brew upgrade` only upgrades it when the installed app's `CFBundleShortVersionString` is older than the cask, and `livecheck` reads the Sparkle feed.

## 5. `official-release` environment

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
  gh secret set KEYAMELEON_WEB_DEPLOY_HOOK --env official-release
  ```

- **Website deploy hook:** `KEYAMELEON_WEB_DEPLOY_HOOK` holds a Cloudflare Workers Builds [deploy hook](https://developers.cloudflare.com/workers/ci-cd/builds/deploy-hooks/) URL for the `main` branch of [`mastro993/Keyameleon-web`](https://github.com/mastro993/Keyameleon-web). Create it in the Cloudflare dashboard under the Worker's **Settings → Builds → Deploy Hooks**. The URL alone starts a build, so treat it as a credential; if it leaks, delete the hook and create a new one. Without this secret, `publish` warns and skips the rebuild. A separate `on: release` workflow cannot replace this step, because GitHub does not start workflows for a release published with `GITHUB_TOKEN`.
- **Optional variable:** `CODESIGN_IDENTITY`, only if the identity is not named `Developer ID Application`.

`gh secret list --env official-release` should list the eleven secrets in the [secrets table](reference.md#secrets). Then move the local `.p12`, `.p8`, and key files to the trash (never through git) and keep offline backups.

Check the live policy:

```sh
gh api repos/mastro993/Keyameleon/environments/official-release
gh api repos/mastro993/Keyameleon/environments/official-release/deployment-branch-policies
```

Expect `required_reviewers` to list `mastro993`, `prevent_self_review: false`, `can_admins_bypass: false`, and `main` as the only branch. To test the gate without changing `main`, dispatch Release, confirm that all three protected jobs wait for review, and cancel without approving. Approving pushes a real version commit.

## 6. `main` branch ruleset

Ruleset `Main branch protection`:

- Require a pull request before merging.
- Require the status check `Required CI gate`.
- Bypass actor: **Deploy keys**, mode **Always**, for the release bump. Keep every other push restricted.

## 7. Tag ruleset

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

## 8. GitHub Pages

**Settings → Pages:** deploy from the `gh-pages` branch, `/ (root)` folder.

`publish` pushes to `gh-pages` with `RELEASE_DEPLOY_KEY`, because [a push made with `GITHUB_TOKEN` does not trigger a Pages build](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site). Older evidence files are kept, and a retry cannot overwrite them with different bytes.

## 9. Optional negative checks

None of these creates a tag. From **Actions → Release → Run workflow**:

| Use workflow from | Release type | Expected |
| --- | --- | --- |
| A feature branch | `patch` | `verify` fails: not the default branch |
| A stale `main` selection | `patch` | `verify` fails because remote `main` advanced |
| `main` while CI is running | `patch` | `verify` waits, then continues when **Required CI gate** succeeds |
| `main` when the target tag exists | any | `verify` fails without changing `main` |
