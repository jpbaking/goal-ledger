# Goal Ledger file templates

Part of section 3 of the `goal-ledger` skill. Write `GOAL.md` and every
`phase-NNNN.md` in exactly these shapes; the bundled validator
(`scripts/validate_goal_ledger.py`) checks them. The status vocabulary and the
invariants are in section 3 of the skill's `SKILL.md`.

`GOAL.md`:

```markdown
# GOAL — <short title>

## Goal
- Goal ID: <stable ID>
- Outcome: <one sentence>
- Done when: <observable completion check>
- Goal status: drafting
- Goal status meaning: drafting | approved | executing | blocked-on-human | in-review | awaiting-acceptance | completed | abandoned
- Last completed phase: none

## Execution
- Execution mode: solo | delegated
- Planner tier: <model or agent that plans, reviews, and accepts>
- Executor tier: <model or agent that runs delegated phases | same>
- Full verification: <one command that must pass at Gate D | manual: <what to check>>

## Git
- Repository: yes | no
- Strategy: isolated-branch | current-branch | none
- Starting branch: <branch | "-">
- Work branch: <branch | "-">
- Baseline commit: <full immutable SHA | "-">
- Starting upstream at start: <ref>@<full SHA> | none | "-"
- Work upstream at start: <ref>@<full SHA> | none | "-"

## Phases
- [todo] phase-0001 — <title>

## Handoff
- Current position: planning
- Next role: planner
- Next action: approve the goal
- Last verified evidence: none
- Blockers: none

## Review
- Reviewed by: none
- Verification result: none
- Diff reviewed: none
- Findings: none

## Log
- created ledger with <N> phases
```

`phase-NNNN.md`:

````markdown
# phase-NNNN — <title>

- Status: todo
- Owner: planner | executor
- Depends on: none
- Goal: <one line>
- Done when: <runnable or observable check>
- Pattern to follow: <path:line to imitate | none>

## Context
<2–6 lines an executor cannot derive from the code alone: why this phase exists,
what decision was already made for them, what the surrounding code assumes>

## Scope
- In: <exact paths or globs this phase may change>
- Out: <paths or areas to leave alone | none>

## Sub-tasks
1. [todo] <one concrete action> — done when: <mechanical check>

## Verify
```sh
<commands runnable from the project root; exit 0 means pass>
```

## Escalate when
- <condition> → stop, set Status: needs-human — reason: <what you need>

## Log
- (append-only, one line per event)

## Evidence
- (append-only: command → observed result)
````
