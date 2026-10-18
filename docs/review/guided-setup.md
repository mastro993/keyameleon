# Review guideline: Guided setup

CodeRabbit applies this to `Sources/Features/Onboarding/**` (see `knowledge_base.code_guidelines` in `.coderabbit.yaml`).

Guided setup has three saved stages (Permissions, Keyboards, Ready). Permission UI follows the real
`IOHIDCheckAccess` decision, not a stored flag. Completion is saved first and handled once. Until setup
completes, there is no status item and no Input Source is selected. Check docs/choices/guided-setup.md
and docs/choices/input-monitoring-permission.md, and that the footer stays reachable with large text.
