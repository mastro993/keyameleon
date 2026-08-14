# Official Release starts from workflow_dispatch

An Official Release starts only when the lead maintainer runs the Official
Release `workflow_dispatch` on `main`. The workflow creates the annotated
`vMAJOR.MINOR.PATCH` tag after artifacts exist. A human tag push does not
publish, so a pushed tag cannot skip environment approval or green CI.
