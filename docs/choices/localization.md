# Localization

Keyameleon speaks the languages of its website: English, Arabic, French, Italian, Japanese, Korean, Simplified Chinese, Spanish, and Traditional Chinese. It follows the macOS language order, including a per-app language set in System Settings › General › Language & Region, and falls back to English. Arabic lays out right to left.

- Every user-visible string, including the Input Monitoring prompt, lives in `Resources/Localization`: `Localizable.xcstrings` for the app and `InfoPlist.xcstrings` for `Info.plist` keys. Code refers to strings through the symbols Xcode generates from manually managed keys, such as `Text(.openSystemSettings)` or `String(localized: .quitApp(name))` where AppKit or a model needs a `String`.
- App Intents titles, parameters, and properties name their manual keys as string literals, such as `"intentSelectInputSource"`, because the App Intents metadata processor rejects generated symbols. `test_localization.py` accepts a literal key only in files that import `AppIntents`.
- Counts use plural variations, not Markdown inflection, so languages with other plural rules (Arabic has six forms) read correctly.
- Sentences are whole strings. A name fills a placeholder; a sentence is never assembled from translated fragments, so each language can order its words.
- macOS terms (System Settings, Input Monitoring, Login Items, Quit & Reopen, menu bar, input source) use Apple's own translation for each language, as macOS shows them.
- Names stay as they are: Keyameleon, Physical Keyboard Names, product names, and Input Source names, which macOS already localizes. The built-in keyboard's fallback product name stays English because it is saved data and part of a Manual Physical Keyboard Designation's signed payload.
- Logs stay English.
