# Official Release starts from a version-increment dispatch

An Official Release starts only when the lead maintainer runs the Release
`workflow_dispatch` on `main` and selects `major`, `minor`, or `patch`. The
workflow calculates from the latest Official Release tag, commits the updated
marketing version to `main`, and creates the annotated `vMAJOR.MINOR.PATCH` tag
on that commit after artifacts exist. A human tag push does not publish, so a
pushed tag cannot skip environment approval or green CI.
