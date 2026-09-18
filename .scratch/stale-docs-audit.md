# Stale Docs Audit

Repo: `/Users/david/Development/apple-say`
Generated: `2026-09-15T11:04:29Z`

## Section A — Issue tracker

Detected: GitHub remote.
Suggested tracker: GitHub Issues.
CLI: `gh` found.

### Git remotes

```
origin	https://github.com/thedavidweng/apple-say.git (fetch)
origin	https://github.com/thedavidweng/apple-say.git (push)
```

## Doc inventory

Doc files scanned: `15`

## Plan-era language

_no matches_

## Forward-looking language

_no matches_

## Agent instructions

```
./AGENTS.md:9:Use the default labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`. See `docs/agents/triage-labels.md`.
./CHANGELOG.md:12:* **editor:** add localized empty document prompt ([0d02ac4](https://github.com/thedavidweng/apple-say/commit/0d02ac4671fb7a6898815ff682e6f04603777b0c))
./docs/agents/triage-labels.md:9:| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
./README.md:141:- **Personal Voice**: When selecting a macOS Personal Voice, macOS will prompt you for authorization. Apple Say uses this permission exclusively to preview and export text you explicitly choose.
```

## Owner/status sections

_no matches_

## History in references

```
./docs/personal-voice.md:74:and requests no capture permission. A signed build completed real-device
```

## Archive-folder smells

_no matches_

## Contract files containing journey language

```
./docs/adr/0001-liquid-glass-restraint.md:14:on glass. Giving Apple Say's informational bottom status labels glass capsules
./docs/adr/0001-liquid-glass-restraint.md:32:- Bottom status row: plain secondary `Text`, document format leading and
./docs/adr/0001-liquid-glass-restraint.md:33:  operational status trailing, never button-shaped. Actions never live there
./docs/agents/issue-tracker.md:42:- **Blocking**: GitHub's **native issue dependencies** — the canonical, UI-visible representation. Add an edge with `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, where `<blocker-db-id>` is the blocker's numeric database id (`gh api repos/<owner>/<repo>/issues/<n> --jq .id`, _not_ the `#number` or `node_id`). GitHub reports `issue_dependencies_summary.blocked_by` (open blockers only — the live gate). Where dependencies aren't available, fall back to a `Blocked by: #<n>, #<n>` line at the top of the child body. A ticket is unblocked when every blocker is closed.
```

## Suggested pass

1. Delete completed plans, phase docs, handoffs, archive folders, and duplicate implementation docs.
2. Move future work into the selected issue tracker.
3. Rewrite useful human docs into current-state guides.
4. Keep contracts focused on commands, payloads, events, schemas, endpoints, and env vars.
