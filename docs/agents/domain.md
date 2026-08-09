# Domain docs

This file tells engineering skills how to use domain documentation in this repo.

## Layout

This repo uses a single-context layout:

/
├── CONTEXT.md
├── docs/adr/
└── src/

## Before exploration

Read these files before code exploration:

- `CONTEXT.md` at the repo root
- Relevant ADRs in `docs/adr/`

If a file does not exist, continue silently. Do not propose its creation before it is necessary. The `/domain-modeling` skill creates domain documentation when it resolves terms or decisions.

## Use glossary vocabulary

When output names a domain concept, use its term from `CONTEXT.md`. This rule applies to issue titles, refactor proposals, hypotheses, and test names. Do not use a synonym that the glossary tells you to avoid.

If the glossary does not contain the necessary concept, first check that the concept is valid. If it is valid, record the gap for `/domain-modeling`.

## Flag ADR conflicts

If output conflicts with an ADR, identify the conflict. Do not silently replace the decision.
