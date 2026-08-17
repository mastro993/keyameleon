# Publish an Official Release as a DMG-only GitHub Release

Keyameleon publishes one signed, notarized, and stapled disk image named
`Keyameleon-<version>.dmg` on each new GitHub Release. The disk image contains
`Keyameleon.app` and an Applications shortcut. GitHub-generated source links
remain, but Keyameleon does not attach a ZIP, custom source archive, Sparkle
appcast, or release evidence to the GitHub Release.

Sparkle publishes `appcast.xml` through GitHub Pages. Release evidence remains
a workflow artifact and does not appear on the release page. A transient ZIP
may support notarization, but it is not a release artifact. This keeps the
public download surface limited to the installer while retaining update and
source-traceability checks outside that surface.

Keyameleon does not migrate the `v0.1.0` release feed. The release stays
immutable, and installed `v0.1.0` copies may require a manual installation of a
newer disk image before they use the GitHub Pages feed.

Release notes use categorized change sections, a separator, a Changelog
section with the full tag comparison and change list, and a Contributors
section of GitHub avatar images. Keyameleon does not publish a
`CHANGELOG.md` file or a changelog artifact.
