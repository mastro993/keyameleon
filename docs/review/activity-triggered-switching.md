# Review guideline: Activity-Triggered Switching

CodeRabbit applies this to `Sources/Features/ActivityTriggeredSwitching/**` (see `knowledge_base.code_guidelines` in `.coderabbit.yaml`).

This is the core of the product. Check against docs/choices/activity-triggered-switching.md,
docs/choices/physical-keyboards.md, and docs/choices/input-monitoring-permission.md:
- Only Activation Activity (key press or repeat) makes a Physical Keyboard active; release-only events do
  not. The Active Physical Keyboard is never persisted.
- Switching requests the exact assigned Input Source and reads it back to verify; requests are serialized
  in observation order and tagged with a generation so stale readbacks are discarded. A failed readback
  restores the previous Input Source. There is no timed retry loop.
- Never fight a manual Input Source change; the next Activation Activity reapplies the assignment.
- An Unavailable Keyboard Assignment is kept; nothing is selected in its place.
- A Physical Keyboard Exclusion produces no Activation Activity, warnings, or retries, and is a filter,
  not a deletion. The built-in keyboard can never be excluded.
- Physical Keyboard Identity must stay stable and unique; CoreHID software IDs are not identity. A changed
  identity never moves or deletes saved data, except the one-time built-in migration in ADR 0003.
- Switching Status priority: Permission Required, Temporarily Unavailable, Paused, Ready.
- Assignments apply only after Guided setup completes (`appliesKeyboardAssignments`).
- CoreHID streams resubscribe after non-cancellation exits with a one-second delay.
Flag any path where Key Content could be stored, logged, or kept beyond classification.
