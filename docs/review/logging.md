# Review guideline: Logging

CodeRabbit applies this to `Sources/Features/Shared/Log*.swift` (see `knowledge_base.code_guidelines` in `.coderabbit.yaml`).

The Log File never contains Key Content, Physical Keyboard Identity values, file paths, or system error
text; keyboard lines use the Physical Keyboard Name. Writing is best effort and must never block or
interrupt switching. Check rotation (1 MiB, five files), `O_APPEND` handling, and that nothing is written
before `Log.start`.
