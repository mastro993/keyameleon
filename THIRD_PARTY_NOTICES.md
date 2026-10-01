# Third-party notices

Keyameleon is licensed under `MIT`. This file lists third-party software
distributed with or linked into Keyameleon Official Release artifacts.

## Sparkle

- Project: [Sparkle](https://sparkle-project.org)
- Source: https://github.com/sparkle-project/Sparkle
- Version: see `Keyameleon.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- License: MIT (and embedded external licenses for bsdiff/bspatch and other components
  as shipped by the Sparkle project)

The complete upstream `LICENSE` from the resolved Sparkle binary distribution
is copied unchanged into `Contents/Resources/Licenses/Sparkle-LICENSE.txt` in
Keyameleon.app. It includes Sparkle's MIT license and its embedded external
licenses. The build checks the binary distribution version against
`Package.resolved` before copying the notices; release verification checks the
embedded framework version too.

Choose **Licenses and Notices** in either About screen to read these texts
offline, alongside Keyameleon's MIT license and this index. The repository's
`LICENSE` and this file are the sources for `LICENSE.txt` and
`THIRD_PARTY_NOTICES.md` in the same bundled folder.

## Apple system frameworks

Keyameleon links Apple system frameworks (AppKit, Carbon, CoreHID, IOKit,
ServiceManagement, SwiftData, SwiftUI, and others provided by macOS). Those
frameworks remain Apple software and are not redistributed as source in this
repository.
