# Review guideline: Updates

CodeRabbit applies this to `Sources/Features/About/**` (see `knowledge_base.code_guidelines` in `.coderabbit.yaml`).

Updates use Sparkle 2 and must match `UpdatePolicy` and `Info.plist`: checks at most every 24 hours,
automatic download and install off, no system profiling. Debug and CI builds never start Sparkle. Flag
any change to the appcast URL or `SUPublicEDKey` handling.
