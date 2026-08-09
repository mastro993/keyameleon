# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`, filtering comments by `jq` and also fetching labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply or remove labels**: `gh issue edit <number> --add-label "..."` or `--remove-label "..."`
- **Close an issue**: `gh issue close <number> --comment "..."`

Infer the repo from `git remote -v`. The `gh` CLI does this automatically when it runs inside a clone.

## Pull requests as a triage surface

**PRs as a request surface: no.** Set this value to `yes` if this repo treats external PRs as feature requests. The `/triage` skill reads this value.

When the value is `yes`, PRs use the same labels and states as issues. Use the `gh pr` equivalents:

- **Read a PR**: `gh pr view <number> --comments` and `gh pr diff <number>`.
- **List external PRs for triage**: `gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments`. Keep only `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, or `NONE` in `authorAssociation`.
- **Comment, label, or close**: Use `gh pr comment`, `gh pr edit --add-label` or `--remove-label`, and `gh pr close`.

GitHub uses one number space for issues and PRs. A reference such as `#42` can be an issue or a PR. Run `gh pr view 42`. If this command does not find a PR, run `gh issue view 42`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Wayfinding operations

The `/wayfinder` skill uses one map issue and child issues.

- **Map**: Use one issue with the `wayfinder:map` label. Its body contains Notes, Decisions-so-far, and Fog. Create it with `gh issue create --label wayfinder:map`.
- **Child ticket**: Link each child issue to the map as a GitHub sub-issue. Use `gh api` with the sub-issues endpoint. If sub-issues are not enabled, add the child to a task list in the map body. Put `Part of #<map>` at the top of the child body. Add one `wayfinder:<type>` label: `research`, `prototype`, `grilling`, or `task`. Assign a claimed ticket to the driving developer.
- **Blocking**: Use GitHub native issue dependencies. Add a dependency with `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`. Get the blocker database ID with `gh api repos/<owner>/<repo>/issues/<n> --jq .id`. Do not use the issue number or `node_id`. If dependencies are not available, put `Blocked by: #<n>, #<n>` at the top of the child body. A ticket is unblocked when all blockers are closed.
- **Frontier query**: List the open children of the map. Remove each issue that has an open blocker or an assignee. The first issue in map order is the frontier.
- **Claim**: Run `gh issue edit <n> --add-assignee @me`. This is the first write of the session.
- **Resolve**: Add the answer with `gh issue comment <n> --body "<answer>"`. Close the issue. Then add a context pointer and link to Decisions-so-far in the map.
