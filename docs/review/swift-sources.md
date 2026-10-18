# Review guideline: Swift sources

CodeRabbit applies this to `Sources/**/*.swift` (see `knowledge_base.code_guidelines` in `.coderabbit.yaml`).

Review against AGENTS.md and the project's strict Swift 6 settings (complete concurrency checking,
warnings as errors). Focus on:
- Concurrency: `@Observable` types are `@MainActor`; no GCD (`DispatchQueue`), no `Task.sleep(nanoseconds:)`;
  prefer async/await over callbacks; check cancellation, actor hops, `Sendable` correctness, unstructured
  `Task` lifetimes, and retain cycles in long-lived tasks or CoreHID streams.
- State: shared data uses `@Observable` with `@State`, `@Bindable`, or `@Environment`; flag new
  `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, or `@EnvironmentObject`.
- Safety: no force unwraps or `try!` unless the failure is truly unrecoverable; no `print`, `NSLog`, or
  `os_log` (use `Log`); no `CFArrayGetValueAtIndex` (bridge CF arrays to Swift arrays).
- Modern APIs: Swift-native string methods (`replacing(_:with:)`), `URL.documentsDirectory` and
  `appending(path:)`, `FormatStyle` instead of `Formatter` subclasses or `String(format:)`,
  `localizedStandardContains()` for user-input filtering.
- Structure: one type per file, files grouped by feature folder, view logic in testable models.
- SwiftUI, from AGENTS.md: `foregroundStyle()`, `clipShape(.rect(cornerRadius:))`, two-parameter or
zero-parameter `onChange`, `Button` instead of `onTapGesture` unless tap location or count matters,
no computed-property subviews (extract a `View` struct), no fixed font sizes (Dynamic Type), no
hard-coded padding or stack spacing unless the design requires it, no `AnyView`, no `GeometryReader`
when `containerRelativeFrame()` or `visualEffect()` works, no AppKit colors, `ForEach(x.enumerated(), ...)`
without `Array(...)`, `.scrollIndicators(.hidden)`, `ScrollPosition` over `ScrollViewReader`,
and image buttons with a text label. Settings and Guided setup selectors must use `PopUpPicker`
(`NSPopUpButton` + `.flexiblePush`); SwiftUI `Picker` and bordered `Menu` in a grouped `Form` hide
the System Settings pop-up box at rest on macOS 26. Check accessibility: VoiceOver labels and values,
Reduce Motion, Increase Contrast, and larger text without clipping. Colors and type come from `Theme`;
Guided setup and Settings must not drift apart. Each view owns its user-visible strings; domain types
expose typed facts, not text.
Do not repeat SwiftLint findings (file and function length, naming) unless they hide a real defect.
