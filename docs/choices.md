# Design decisions

This document describes how Keyameleon behaves today and why, grouped by feature. Product terms in **bold** are defined in [`CONTEXT.md`](../CONTEXT.md). The most consequential decisions also have an [ADR](adr).

When behavior changes, edit the relevant section in place rather than appending a dated entry. Superseded decisions live in git history and pull requests; [`breadcrumbs.md`](breadcrumbs.md) keeps a short chronological work log.

## Principles

- **Monitor-only.** Keyameleon observes keyboards through CoreHID in listen-only mode and changes layouts only through the Text Input Sources API. It never seizes, injects, or alters input. The [safety audit](development.md#safety-audit) enforces this.
- **Key Content stays in classification.** Keystrokes, modifiers, shortcuts, and keyboard state never reach saved data, logs, the network, or crash state.
- **No telemetry.** No analytics, no notifications, no automatic uploads. Sparkle update checks are the only network traffic.
- **Nothing silent or substituted.** Keyameleon never picks a replacement Input Source, never deletes or recreates unreadable user data, and never moves saved data between changed identities without an explicit rule or user action.
- **Copy belongs to its view.** Each view decides which strings it shows; their text, in every language, lives in the [string catalog](choices/localization.md). Domain types expose typed facts, not text.

## Sections

- [Localization](choices/localization.md)
- [Physical Keyboards](choices/physical-keyboards.md)
- [Activity-Triggered Switching](choices/activity-triggered-switching.md)
- [Input Monitoring permission](choices/input-monitoring-permission.md)
- [Persistence](choices/persistence.md)
- [Guided setup](choices/guided-setup.md)
- [Menu bar menu](choices/menu-bar-menu.md)
- [Settings](choices/settings.md)
- [Logging](choices/logging.md)
- [Updates](choices/updates.md)
- [Single instance](choices/single-instance.md)
- [Testing and CI](choices/testing-and-ci.md)
- [Official Releases](choices/official-releases.md)
