# Review guideline: App shell

CodeRabbit applies this to `Sources/App/**` (see `knowledge_base.code_guidelines` in `.coderabbit.yaml`).

Composition root and app shell. Hosted test processes must not start CoreHID observation, the lifecycle
observer, the status item, Guided setup, or Sparkle (ADR 0005). Only one Keyameleon process runs per Mac
(ADR 0002); do not weaken the single-instance lock. `Info.plist` must keep
`NSInputMonitoringUsageDescription`.
