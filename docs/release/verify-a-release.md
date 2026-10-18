# Verify a release

Part of [Official Release](official-release.md).

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
