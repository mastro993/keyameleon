# Updates

Sparkle 2 handles updates, configured in `Info.plist` and mirrored by `UpdatePolicy`:

- Automatic checks at most every 24 hours. Automatic download and installation are off and cannot be enabled; critical updates also need approval.
- No system profiling and no Keyameleon-generated identifiers.
- Feed: `https://mastro993.github.io/keyameleon/appcast.xml`. GitHub Pages serves project sites under the lowercase repository path; a capitalized path made `0.4.0` and `0.4.1` unable to update. The Release workflow now reads the feed URL back from the built app and checks that the live feed serves the new version before publishing.
- Only Official Release builds include `SUPublicEDKey`. Debug and CI builds never start Sparkle.
- **Gentle reminders:** Keyameleon is a background app, so for a scheduled update it temporarily becomes a regular app with Dock badge `1`. Paying attention clears the badge, and the end of the update session restores menu-bar-only mode (during Guided setup the Dock icon stays). Sparkle still shows its own alert. A check the person starts changes nothing.
