# lazyway-io-boilerplate

Personal boilerplate kit. It bundles the AI-agent tooling and dev scripts jpbaking
wants in **every** project — a Cline reasoning/process framework, a safe
`docker compose` wrapper, and (for frontend apps) a design system — into one
install. Each piece is an independent, standalone project; this repo just
combines them with one installer.

This README is written for **both** audiences that read it: a human setting
up a project by hand, and a coding agent (Cline or otherwise) asked to
bootstrap or retrofit a project with this kit.

## What's inside

| Component | Required? | What it drops in your project | Upstream |
|---|---|---|---|
| **cline-rules** | Always | `.clinerules/00-core-reasoning-rules.md`, `01-dox-framework.md`, `02-plan-execute-resume.md` — structured reasoning, the [DOX](https://github.com/jpbaking/dox) `AGENTS.md` doc framework, and crash-safe multi-phase task plans | [jpbaking/cline-rules](https://github.com/jpbaking/cline-rules) |
| **compose-helper** | Always | `compose-helper.sh` (+ `.ps1` on Windows) and `compose-helper.env`, plus `.clinerules/compose-helper.md` and `.cline/skills/compose-helper/` teaching agents to use it safely | [jpbaking/compose-helper](https://github.com/jpbaking/compose-helper) |
| **lazyway-io-design** | Optional — webapps with a frontend | `.clinerules/lazyway-io-design.md` and `.cline/skills/lazyway-io-design/` (rule + skill only; the skill fetches the actual `design/` CSS/JS kit into the project on first UI task) | [jpbaking/lazyway-io-design](https://github.com/jpbaking/lazyway-io-design) |

None of this is reimplemented here — the installer fetches the current version of
each piece straight from its own repo, so this boilerplate never drifts out of
sync with upstream fixes.

## Quick start

### Starting a brand-new project

Use this repo directly as the starting point — the files are already in place,
nothing to install:

```sh
git clone https://github.com/jpbaking/lazyway-io-boilerplate.git my-new-app
cd my-new-app
# README, LICENSE, and the installer scripts describe/license *this
# boilerplate* — drop them and write your own before you start.
rm -rf .git install.sh install.ps1 LICENSE README.md && git init
```

(Or mark this repo as a GitHub **template repository** and click **Use this
template** instead of cloning.) Then add your own `docker-compose.yaml` next to
`compose-helper.sh`, and if it's a frontend project, keep `lazyway-io-design`;
otherwise delete `.clinerules/lazyway-io-design.md` and
`.cline/skills/lazyway-io-design/`.

### Adding it to an existing project

Run the installer from your project's root. It only adds/updates the files
above — it never touches your application code — and it's safe to re-run any
time to pick up updates.

**Linux / macOS**

```sh
curl -fsSL https://raw.githubusercontent.com/jpbaking/lazyway-io-boilerplate/main/install.sh | sh
```

**Windows (PowerShell 5.1+ or pwsh)**

```powershell
irm https://raw.githubusercontent.com/jpbaking/lazyway-io-boilerplate/main/install.ps1 | iex
```

The installer:

- always installs cline-rules and compose-helper (no prompt — these are the
  "always" row above), and asks once whether to also install the optional
  design-system rule + skill (default **No**)
- never overwrites an existing `compose-helper.env` (only reports which keys
  the latest example has that yours doesn't)
- delegates the `.clinerules/` merge itself to cline-rules' own installer,
  which safely handles an existing `.clinerules` (renumbers conflicting rule
  files, converts a single-file `.clinerules` to a folder, etc. — see
  [its README](https://github.com/jpbaking/cline-rules#readme) for the exact
  behavior)

Options (environment variables):

| Variable | Effect |
|---|---|
| `ASSUME_YES=1` | Accept all prompts non-interactively (CI-safe) |
| `WITH_DESIGN=1` / `WITH_DESIGN=0` | Install / skip the design kit without being asked |
| target dir as `sh -s -- /path`, or `$env:BOILERPLATE_TARGET` on Windows | Install into a directory other than the current one |

```sh
# non-interactive, including the design kit
curl -fsSL https://raw.githubusercontent.com/jpbaking/lazyway-io-boilerplate/main/install.sh | ASSUME_YES=1 WITH_DESIGN=1 sh
```

### Manual install

No script, full control — copy whichever rows you want from the table above,
by hand, from each upstream repo (or from this repo's own copies, which mirror
them). Nothing here requires a package manager or build step; every file is
plain Markdown, shell, or PowerShell.

## For AI agents

If you're an agent asked to "set this project up with the boilerplate" (or
similar), a new project, or an existing one:

1. Check whether the files in the table above already exist. If they do,
   you're done unless the user asked to update — re-running the installer is
   always safe.
2. Otherwise, run the installer for the platform you're on (§ above). Prefer
   the installer over hand-copying: it contains conflict-handling logic (rule
   renumbering, single-file → folder conversion) that is not worth
   reimplementing or approximating from memory.
3. Ask the user only about things the installer asks about non-mechanically —
   principally whether this is a frontend project that wants
   `lazyway-io-design`. Everything else the installer handles deterministically.
4. Once installed, the `.clinerules/` files are the authoritative, always-loaded
   instructions — don't re-derive their content from this README; read them
   directly if you need their exact rules. In short: `00-core-reasoning-rules.md`
   governs how you reason and verify your own work, `01-dox-framework.md`
   governs `AGENTS.md` docs, `02-plan-execute-resume.md` governs multi-phase
   task plans, `compose-helper.md` governs any `docker compose` operation, and
   `lazyway-io-design.md` (if installed) governs any UI/styling work.
5. Never invent or retype the content of any installed file from memory if it
   looks stale or wrong — re-run the installer (or re-download the specific
   file from its upstream repo) instead of guessing.

## Repo layout

```
lazyway-io-boilerplate/
├── README.md            ← this file — describes the boilerplate, not your app, see below
├── LICENSE              ← this boilerplate's own license (0BSD) — not for your app, see below
├── install.sh           ← installer (Linux/macOS)
├── install.ps1          ← installer (Windows)
├── compose-helper.sh    ← docker compose wrapper (see compose-helper repo)
├── compose-helper.env   ← compose-helper's own config
├── .clinerules/         ← always-loaded Cline rules (see table above)
└── .cline/skills/       ← on-demand Cline skills (compose-helper, lazyway-io-design)
```

## Updating

Re-run the installer for your platform in the project root — every file it
touches is either freshly re-downloaded or, for `compose-helper.env`, left
alone if it already exists.

## License

This repo's own [LICENSE](LICENSE) is [0BSD](https://opensource.org/licenses/0BSD),
matching the upstream kits it bundles (cline-rules, compose-helper — check
[lazyway-io-design](https://github.com/jpbaking/lazyway-io-design) for its own
terms). Do whatever you want with the boilerplate glue itself, no attribution
required.

It only covers this repo's own files (this `README.md`, the installer scripts,
and `LICENSE` itself) — none of them are installed into other projects. The
installer never fetches or writes a `README.md` or `LICENSE`, and the
new-project clone guide above deletes all three along with the installer
scripts so you can write your own.
