# Review guideline: Shell scripts

CodeRabbit applies this to `Scripts/**/*.sh` (see `knowledge_base.code_guidelines` in `.coderabbit.yaml`).

Bash under `set -euo pipefail`. Check quoting, failure propagation through pipes and subshells, and that
destructive steps (`run.sh reset`, `tccutil`, LaunchServices unregistering, deleting data folders) target
only Keyameleon's own bundle IDs and paths, and that the default `run.sh reset` never touches the
release identity (docs/adr/0008-separate-debug-identity.md). The safety audit in `run.sh` is a security
control; flag any weakening of its patterns. Release scripts must keep releases immutable: an existing version fails and
retries reuse the exact signed bytes. Secrets never reach logs or command arguments visible in CI output.
