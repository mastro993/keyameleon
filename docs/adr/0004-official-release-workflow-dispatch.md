# Official Release starts from a version-increment dispatch

An Official Release starts only when the lead maintainer runs the Release
`workflow_dispatch` on `main` and selects `major`, `minor`, or `patch`. The
workflow calculates from the latest Official Release tag. One protected job
then commits the updated marketing version on the runner, tests it, and
produces and saves the signed artifacts. Only after that does it push the
commit to `main` and create the annotated `vMAJOR.MINOR.PATCH` tag on it. A
human tag push does not publish, so a pushed tag cannot skip environment
approval or the release tests.

GitHub asks required reviewers to approve each job that references a protected
environment. Separate protected jobs for the version commit, the artifacts, and
publication needed several approvals, or polling between jobs approved
together. The protected stages therefore run as ordered steps of one job, with
one approval, and a failed step stops every later step. The job pays for this
with a shared runner. The deploy key reaches that runner only after the
artifacts are saved, publication scripts come from a fresh checkout of the
dispatch commit, and only the signing step receives the signing secrets.
