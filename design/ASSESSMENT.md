# Keyameleon design assessment

## Scope and verdict

Assessed the active `design.pen` canvas: all 28 top-level objects, reusable components, nested instance overrides, both appearances, and desktop-context previews. This is a design-system assessment, not a Swift source-code or running-app audit.

**Design consistency improved; runtime macOS conformance remains to be validated.** No literal colors or unbound typography/spacing/radius/stroke style values remained in the final recursive canvas audit. No meaningful content overflow remained (0.01 px tolerance for imported vector rounding).

## Findings and changes

| Area | Finding | Change |
| --- | --- | --- |
| Typography | Inter mixed with SF Pro; fractional menu sizes; oversized onboarding typography | One `font-sans` token using SF Pro; named type and weight tokens; 13 pt body, 12 pt callout, 11 pt caption, 26 pt large title |
| Colors | Hardcoded paints in components, imported symbols, and instance replacements | Semantic light/dark colors throughout, including window controls, selection, artwork shadows and transparent fills |
| Contrast | Light-blue links, pale secondary text, white step labels on bright accents, variable sidebar-image contrast | Darker light-mode links/buttons; separate link and button accents; legible muted text; stronger sidebar image shade |
| Progress | Three separately authored onboarding indicators; inconsistent completed-step text | One shared progress component with per-step overrides |
| Input sources | Six separately authored pickers with inconsistent chevrons, sizing and type | One shared picker with width/value overrides across onboarding and Settings |
| Settings | Light/dark screens separately repeated configuration overrides | Dark screens instance the canonical corresponding Settings screen; shared shell/content slots retained |
| Existing reuse | Menu, keyboard states, onboarding sidebar/buttons, About window and SF Symbol assets already shared | Preserved these components rather than rebuilding them |
| Paused menu | Resume action still displayed pause symbol | Both paused appearances use shared play symbol |
| Layout | Ready preview clipped the bottom of its menu; desktop frames slightly smaller than wallpaper; rotated key artwork overflowed | Expanded Ready preview and its screen; matched desktop bounds; adjusted artwork position |
| Organization | Unnamed symbols/instances and generic desktop frame names | Added descriptive names |
| Numeric styling | Spacing, radius, typography, strokes and effects hardcoded | Bound supported styling properties to variables; retained documented dimensions as described below |

Final canvas contains 34 reusable components. Light/dark differences remain in semantic color variables or genuine state/content overrides, not separate copied layouts.

## Measured contrast

Ratios calculated from opaque token pairs, not sampled from screenshots:

| Pair | Light | Dark |
| --- | ---: | ---: |
| Primary text / Settings surface | 16.83:1 | 13.68:1 |
| Secondary text / Settings surface | 6.26:1 | 7.55:1 |
| Muted text / Settings surface | 5.99:1 | 6.74:1 |
| Link accent / Settings surface | 5.57:1 | 6.80:1 |
| Button label / button accent | 5.57:1 | 5.23:1 |
| Muted menu text / opaque reference surface | 5.10:1 | 6.74:1 |
| Success text / window | 5.08:1 | 9.81:1 |

These tested pairs exceed 4.5:1. Translucent menus still require testing over real wallpapers; these figures are not a blanket accessibility certification.

## Numeric values: editor limitation

The active editor accepts width/height variable references but reads them back as numeric values. It also did not retain attempted sizing metadata. Claiming zero literal numbers would therefore be inaccurate.

- Colors, font family/size/weight, line height, spacing, padding, corner radii, stroke widths, relevant opacity and effects use variables.
- Non-glyph dimension mappings are recorded in each applicable node's **context**, e.g. `width=$onboarding-width`. These are handoff references, not live bindings.
- Existing fixed dimensions are retained where needed; flexible containers continue using `fill_container` or content sizing.
- Canvas coordinates, artwork rotation, SVG geometry/viewBoxes, image crops and imported glyph proportions remain numeric. These describe placement/artwork, not reusable style decisions.
- The editor resolves variable-backed opacity using percentage units; `opacity-muted=55` produces 0.55 opacity.

Use native layout and named dimensions during implementation rather than copying every canvas measurement into SwiftUI.

## Verification checklist

- [x] Inspected all top-level objects and recursively audited instance overrides.
- [x] Visually checked menu states, keyboard variants, all onboarding stages, Settings tabs and About in both appearances across the assessment.
- [x] Checked foreground/background token contrast for key text roles.
- [x] Checked resolved layouts; no overflow larger than 0.01 px remained.
- [x] Recursive audit found no literal paint or unbound typography/spacing/radius/stroke style values.
- [x] Checked variable references for missing definitions.
- [x] Cleared work-in-progress placeholders.
- [ ] Validate actual SwiftUI implementation against this design.
- [ ] Test keyboard navigation, focus rings, VoiceOver names/roles and keyboard shortcuts in the running app.
- [ ] Test Increase Contrast, Reduce Transparency and user-selected system accent colors.
- [ ] Test localized/long keyboard names, larger text preferences and resizing.
- [ ] Test translucent menus against varied wallpapers and native window materials.

Imported SF Symbol groups may produce an editor `fit_content`/non-flex warning or subpixel rounding warnings. Groups intentionally preserve their vector structure; the resolved bounds check excludes only numerical excess below 0.01 px.

## macOS implementation requirements

Canvas hex values are design approximations, not dynamic platform colors. Use semantic system foreground/background roles, native controls, system font and system materials in the app. Respect the user's accent choice rather than enforcing the preview blue. Native controls should supply hover, pressed, disabled and keyboard-focus states; static canvas images cannot establish these behaviors.

## Apple references

- [Color](https://developer.apple.com/design/human-interface-guidelines/color): semantic roles, system accent preference, appearance and increased-contrast variants.
- [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode): adaptive colors, vibrancy, sufficient contrast across appearances.
- [Typography](https://developer.apple.com/design/human-interface-guidelines/typography): SF Pro and macOS text styles, including 13 pt body text.
