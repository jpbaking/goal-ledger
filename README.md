# lazyway-io-boilerplate

Personal boilerplate kit. It bundles the AI-agent tooling and dev scripts jpbaking
wants in **every** project — a reasoning/process framework for coding agents, a
safe `docker compose` wrapper, and (for frontend apps) a design system — into
one install, for whichever agent harnesses the project uses.

This README is written for **both** audiences that read it: a human setting
up a project by hand, and a coding agent asked to bootstrap or retrofit a
project with this kit.

## Two content sets, three harness targets

The same procedures ship in two tunings, and the installer maps them onto the
harnesses you pick:

| Source set | Tuned for | Installed to |
|---|---|---|
| `sets/small` | small/weak models (< ~32B): reasoning scaffold, mechanical checklists, hand-holding | **Cline** — `.clinerules/` + `.cline/skills/` + `/workflow` shortcuts |
| `sets/frontier` | frontier models (Sonnet+, GPT-5+, Gemini 3+): contracts stated once, judgment trusted | **Claude Code** — `CLAUDE.md` + `.claude/{rules,skills,commands}` — and the shared **`.agents/` + `AGENTS.md` convention** read by Codex CLI, Google Antigravity, and Gemini CLI |
| `sets/shared` | everyone (harness-neutral procedures: DOX skills, compose-helper, design) | wherever the sets above land |

Key file conventions (`AGENTS.md` DOX trees, `.tmp-agent-scratch/` master
plans, the git commit contract) are identical across sets, so **a task started
under one harness resumes under any other**. Each installed harness also gets
an ignore file/setting (`.clineignore`, `.claude/settings.json` deny rules,
`.geminiignore`, an `AGENTS.md` note) so it doesn't read the other harnesses'
config trees — `AGENTS.md` itself is never ignored; it's the shared contract.

## Components

| Component | Required? | What it provides | Upstream |
|---|---|---|---|
| **core rules** | always | structured-reasoning rules (small set) / working disciplines (frontier set) | [jpbaking/cline-rules](https://github.com/jpbaking/cline-rules) (small set base) |
| **compose-helper** | script always; agent rule/skill per harness | `compose-helper.sh`/`.ps1` + `compose-helper.env`, plus a rule + skill teaching agents to use it safely | [jpbaking/compose-helper](https://github.com/jpbaking/compose-helper) |
| **DOX** | optional (default No) | the [DOX](https://github.com/jpbaking/dox) `AGENTS.md` doc framework: rule + 5 `dox-*` skills, with the framework template packaged offline | [jpbaking/dox](https://github.com/jpbaking/dox) |
| **master-plan** | optional (default No) | crash-safe multi-phase task plans: rule + 4 `master-plan*` skills, git commit trail with squash-on-acceptance | this repo |
| **lazyway-io-design** | optional (default No) — webapps with a frontend | design-system rule + skill (the skill fetches the actual `design/` CSS/JS kit on first UI task) | [jpbaking/lazyway-io-design](https://github.com/jpbaking/lazyway-io-design) |

## Install

Run the installer from your project's root. It only adds/updates its own
files — it never touches your application code — and is safe to re-run any
time to pick up updates. It asks which harnesses to support (each defaults to
Yes) and which optional components to include.

**Linux / macOS**

```sh
curl -fsSL https://raw.githubusercontent.com/jpbaking/lazyway-io-boilerplate/main/install.sh | sh
```

**Windows (PowerShell 5.1+ or pwsh)**

```powershell
irm https://raw.githubusercontent.com/jpbaking/lazyway-io-boilerplate/main/install.ps1 | iex
```

For a brand-new project: `mkdir my-new-app && cd my-new-app && git init`, then
run the installer.

What the installer does:

- asks which harnesses to install for — Cline / Claude Code / the `.agents`
  convention (Codex, Antigravity, Gemini) — each defaulting to Yes
- always installs compose-helper's script via its own upstream installer
  (never overwrites an existing `compose-helper.env`; only reports missing keys)
- for Cline: delegates to the upstream cline-rules installer (which asks about
  its DOX and plan-execute sub-components, default No each, and safely merges
  an existing `.clinerules/`), then overlays this repo's harmonized/updated
  files on top — including replacing legacy plan-execute with the master-plan
  family — and writes `.clineignore`
- for Claude Code / `.agents`: installs the frontier set; DOX and master-plan
  mirror the Cline choices when Cline was installed, otherwise the installer
  asks directly; writes `CLAUDE.md` imports and `.claude/settings.json`
  idempotently, appends an `AGENTS.md` pointer section, writes `.geminiignore`
- components you decline stay absent from every harness

Options (environment variables):

| Variable | Effect |
|---|---|
| `WITH_CLINE=1/0`, `WITH_CLAUDE=1/0`, `WITH_AGENTS=1/0` | Select harnesses without being asked |
| `WITH_DESIGN=1/0` | Include/skip the design component without being asked |
| `ASSUME_YES=1` | Answer Yes to every prompt this installer owns (delegated installers keep their own defaults) |
| `LAZYWAY_BOILERPLATE_REF=<ref>` | Fetch this repo's files from a ref other than `main` |
| target dir as `sh -s -- /path`, or `$env:BOILERPLATE_TARGET` on Windows | Install into a directory other than the current one |

### Manual install

No script, full control — copy what you want from `sets/` by hand:
`sets/small/*` → Cline paths, `sets/frontier/*` + `sets/shared/*` → Claude
Code or `.agents` paths. Every file is plain Markdown, shell, or PowerShell;
nothing requires a package manager or build step.

## For AI agents

If you're an agent asked to "set this project up with the boilerplate" (or
similar):

1. Check whether the target harness's files already exist (`.clinerules/`,
   `CLAUDE.md` + `.claude/`, or `AGENTS.md` + `.agents/`). If they do, you're
   done unless asked to update — re-running the installer is always safe.
2. Otherwise run the installer for the platform you're on (§ above), passing
   `WITH_*` env vars if the user already told you which harnesses they want.
   Prefer the installer over hand-copying: it contains conflict-handling and
   idempotent-merge logic not worth approximating from memory.
3. Ask the user only what the installer can't decide: which harnesses, and
   whether this is a frontend project that wants `lazyway-io-design`.
4. Once installed, the rules files (`.clinerules/`, `.claude/rules/`, or
   `.agents/rules/`) are the authoritative always-on instructions — read them
   directly rather than re-deriving their content from this README.
5. Never retype installed files from memory if they look stale — re-run the
   installer (or re-fetch the specific file from `sets/` in this repo).

## Repo layout

```
lazyway-io-boilerplate/
├── README.md            ← this file — describes the boilerplate, not your app
├── LICENSE              ← this boilerplate's own license (0BSD)
├── install.sh           ← installer (Linux/macOS)
├── install.ps1          ← installer (Windows)
├── compose-helper.sh    ← docker compose wrapper (see compose-helper repo)
├── compose-helper.env   ← compose-helper's own config
└── sets/                ← the content the installer maps onto harnesses
    ├── shared/          ← harness-neutral: dox-* skills (+ packaged AGENTS.md
    │                      template), compose-helper + design rules/skills
    ├── small/           ← weak-model set for Cline: rules, master-plan
    │                      skills, /workflow shortcuts
    └── frontier/        ← frontier-model set for Claude Code + .agents:
                           rules, master-plan skills, /command shortcuts
```

## Updating

Re-run the installer in the project root with the same harness selection —
every file it touches is freshly re-downloaded; `compose-helper.env`,
`CLAUDE.md`, `AGENTS.md`, ignore files, and `.claude/settings.json` are
merged/appended idempotently rather than overwritten.

## License

This repo's own [LICENSE](LICENSE) is [0BSD](https://opensource.org/licenses/0BSD),
matching the upstream kits it bundles (cline-rules, compose-helper — check
[lazyway-io-design](https://github.com/jpbaking/lazyway-io-design) for its own
terms). Do whatever you want with the boilerplate glue itself, no attribution
required.

It only covers this repo's own files — the installer never writes this
`README.md` or `LICENSE` into your project.
