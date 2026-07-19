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
  shared/
    goal-ledger.md
skills/
  shared/
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

**Preferred: let your AI agent install it.** An agent merges with whatever the
project already has — existing `AGENTS.md` / `GEMINI.md` / `CLAUDE.md`
content, ignore rules, legacy Master Plan artifacts, same-named skills —
instead of colliding with it. Paste this into your coding agent from the
target project's root:

```
Fetch https://raw.githubusercontent.com/jpbaking/goal-ledger/main/AGENT-INSTALL.md and follow its instructions exactly to install Goal Ledger into this project. Merge with — never blindly overwrite — any existing AGENTS.md, GEMINI.md, CLAUDE.md, rule, or ignore files, and report every file you created or changed.
```

The procedure in [AGENT-INSTALL.md](./AGENT-INSTALL.md) is the authoritative
install contract; the script installers below implement the same layout.

**Alternative: the script installers.** Run from the target project's root.

Linux or macOS:

```sh
curl -fsSL https://raw.githubusercontent.com/jpbaking/goal-ledger/main/install.sh | sh
```

The shell installer requires `unzip` plus either `curl` or `wget` when installing
from GitHub. Local `GOAL_LEDGER_SOURCE` installations do not require them.
GitHub archive downloads use the unauthenticated API, which is limited to 60
requests per hour per public IP. Shared CI egress can use
`GOAL_LEDGER_ARCHIVE_URL` to supply a cached or alternate archive URL.

Windows PowerShell 5.1 or newer:

```powershell
irm https://raw.githubusercontent.com/jpbaking/goal-ledger/main/install.ps1 | iex
```

The installer asks which harnesses the project supports. Each defaults to Yes.
It downloads one complete GitHub project archive into a temporary directory,
validates the canonical files, copies whole skill directories, and removes the
temporary archive. Existing root instruction content is preserved and the Goal
Ledger reference is added only when missing.

Installed rule and skill copies are generated adapters: both install paths add
them to the target's `.gitignore` (marker-guarded, idempotent). The root
instruction files (`AGENTS.md`, `GEMINI.md`, `CLAUDE.md`) and the runtime
`.goal-ledger/` directory stay committable. The appended bridge text is
conditional ("if `.agents/rules/goal-ledger.md` exists…"), so a fresh clone —
which lacks the gitignored adapters — degrades safely; re-run either install
path there to regenerate them.

| Harness | Rules | Skills |
|---|---|---|
| Codex, Antigravity | `.agents/rules/` reached through `AGENTS.md` | `.agents/skills/` |
| Gemini CLI | `.agents/rules/` imported by `GEMINI.md` | `.agents/skills/` |
| Cline | `.agents/rules/` reached through `AGENTS.md` | `.agents/skills/` |
| Claude Code | Auto-discovered `.claude/rules/` | `.claude/skills/` |

Current Cline supports the shared `.agents/skills` location, so the installer
does not create a second `.cline/skills` copy (verified against current Cline
documentation, 2026-07-19: Cline reads `AGENTS.md` and discovers
`.agents/skills`, and duplicate same-named copies in its compatibility
locations can surface twice — which is why overlapping adapters are verified
byte-for-byte instead).

### Non-interactive options

| Variable | Effect |
|---|---|
| `WITH_CLINE=1/0` | Enable or disable Cline support without prompting |
| `WITH_CLAUDE=1/0` | Enable or disable Claude Code support without prompting |
| `WITH_AGENTS=1/0` | Enable or disable Codex/Antigravity support without prompting |
| `WITH_GEMINI=1/0` | Enable or disable Gemini CLI support without prompting; inherits `WITH_AGENTS` when unset |
| `ASSUME_YES=1` | Answer Yes to installer-owned prompts |
| `GOAL_LEDGER_REF=<ref>` | Install from a branch, tag, or commit other than `main` |
| `GOAL_LEDGER_REPO=<owner/repo>` | Install from a GitHub fork |
| `GOAL_LEDGER_SOURCE=<path>` | Install from a local source checkout for development or CI |
| `GOAL_LEDGER_ARCHIVE_URL=<url>` | Override the GitHub archive URL |
| shell target argument or `$env:GOAL_LEDGER_TARGET` | Install into a directory other than the current one |

Example:

```sh
WITH_CLINE=0 WITH_CLAUDE=1 WITH_AGENTS=1 WITH_GEMINI=0 sh install.sh /path/to/project
```

## Updating and migration

Re-run the installer with the same harness selection. Canonical Goal Ledger rule
and skill copies are refreshed in place. Whole same-named Goal Ledger skill
directories are replaced so retired bundled resources cannot linger.

The installer assumes every unrelated existing adapter belongs to the target
project or another tool. It never deletes legacy core reasoning, DOX,
compose-helper, lazyway-io-design, workflow, command, or skill files. It only
inspects same-purpose Master Plan and Goal Ledger locations, reports possible
duplicates, and leaves non-destination files untouched. Review and remove stale
adapters manually when appropriate.

Ignore files are preserved. If `.clineignore` may hide the canonical `.agents`
path, the installer reports the matching pattern instead of removing it. It also
reports same-named global skills. When both Cline and Claude are selected, their
required adapter copies are verified byte-for-byte and the installer asks you to
confirm through Cline's skill list that each name resolves once; ignore files are
not treated as an unverified skill-registry filter.

If `.tmp-agent-scratch/MASTER-PLAN.md` contains an unfinished legacy plan, the
installer stops before downloading or changing anything so that work can be
finished, abandoned, or deliberately migrated first.

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

The main skill includes a read-only `scripts/validate_goal_ledger.py` helper. The
Goal Ledger skills run it when Python 3 is available and fall back to manual
contract checks otherwise. It validates file structure, status mirrors,
dependencies, lifecycle invariants, Git baselines, branches, and commit trailers.

## Development

Run the local checks with:

```sh
python3 -m unittest discover -s tests -v
```

CI runs the validator and installer fixtures on Linux, macOS, Windows PowerShell
5.1, and PowerShell 7.

## License

This repository is licensed under [0BSD](LICENSE).
