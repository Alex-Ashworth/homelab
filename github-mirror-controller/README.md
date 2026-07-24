# GitHub Mirror Controller

GitHub Mirror Controller maintains outbound, one-way copies of selected GitHub repositories on GitLab and Gitea. GitHub is the sole source of truth.

**Runtime state:** Running on 2026-07-23.

## Scope and flow

The checked-in configuration selects repositories owned by the configured GitHub account, including private repositories while excluding archived repositories, forks, and templates. The controller polls every five minutes and performs full Git/LFS and metadata reconciliation daily.

```text
GitHub REST API + Git/LFS → controller → GitLab and Gitea Git/API
```

It creates missing destination repositories and mirrors branches, tags, Git notes, Git LFS objects, force updates, and ref deletions. It mirrors issues, ordinary comments, labels, and currently open pull requests; fork pull requests use reserved synthetic branches.

## State and overwrite behavior

A durable SQLite state database maps GitHub repository, issue, pull-request, and comment IDs to destination IDs. This state must be backed up to prevent duplicate metadata records after recovery.

Destination refs under `refs/heads/*`, `refs/tags/*`, and `refs/notes/*` are force-updated and pruned. Do not treat a destination mirror as a writable source: destination-only branches and tags are deleted on a later reconciliation.

## Limitations

- Shadow issues and pull requests are bot-owned; merged GitHub PRs are closed downstream rather than natively merged.
- Historical closed PRs are not backfilled during the first reconciliation.
- Inline review threads, approvals, checks, reactions, assignments, milestones, attachments, releases, packages, Actions artifacts, and wikis are not mirrored.
- Label colors and descriptions are not mirrored; GitLab labels containing commas are omitted.
- Deleted GitHub issues and comments are not propagated by polling.
- Destination issue and pull-request numbers need not match GitHub numbers.
- Repositories removed from the selected scope are retained downstream; entire repositories are not deleted automatically.

## Runtime design

Docker Compose supplies GitHub, GitLab, and Gitea tokens as secrets without exposing their values in configuration. The controller is read-only, drops all capabilities, enables `no-new-privileges`, uses a temporary `/tmp`, and persists its SQLite state in the named `mirror-state` volume.

The project requires Python 3.11 or newer, has zero declared runtime Python dependencies, exposes the `github-mirror-controller` CLI entry point, and includes a pytest test suite in `tests/`.
