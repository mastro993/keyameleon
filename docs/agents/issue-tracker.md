# Issue tracker: Local Markdown

Issues and specs for this repo live as Markdown files in `.scratch/`.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`. Never use one combined tickets file.
- Record triage state as a `Status:` line near the top of each issue file. See `triage-labels.md` for the role strings.
- Append comments and conversation history under an `## Comments` heading at the end of the file.

## When a skill says "publish to the issue tracker"

Create a new file under `.scratch/<feature-slug>/`. Create the directory if necessary.

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally give the path or issue number directly.

## Wayfinding operations

`/wayfinder` uses a map file with one child file for each ticket.

- **Map**: `.scratch/<effort>/map.md` contains Notes, Decisions-so-far, and Fog.
- **Child ticket**: `.scratch/<effort>/issues/NN-<slug>.md`, numbered from `01`, contains the question. A `Type:` line records the ticket type: `research`, `prototype`, `grilling`, or `task`. A `Status:` line records `claimed` or `resolved`.
- **Blocking**: A `Blocked by: NN, NN` line is near the top. A ticket is unblocked when each file that it lists has `Status: resolved`.
- **Frontier**: Scan `.scratch/<effort>/issues/` for open, unblocked, and unclaimed files. The first file by number wins.
- **Claim**: Set `Status: claimed` and save before any work.
- **Resolve**: Append the answer under an `## Answer` heading, set `Status: resolved`, then append a context pointer to Decisions-so-far in `map.md`.
