# Goal Ledger

Goal Ledger is a git-tracked execution record for coding agents. Its skills
and rule install **user-global** into each harness's discovery paths; the
record itself (`.goal-ledger/`) lives committed in each project that uses it.

There are no separate model tiers. Codex, Claude Code, Google Antigravity,
Gemini CLI, Cline, and Cursor receive the same semantic rules and skills
(Cursor discovers the shared global skill copies natively).

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

The install copies these canonical files into harness discovery locations. No
commands or workflow wrappers are generated; the Agent Skills files are the
workflows.

The former core reasoning rules are intentionally separate from this repository
and are available as a public
[core-reasoning-rules.md Gist](https://gist.github.com/jpbaking/a4d69ef15315f0189420bee1baa43c7a).

## Install

Installation is agent-guided only — there are no install scripts. Your agent
merges with whatever you already have — existing global instruction files,
legacy Master Plan artifacts, same-named skills — instead of colliding with
it. Paste this into your coding agent:

```
Fetch https://raw.githubusercontent.com/jpbaking/goal-ledger/main/AGENT-INSTALL.md and follow its instructions exactly to install Goal Ledger. Merge with — never blindly overwrite — any existing global or project instruction files, and report every file you created or changed.
```

The procedure in [AGENT-INSTALL.md](./AGENT-INSTALL.md) is the authoritative
install contract. The agent acquires the sources itself (`git clone`, repo
zip, or `gh`) in a temporary directory and copies the skills and rule into
each selected harness's **user-global** discovery paths — nothing is added
to your repos. The rule self-gates on `.goal-ledger/` in the current
project, so it stays inert elsewhere.

| Harness | Rules | Skills |
|---|---|---|
| Codex | pointer block merged into `~/.codex/AGENTS.md` → `~/.agents/rules/` | `~/.agents/skills/` |
| Claude Code | pointer block merged into `~/.claude/CLAUDE.md` → `~/.agents/rules/` | `~/.claude/skills/` |
| Antigravity | auto-loaded `~/.gemini/config/rules/` | `~/.gemini/config/skills/` |
| Gemini CLI | pointer block merged into `~/.gemini/GEMINI.md` → `~/.agents/rules/` | `~/.agents/skills/` |
| Cline | global Rules directory (`~/Cline/Rules/` on Linux, `~/Documents/Cline/Rules/` on macOS/Windows) | `~/.cline/skills/` |

The install is per-user and per-machine: teammates who want the skills
install them for themselves, and every clone of a project works regardless —
the committed `.goal-ledger/` record needs no adapters to be readable.
Project-level adapter install remains an explicit opt-in documented in
AGENT-INSTALL.md.

## Updating and migration

Re-run the install with the same harness selection. Canonical Goal Ledger
rule and skill copies are refreshed in place. Whole same-named Goal Ledger
skill directories are replaced so retired bundled resources cannot linger.

The procedure assumes every unrelated existing adapter belongs to another
tool. It never deletes legacy core reasoning, DOX, compose-helper,
lazyway-io-design, workflow, command, or skill files. It only inspects
same-purpose Master Plan and Goal Ledger locations, reports possible
duplicates, and leaves non-destination files untouched. Review and remove
stale adapters manually when appropriate — including old gitignored
project-level Goal Ledger adapters from installs made before the user-global
default.

If `.tmp-agent-scratch/MASTER-PLAN.md` contains an unfinished legacy plan,
the procedure stops before changing anything so that work can be finished,
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

The main skill includes a read-only `scripts/validate_goal_ledger.py` helper. The
Goal Ledger skills run it when Python 3 is available and fall back to manual
contract checks otherwise. It validates file structure, status mirrors,
dependencies, lifecycle invariants, Git baselines, branches, and commit trailers.

## Development

Run the local checks with:

```sh
python3 -m unittest discover -s tests -v
```

CI runs the validator fixtures on Linux, macOS, and Windows.

## License

This repository is licensed under [0BSD](LICENSE).
