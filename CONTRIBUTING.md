# Contributing to Keyameleon

Thanks for helping. This guide covers how to propose a change and what a pull request needs to be merged.

## Before you start

- **Small fixes**, such as typos, small bugs, and documentation, can go straight to a pull request.
- **Larger changes, new features, and UI changes** need an issue first, so the approach is agreed before you write code. Use the [bug report](.github/ISSUE_TEMPLATE/bug_report.yml) or [feature request](.github/ISSUE_TEMPLATE/feature_request.yml) template.
- **Security issues** go through private reporting, never a public issue. See [`SECURITY.md`](SECURITY.md).

To build and run the app, follow [`docs/development.md`](docs/development.md).

## Pull requests

Changes reach `main` only through pull requests. Each pull request should:

1. **Pass CI.** The required check is **Required CI gate**. For code changes it runs `./Scripts/run.sh test` on macOS 26; documentation-only changes skip the macOS job. Run the same command locally before asking for review. Details are in [`docs/testing.md`](docs/testing.md#continuous-integration).
2. **Include tests** for any behavior change. See [what to test](docs/testing.md#what-to-test).
3. **Use the product vocabulary** from [`CONTEXT.md`](CONTEXT.md) for domain concepts, such as Physical Keyboard rather than "device".
4. **Update the docs** in `docs/` that describe the behavior you changed.
5. **Have a Conventional Commit title**, such as `fix(menu): keep scroll position when a keyboard reconnects`.
6. **Follow the [pull request template](.github/pull_request_template.md).** Link the issue with `Closes #123`, and add before and after screenshots for UI changes.

## Rules that are never negotiable

- Keep Key Content out of saved data, logs, network output, and crash state.
- Do not add analytics, telemetry, or automatic diagnostic upload.
- Do not add third-party dependencies without agreement in an issue first.
- Never commit signing certificates, notarization keys, Sparkle private keys, or recovery material.

## Releases

Contributors do not publish releases. The lead maintainer starts each Official Release from the Release workflow on `main`, and it runs only after their approval. See [`docs/release/official-release.md`](docs/release/official-release.md).

## License

Keyameleon is [MIT licensed](LICENSE). By contributing, you agree that your contribution is licensed under the same terms.
