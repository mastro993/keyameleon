# Product validation over formal qualification

Keyameleon validates product outcomes with one focused macOS 26 test suite and
small safety checks. We remove repeated suites, fixed stress counts, human
qualification matrices, qualification evidence files, and performance quotas because they add
process cost without proving more about normal product behavior. Official Release
artifact evidence remains separate from product validation.

CI does not run tests when a pull request or `main` commit does not change code.
Code means app source, product tests, the test runner, project and package files,
and the CI workflow. Code changes run the complete macOS product tests. One
stable required gate covers both paths. This keeps product validation for code
changes while avoiding tests when code did not change.
