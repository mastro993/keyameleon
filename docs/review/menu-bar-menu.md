# Review guideline: Menu bar menu

CodeRabbit applies this to `Sources/Features/Menu/**` (see `knowledge_base.code_guidelines` in `.coderabbit.yaml`).

The status item owns a native `NSMenu`; it stays on `NSStatusItem`, not `MenuBarExtra`. The middle region
shows either the keyboard list or one notice, never both. Notice buttons must be native `NSButton`s that
work during menu tracking and stay keyboard-activatable. Every command closes the menu. Ordinary updates
reuse the hosting view to keep the scroll position. Compare with docs/choices/menu-bar-menu.md.
