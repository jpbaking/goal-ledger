# HANDOFF — review findings and planned fixes

Review of the Goal Ledger kit at commit `09f1155`, 2026-07-19. Method: full manual
read of both installers, all four skills, the validator, tests, and CI; local test
run (`python3 -m unittest discover -s tests -v` — 14 tests, all pass, PowerShell
test skipped because pwsh is not installed locally); scripted reproduction of the
append-newline behavior; a parallel independent review by a second agent (agy),
whose claims were re-verified before inclusion; and documentation checks for
Claude Code `.claude/rules` discovery and PowerShell path-separator semantics.

Nothing below has been fixed yet. Items are ordered by severity within each
section. "Confirmed" means reproduced or directly demonstrated; "high confidence"
means derived from documented platform behavior but not yet exercised.

## 1. Confirmed bugs

### 1.1 `ensure_gemini_pointer` corrupts GEMINI.md without a trailing newline — and re-appends forever

`install.sh:218-223`. When an existing `GEMINI.md` does not end with a newline,
`printf '%s\n' '@.agents/rules/goal-ledger.md' >> "$file"` glues the import onto
the last line. Reproduced:

```
Some line without trailing newline@.agents/rules/goal-ledger.md
```

Three consequences: the user's last line is corrupted, the `@` import is not at
line start so Gemini will not resolve it, and because the idempotency check is an
exact-line match (`grep -qxF`), every subsequent run appends the line again.

**Fix:** before appending, add a newline when the file is non-empty and does not
end with one (mirror the logic `install.ps1` already has in `Ensure-Line`,
`install.ps1:80-84`). Add an installer test fixture with a no-trailing-newline
`GEMINI.md` covering both corruption and idempotency.

Note: the analogous `ensure_agents_pointer` (`install.sh:205-216`) is *not*
corrupted in this case — the heredoc's leading blank line terminates the dangling
line — but the blank separator line is silently consumed. The same fix applies
for tidiness.

### 1.2 Validator crashes when `git` is not installed

`skills/goal-ledger/scripts/validate_goal_ledger.py:320-327`. With
`Repository: yes` and no `git` on PATH, `subprocess.run(["git", ...])` raises an
unhandled `FileNotFoundError` and the validator dies with a traceback instead of
a diagnostic. The skills promise deterministic validation whenever Python 3 is
available; git availability is a separate question.

**Fix:** wrap the `git()` helper in `try/except OSError` and convert to a single
error such as "git is unavailable; run with --no-git or install git", then skip
the remaining live-Git checks. Add a validator test (e.g. patch `subprocess.run`
or run with a stripped PATH).

### 1.3 `Last completed phase` check breaks under out-of-order phase completion

`validate_goal_ledger.py:263-274`. The check requires `Last completed phase` to
equal the *highest-numbered* done phase (`done_phases[-1]` on a sorted list). But
dependencies may point forward: with `phase-0002` depending on `phase-0003`, the
execution loop legitimately completes 0003 first, then 0002 — at which point the
truthful `Last completed phase: phase-0002` is reported as an error.

**Fix:** decide the semantics and align spec + validator. Simplest: define
`Last completed phase` as "most recently completed phase" and have the validator
accept any phase whose status is done (it already checks existence and done-ness
at lines 275-279; delete the `done_phases[-1]` comparison). Add a test with a
forward dependency.

## 2. High-confidence bugs (verify while fixing)

### 2.1 `install.ps1` hardcoded backslash paths break on PowerShell 7 for Linux/macOS

Throughout `install.ps1`: `Join-Path $SourceRoot 'rules\goal-ledger.md'` (line
139), `"skills\$Skill\SKILL.md"` (144), `'.tmp-agent-scratch\MASTER-PLAN.md'`
(201), the whole `Inspect-SameNamedArtifacts` list (213-223), etc. PowerShell
*provider* cmdlets (`Test-Path`, `Copy-Item`) are forgiving about separators, but
the script also feeds these paths to raw .NET APIs
(`[System.IO.File]::ReadAllText` at line 146, `ReadAllBytes` in
`Get-TextDocument`), which treat `\` as a literal filename character on Unix. At
best `Validate-Source` throws on Linux; at worst safety checks like
`Test-LegacyActivePlan` silently pass over an existing legacy plan.

This matters because GitHub's `ubuntu-latest`/`macos-latest` runners ship pwsh,
so `PowerShellInstallerTests` runs in the `unix` CI job — this likely makes that
job red today (could not verify locally: no pwsh installed here).

**Fix:** use forward slashes in every path literal in `install.ps1` (both
Windows PowerShell 5.1 and pwsh accept `/` in provider and .NET APIs on all
platforms). Verify by running the PS test under pwsh on Linux (CI or local
install).

### 2.2 PowerShell installer may not signal failure to callers

`install.ps1:356-358`. The `catch { Write-Error ... }` at the top level relies on
`$ErrorActionPreference = 'Stop'` re-throwing to produce a non-zero exit. That is
incidental, version-sensitive behavior; under some hosts (`irm | iex` in a
console with a different EAP, or future refactors that move the catch) the script
can print the error and exit 0, so scripted callers and CI think the install
succeeded.

**Fix:** make failure explicit — set a failure flag in `catch`, and after
`finally`, `exit 1` (guarded so `irm | iex` in an interactive console doesn't
close the session: prefer `throw` after cleanup, or `if ($Host.Name -eq
'ConsoleHost' -and $MyInvocation...)`-style handling; decide during
implementation). Add a PS test asserting non-zero exit for an invalid source,
mirroring the existing sh test `test_invalid_source_does_not_modify_target`.

## 3. Robustness fixes

### 3.1 Interrupted installs leave `.goal-ledger-install.*` / `.goal-ledger-backup.*` litter in the target

`install.sh:101-133`, `install.ps1:152-188`. The staged-swap design is good, but
if the process dies between `cp` and the final `mv` (or a copy fails), the
`*.goal-ledger-install.$$` / backup paths remain in `.agents/`/`.claude/`. The
`trap`/`finally` only cleans `$STAGING_ROOT`. Related edge: `install_tree` checks
that the *incoming* path is free but not the *backup* path; a pre-existing
same-named backup directory makes `mv "$dest" "$backup"` nest the destination
inside it, and the recovery path then restores the wrong tree.

**Fix:** track every incoming/backup path created and remove leftover incoming
paths in the cleanup trap/finally (backups from a crashed run should be reported,
not deleted); check the backup path for pre-existence exactly like the incoming
path. Same for both installers.

### 3.2 Signal handling in `install.sh` can exit 0 after an interrupt

`install.sh:19` — `trap cleanup 0 HUP INT TERM` runs cleanup on a signal but
does not re-raise or force a failure status, so an interrupted install can end
looking successful to a wrapper script.

**Fix:** `trap 'cleanup' EXIT` plus a separate signal trap that cleans up and
exits non-zero (e.g. `trap 'cleanup; trap - EXIT; exit 130' INT` and analogous
for HUP/TERM).

### 3.3 PowerShell 5.1 downloads can fail on TLS 1.0-default systems

`install.ps1:130`. On older Windows / .NET < 4.7 configurations,
`Invoke-WebRequest` to GitHub fails with a TLS handshake error. Standard
`irm | iex` installer practice applies.

**Fix:** before the request, opt in without clobbering existing protocols:
`[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12`.

### 3.4 Unauthenticated `api.github.com` zipball is rate-limited to 60 requests/hour/IP

`install.sh:79`, `install.ps1:124`. CI farms or shared NAT egress will hit 403s.

**Fix (refinement):** default to
`https://codeload.github.com/<repo>/zip/refs/heads/<ref>` (not API-rate-limited)
or try codeload with API fallback; keep `GOAL_LEDGER_ARCHIVE_URL` as the
escape hatch. Needs a small design note because a bare `<ref>` maps to different
codeload URLs for branches vs tags vs SHAs — the API zipball's ref-agnosticism is
why it was presumably chosen. If codeload's ref ambiguity is deemed not worth it,
at least document the rate limit in the README.

## 4. Cross-installer consistency

- **New-file AGENTS.md shape differs:** bash `ensure_agents_pointer` creates a
  new `AGENTS.md` that begins with a blank line and has no top-level heading
  (`install.sh:208`); the PS version writes `# Project rules` first
  (`install.ps1:101-105`). Align on the PS behavior in bash.
- **Prompt retry behavior differs:** bash `ask` re-prompts on unrecognized input
  (`install.sh:33-41`); PS `Ask` silently takes the default
  (`install.ps1:27-29`). Align on re-prompting.
- **`decide` error attribution for Gemini inheritance:** when `WITH_GEMINI` is
  unset and `WITH_AGENTS` holds garbage, the error message blames `WITH_GEMINI`
  (`install.sh:260-261`, `install.ps1:318-319`). Cosmetic; report the variable
  the value actually came from.
- **Ref encoding:** `install.sh:78` percent-encodes only `/` in
  `GOAL_LEDGER_REF`; PS uses full `EscapeDataString`. Low impact for git refs,
  but align (a tiny `sed`-based escape of `%` then `/`, or document the
  limitation).

## 5. Validator refinements

- **Section-aware field parsing:** `field_map` (`validate_goal_ledger.py:57-61`)
  scans the whole document, so a free-form Log entry like `- Next action: retry
  tests` silently overwrites the Handoff `Next action` field (last match wins).
  Parse fields within their `##` section instead.
- **Reason suffix accepted on any status:** `PHASE_STATUS_RE` (line 14) permits
  `done — reason: x` although the vocabulary defines reasons only for `skipped`
  and `needs-human`. Reject reason suffixes on other statuses.
- **Ongoing sub-task in a non-ongoing phase is not flagged:** the contract's
  execution loop implies active sub-tasks only exist in the ongoing phase; add a
  warning when a `[ongoing]` sub-task sits in a `todo`/`done`/`skipped` phase.
- **Sub-task placeholder check** (line 207) recognizes `<check>` but not
  `<runnable or observable check>`; harmless today (the sub-task template uses
  `<check>`), cheap to include both. *(agy finding.)*
- **Upstream field format unvalidated:** when a strategy is prepared, `Starting/
  Work upstream at start` accept any text; validate `<ref>@<full SHA> | none`.
- **Drop `from __future__ import print_function`** (line 4): the script already
  requires Python 3.7+ (`subprocess.run(text=True)`, pathlib).
- Won't fix: `\x1f`/`\x1e` delimiter collision with pathological commit messages
  (agy nitpick) — theoretical, and any fix costs more than it buys.

## 6. Test and CI additions

- Installer: append to `GEMINI.md`/`AGENTS.md` lacking a trailing newline
  (bug 1.1) including second-run idempotency.
- Installer: PS failure exit code for an invalid source (bug 2.2).
- Installer: interrupted-install litter is cleaned / backup-path collision
  (3.1) — at minimum the backup-pre-existence check.
- Validator: git binary missing (1.2); forward-dependency completion order
  (1.3); commit-trailer checks (`Goal-ID`/`Goal-Phase` classification at lines
  405-428 currently have zero coverage — needs a small fixture repo built in a
  temp dir); Log-line field shadowing (5).
- CI: after fixing 2.1, the existing matrix already exercises pwsh on
  Linux/macOS via `PowerShellInstallerTests`; make that explicit in the job name
  or README so a future skip regression is noticed. Consider `shellcheck
  install.sh` alongside `sh -n`.

## 7. Documentation notes

- `.claude/rules/` auto-discovery: **confirmed real** against current Claude
  Code docs (rules files load at session start, same priority as CLAUDE.md), so
  the kit's Claude path and the `Warn-RedundantClaudeImport` logic are sound. No
  change needed.
- README's claim that current Cline reads `AGENTS.md` and the shared
  `.agents/skills` location (README lines 60-68) was verified on 2026-07-19
  against current harness documentation (see the multi-harness support research
  playbook); the README now records the verification date. All four skill
  descriptions are under Cline's documented 1,024-character limit.
- README "CI runs … on Linux, macOS, Windows PowerShell 5.1, and PowerShell 7"
  is accurate in intent but currently undermined by 2.1 on the unix side.

## 8. Second-opinion review notes

An independent agy review (report:
`scratchpad/agy-review.md` in the session scratch area) contributed 1.2, part of
3.1, and the sub-task placeholder nit. Two of its claims were corrected on
verification: the `AGENTS.md` no-trailing-newline append does *not* corrupt
content in `install.sh` (the heredoc's leading blank line absorbs it — only
`GEMINI.md` is affected), and its "redundant string formatting" item was a
non-finding. Its remaining items matched findings above.

## Suggested fix order

1. Bugs 1.1, 1.2, 1.3 with their tests (small, independent).
2. Bug 2.1 (mechanical separator sweep) + 2.2, then confirm the full matrix is
   green — this unblocks trust in CI for everything else.
3. Robustness items 3.1-3.3; consistency items in section 4.
4. Validator refinements (5) with tests, then remaining test/CI additions (6).
5. Documentation follow-ups (7), including the Cline verification.
