# Retry a failed release

Part of [Official Release](official-release.md).

Fix the cause, then rerun **failed jobs** on the same run (`gh run rerun RUN_ID --failed`). Do not start a new dispatch or rerun all jobs; a new dispatch for an existing version fails. A retry may need a new approval.

- A retry reuses the bump commit only while it is still the tip of `main`.
- If the workflow artifact exists, the retry restores and validates those exact signed bytes and skips `produce`. An unreadable, ambiguous, expired, or invalid artifact stops the retry.
- A missing artifact may be rebuilt only before a tag or GitHub Release exists. After publication has begun, investigate manually instead of producing new signed bytes.
- Publication reuses a matching tag and asset, uploads a missing asset from the artifact, and deletes an empty `starter` asset left by a failed upload. It never replaces an uploaded asset or changes published evidence. A mismatched tag, asset, or evidence stops for manual investigation.
- An identical Pages retry makes no commit. The cask step makes no commit when the cask already matches, and stops without pushing if the same version has a different checksum or the cask is already newer.
- Failure before the GitHub Release leaves the previous feed in place. Failure after the Release but before Pages leaves the DMG downloadable for the retry.
