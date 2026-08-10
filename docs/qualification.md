# Automated Qualification

Run the deterministic automated gate with:

```sh
./Scripts/run.sh qualify
```

The gate builds Keyameleon, runs source and dependency audits, audits the built
binary, runs network and crash-surface checks, then runs the complete automated
suite 10 consecutive times. It includes a 100,000 Physical Keyboard Event
stress test. Logs and sanitized JSON evidence are written below
`.scratch/qualification/`.

The evidence verdict is one of:

- `pass`: every executed case passed.
- `fail`: a required executed case failed.
- `inconclusive`: a required case was not covered, such as a supported macOS
  major not present on the current host.

An inconclusive verdict exits with status 2. It must not be used as a release
pass.

By default, the gate expects macOS 15 and macOS 26. CI runs the gate in a
matrix, once on each supported macOS major, with
`QUALIFICATION_SUPPORTED_MACOS_VERSIONS` set to that host's major. Local runs
can set `QUALIFICATION_SUITE_RUNS` to a smaller positive value during focused
development, but release evidence requires 10.

Qualification evidence contains only platform facts, counts, statuses, and
sanitized case details. It must not contain Key Content, serial numbers,
location identifiers, exact Physical Keyboard Identity values, custom Physical
Keyboard Names, Keyboard Assignments, or raw Input Source identifiers.
