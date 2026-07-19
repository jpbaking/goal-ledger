# Goal Ledger

Goal Ledger is a project-local, git-tracked execution record for coding agents,
installed into the discovery paths used by the selected agent harnesses.

There are no separate model tiers. Codex, Claude Code, Google Antigravity,
Gemini CLI, and Cline receive the same semantic rules and skills.

It provides crash recovery, inter-agent handoff, branch isolation, phase commits,
and optional safe squash-on-acceptance through a committed `.goal-ledger/`.

DOX, compose-helper, and lazyway-io-design are not vendored or installed by this
repository. Install those projects separately if a project needs them.

## Canonical source layout

```text
rules/
  goal-ledger.md
skills/
  goal-ledger/SKILL.md
  goal-ledger-resume/SKILL.md
  goal-ledger-status/SKILL.md
  goal-ledger-abandon/SKILL.md
```

The installer copies these canonical files into harness discovery locations. No
commands or workflow wrappers are generated; the Agent Skills files are the
workflows.

The former core reasoning rules are intentionally separate from this repository
and are available as a public
[core-reasoning-rules.md Gist](https://gist.github.com/jpbaking/a4d69ef15315f0189420bee1baa43c7a).

## Install

Run the installer from the target project's root.

Linux or macOS:

```sh
curl -fsSL https://raw.githubusercontent.com/jpbaking/goal-ledger/main/install.sh | sh
```

Windows PowerShell 5.1 or newer:

```powershell
irm https://raw.githubusercontent.com/jpbaking/goal-ledger/main/install.ps1 | iex
```

The installer asks which harnesses the project supports. Each defaults to Yes.
It preserves existing `AGENTS.md` and `CLAUDE.md` content and adds its rule
references only when missing.

| Harness | Rules | Skills |
|---|---|---|
| Codex, Antigravity, Gemini | `.agents/rules/` reached through `AGENTS.md` | `.agents/skills/` |
| Cline | `.agents/rules/` reached through `AGENTS.md` | `.agents/skills/` |
| Claude Code | `.claude/rules/` imported by `CLAUDE.md` | `.claude/skills/` |

Current Cline supports the shared `.agents/skills` location, so the installer
does not create a second `.cline/skills` copy.

### Non-interactive options

| Variable | Effect |
|---|---|
| `WITH_CLINE=1/0` | Enable or disable Cline support without prompting |
| `WITH_CLAUDE=1/0` | Enable or disable Claude Code support without prompting |
| `WITH_AGENTS=1/0` | Enable or disable Codex/Antigravity/Gemini support without prompting |
| `ASSUME_YES=1` | Answer Yes to installer-owned prompts |
| `GOAL_LEDGER_REF=<ref>` | Install from a branch, tag, or commit other than `main` |
| shell target argument or `$env:GOAL_LEDGER_TARGET` | Install into a directory other than the current one |

Example:

```sh
WITH_CLINE=0 WITH_CLAUDE=1 WITH_AGENTS=1 sh install.sh /path/to/project
```

## Updating and migration

Re-run the installer with the same harness selection. Canonical rule and skill
copies are refreshed in place.

When upgrading from the former multi-component release, the installer removes
the known generated adapters for core reasoning, DOX, compose-helper,
lazyway-io-design, legacy Master Plan commands/workflows and skills, and
duplicate Cline skill copies. It intentionally does not remove:

- DOX framework text already merged into a project's `AGENTS.md`, because that
  file may also contain project-owned guidance;
- `compose-helper.sh`, `compose-helper.ps1`, or `compose-helper.env` already in a
  target project, because application scripts may depend on them.
- a completed legacy `.tmp-agent-scratch/`, because it may still be useful history.

Remove those manually after reviewing the target project if they are no longer
wanted. If `.tmp-agent-scratch/MASTER-PLAN.md` contains an unfinished legacy plan,
the installer stops before changing anything so that work can be finished,
abandoned, or deliberately migrated first.

## Using Goal Ledger

Ask your agent to use the `goal-ledger` skill for multi-phase or long-running
work. Use `goal-ledger-resume` for recovery or handoff, `goal-ledger-status` for
a read-only report, and `goal-ledger-abandon` to stop while preserving history.

Goal Ledger writes `GOAL.md` and `phase-NNNN.md` files directly under
`.goal-ledger/`. The directory is committed, never gitignored, and remains in the
accepted result. `GOAL.md` records an immutable baseline, a stable Goal ID, the
chosen Git strategy, and handoff state. Commit trailers connect Git history to
the goal without trying to store a moving `HEAD` hash inside the commit itself.

The workflow strongly recommends an isolated `goal/<goal-id>` branch. Staying on
the current branch is supported, but automatic squashing is refused when commits
are foreign, interleaved, merged, published, or otherwise unsafe to rewrite.
When a goal branch was pushed for remote handoff, retain its history and use a
squash merge during integration instead of rewriting the published branch.

Harness-specific menus may expose different invocation syntax, but successful use
does not depend on a slash-command wrapper.

## License

This repository is licensed under [0BSD](LICENSE).
