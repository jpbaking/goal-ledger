#!/bin/sh
# install.sh — installer/updater for jpbaking's boilerplate kit
# https://github.com/jpbaking/lazyway-io-boilerplate
#
# Two content sets, mapped onto the agent harnesses you choose:
#   - sets/small    — tuned for small/weak models  -> Cline
#   - sets/frontier — tuned for frontier models    -> Claude Code, and the
#                     shared .agents/ + AGENTS.md convention (Codex CLI,
#                     Google Antigravity, Gemini CLI)
#   - sets/shared   — harness-neutral procedures used by both
#
# Harness selection (each defaults to YES; asked unless set):
#   WITH_CLINE=1|0    Cline        -> .clinerules/ + .cline/  (delegates to
#                                     upstream cline-rules installer first)
#   WITH_CLAUDE=1|0   Claude Code  -> CLAUDE.md + .claude/
#   WITH_AGENTS=1|0   Codex/Antigravity/Gemini -> AGENTS.md pointer + .agents/
#
# Component selection:
#   WITH_DESIGN=1|0   lazyway-io-design rule+skill (default: ask, No)
#   DOX and master-plan: when Cline is installed, upstream cline-rules asks
#   and the answer is mirrored to the other harnesses; without Cline, this
#   installer asks directly (default No each).
#
# Each installed harness also gets an ignore file / setting so it does not
# read the other harnesses' config trees (AGENTS.md itself is never ignored —
# it is the shared DOX contract).
#
# Usage (from your project root):
#   curl -fsSL https://raw.githubusercontent.com/jpbaking/lazyway-io-boilerplate/main/install.sh | sh
# Non-interactive:  ... | ASSUME_YES=1 sh     (design still defaults No unless WITH_DESIGN=1)
# Other directory:  ... | sh -s -- /path/to/project
#
# This repo's own README.md and LICENSE (and this installer itself) are never
# written into the target project — they cover this repo, not yours.

set -eu

BOILERPLATE_REPO="jpbaking/lazyway-io-boilerplate"
BOILERPLATE_REF="${LAZYWAY_BOILERPLATE_REF:-main}"

CLINE_RULES_INSTALL_URL="https://raw.githubusercontent.com/jpbaking/cline-rules/main/install.sh"
COMPOSE_HELPER_INSTALL_URL="https://raw.githubusercontent.com/jpbaking/compose-helper/main/.install-helper/install.sh"
DESIGN_BASE="https://raw.githubusercontent.com/jpbaking/lazyway-io-design/main"
SETS="https://raw.githubusercontent.com/jpbaking/lazyway-io-boilerplate/$BOILERPLATE_REF/sets"

TARGET_ROOT="${1:-.}"

say()  { printf '%s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -q -O "$2" "$1"; }
else
  die "Neither curl nor wget found."
fi

# Yes/no prompts that work under `curl | sh` (stdin is the pipe) — read the
# controlling terminal directly. $2 is the no-terminal/ASSUME_YES default.
ask() {
  q="$1"; def="${2:-n}"
  if [ "${ASSUME_YES:-0}" = "1" ]; then
    say "$q [auto-yes via ASSUME_YES=1]"; return 0
  fi
  if ! ( : < /dev/tty > /dev/tty ) 2>/dev/null; then
    say "$q [no terminal — defaulting to $def]"
    [ "$def" = "y" ] && return 0 || return 1
  fi
  if [ "$def" = "y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
  while :; do
    printf '%s %s ' "$q" "$hint" > /dev/tty
    IFS= read -r ans < /dev/tty || ans=""
    case "$ans" in
      y|Y|yes|YES) return 0 ;;
      n|N|no|NO) return 1 ;;
      "") [ "$def" = "y" ] && return 0 || return 1 ;;
    esac
  done
}

# env override (1/0) or ask; $3 is the ask default
decide() {
  case "$1" in
    1) return 0 ;;
    0) return 1 ;;
    *) ask "$2" "$3" ;;
  esac
}

[ -d "$TARGET_ROOT" ] || die "Target directory '$TARGET_ROOT' does not exist."

say "jpbaking's boilerplate kit — installer"
say "source: github.com/$BOILERPLATE_REPO@$BOILERPLATE_REF"
say "target: $TARGET_ROOT"
say ""

# --- Selection ----------------------------------------------------------------
say "==> Which agent harnesses should this project support?"
cline_on=1;  decide "${WITH_CLINE:-}"  "    Cline (.clinerules/ + .cline/, small-model set)?" y || cline_on=0
claude_on=1; decide "${WITH_CLAUDE:-}" "    Claude Code (CLAUDE.md + .claude/, frontier set)?" y || claude_on=0
agents_on=1; decide "${WITH_AGENTS:-}" "    Codex / Antigravity / Gemini (AGENTS.md + .agents/, frontier set)?" y || agents_on=0
if [ "$cline_on$claude_on$agents_on" = "000" ]; then die "Nothing selected — nothing to do."; fi

design_on=0
if decide "${WITH_DESIGN:-}" "    Include the lazyway-io-design component (webapps with a frontend)?" n; then design_on=1; fi
say ""

# --- compose-helper (always — the script serves every harness) -----------------
say "==> compose-helper — delegating to its own installer"
if ! ( cd "$TARGET_ROOT" && curl -fsSL "$COMPOSE_HELPER_INSTALL_URL" 2>/dev/null | bash ); then
  die "compose-helper install failed. See https://github.com/jpbaking/compose-helper"
fi
say ""

# --- Cline (small-model set) ---------------------------------------------------
if [ "$cline_on" = "1" ]; then
  say "==> Cline — delegating to cline-rules, then overlaying the small-model set"
  if ! curl -fsSL "$CLINE_RULES_INSTALL_URL" 2>/dev/null | sh -s -- "$TARGET_ROOT"; then
    die "cline-rules install failed. See https://github.com/jpbaking/cline-rules"
  fi

  # harmonized core rules (always present after the delegate)
  fetch "$SETS/small/rules/00-core-reasoning-rules.md" \
    "$TARGET_ROOT/.clinerules/00-core-reasoning-rules.md"

  # DOX component (chosen inside the delegate): harmonized rule + neutralized
  # dox-init (with packaged AGENTS.md template) and dox-upgrade
  if [ -f "$TARGET_ROOT/.clinerules/dox.md" ]; then
    fetch "$SETS/shared/rules/dox.md" "$TARGET_ROOT/.clinerules/dox.md"
    mkdir -p "$TARGET_ROOT/.cline/skills/dox-init/templates"
    fetch "$SETS/shared/skills/dox-init/SKILL.md" "$TARGET_ROOT/.cline/skills/dox-init/SKILL.md"
    fetch "$SETS/shared/skills/dox-init/templates/AGENTS.md" \
      "$TARGET_ROOT/.cline/skills/dox-init/templates/AGENTS.md"
    if [ -f "$TARGET_ROOT/.cline/skills/dox-upgrade/SKILL.md" ]; then
      fetch "$SETS/shared/skills/dox-upgrade/SKILL.md" "$TARGET_ROOT/.cline/skills/dox-upgrade/SKILL.md"
    fi
  fi

  # master-plan family replaces upstream's legacy plan-execute
  if [ -f "$TARGET_ROOT/.clinerules/plan-execute.md" ] || \
     [ -f "$TARGET_ROOT/.clinerules/master-plan.md" ]; then
    rm -f "$TARGET_ROOT/.clinerules/plan-execute.md" \
          "$TARGET_ROOT/.clinerules/workflows/plan-execute.md"
    rm -rf "$TARGET_ROOT/.cline/skills/plan-execute"
    fetch "$SETS/small/rules/master-plan.md" "$TARGET_ROOT/.clinerules/master-plan.md"
    for s in master-plan master-plan-resume master-plan-status master-plan-clear; do
      mkdir -p "$TARGET_ROOT/.cline/skills/$s"
      fetch "$SETS/small/skills/$s/SKILL.md" "$TARGET_ROOT/.cline/skills/$s/SKILL.md"
    done
  fi

  # design component
  if [ "$design_on" = "1" ]; then
    mkdir -p "$TARGET_ROOT/.cline/skills/lazyway-io-design/templates"
    fetch "$DESIGN_BASE/cline/clinerules/lazyway-io-design.md" "$TARGET_ROOT/.clinerules/lazyway-io-design.md"
    fetch "$DESIGN_BASE/cline/skills/lazyway-io-design/SKILL.md" "$TARGET_ROOT/.cline/skills/lazyway-io-design/SKILL.md"
    fetch "$DESIGN_BASE/cline/skills/lazyway-io-design/templates/app.html" "$TARGET_ROOT/.cline/skills/lazyway-io-design/templates/app.html"
    fetch "$DESIGN_BASE/cline/skills/lazyway-io-design/templates/page.html" "$TARGET_ROOT/.cline/skills/lazyway-io-design/templates/page.html"
  fi

  # workflows — one /shortcut per installed skill
  for wf in compose-helper dox-audit dox-child dox-fix dox-init dox-upgrade \
            lazyway-io-design master-plan master-plan-resume master-plan-status \
            master-plan-clear; do
    if [ -f "$TARGET_ROOT/.cline/skills/$wf/SKILL.md" ]; then
      mkdir -p "$TARGET_ROOT/.clinerules/workflows"
      fetch "$SETS/small/workflows/$wf.md" "$TARGET_ROOT/.clinerules/workflows/$wf.md"
    fi
  done

  # ignore the other harnesses' trees (never AGENTS.md — that is shared DOX)
  for line in ".claude/" "CLAUDE.md" ".agents/" ".geminiignore"; do
    grep -qxF "$line" "$TARGET_ROOT/.clineignore" 2>/dev/null || \
      printf '%s\n' "$line" >> "$TARGET_ROOT/.clineignore"
  done
  say "    Cline installed (.clinerules/ .cline/ .clineignore)"
  say ""
fi

# --- Component flags for the frontier harnesses --------------------------------
if [ "$cline_on" = "1" ]; then
  dox_on=0; [ -f "$TARGET_ROOT/.clinerules/dox.md" ] && dox_on=1
  mp_on=0;  [ -f "$TARGET_ROOT/.clinerules/master-plan.md" ] && mp_on=1
elif [ "$claude_on" = "1" ] || [ "$agents_on" = "1" ]; then
  dox_on=0; if ask "==> Include the DOX component (AGENTS.md doc framework)?" n; then dox_on=1; fi
  mp_on=0;  if ask "==> Include the master-plan component (persistent task plans)?" n; then mp_on=1; fi
  say ""
fi

# One shared routine: install the frontier set under a root dir ($1),
# with commands/workflows under $2.
install_frontier_tree() {
  froot="$1"; fcmds="$2"
  mkdir -p "$TARGET_ROOT/$froot/rules" "$TARGET_ROOT/$fcmds" "$TARGET_ROOT/$froot/skills"
  fetch "$SETS/frontier/rules/core.md" "$TARGET_ROOT/$froot/rules/core.md"
  fetch "$SETS/shared/rules/compose-helper.md" "$TARGET_ROOT/$froot/rules/compose-helper.md"
  if [ "$dox_on" = "1" ]; then fetch "$SETS/shared/rules/dox.md" "$TARGET_ROOT/$froot/rules/dox.md"; fi
  if [ "$mp_on" = "1" ]; then fetch "$SETS/frontier/rules/master-plan.md" "$TARGET_ROOT/$froot/rules/master-plan.md"; fi
  if [ "$design_on" = "1" ]; then fetch "$SETS/shared/rules/lazyway-io-design.md" "$TARGET_ROOT/$froot/rules/lazyway-io-design.md"; fi

  skills="compose-helper"
  if [ "$dox_on" = "1" ]; then skills="$skills dox-audit dox-child dox-fix dox-init dox-upgrade"; fi
  if [ "$design_on" = "1" ]; then skills="$skills lazyway-io-design"; fi
  for s in $skills; do
    mkdir -p "$TARGET_ROOT/$froot/skills/$s"
    fetch "$SETS/shared/skills/$s/SKILL.md" "$TARGET_ROOT/$froot/skills/$s/SKILL.md"
    fetch "$SETS/frontier/commands/$s.md" "$TARGET_ROOT/$fcmds/$s.md"
  done
  if [ "$mp_on" = "1" ]; then
    for s in master-plan master-plan-resume master-plan-status master-plan-clear; do
      mkdir -p "$TARGET_ROOT/$froot/skills/$s"
      fetch "$SETS/frontier/skills/$s/SKILL.md" "$TARGET_ROOT/$froot/skills/$s/SKILL.md"
      fetch "$SETS/frontier/commands/$s.md" "$TARGET_ROOT/$fcmds/$s.md"
    done
  fi
  if [ "$dox_on" = "1" ]; then
    mkdir -p "$TARGET_ROOT/$froot/skills/dox-init/templates"
    fetch "$SETS/shared/skills/dox-init/templates/AGENTS.md" \
      "$TARGET_ROOT/$froot/skills/dox-init/templates/AGENTS.md"
  fi
  if [ "$design_on" = "1" ]; then
    mkdir -p "$TARGET_ROOT/$froot/skills/lazyway-io-design/templates"
    fetch "$SETS/shared/skills/lazyway-io-design/templates/app.html" \
      "$TARGET_ROOT/$froot/skills/lazyway-io-design/templates/app.html"
    fetch "$SETS/shared/skills/lazyway-io-design/templates/page.html" \
      "$TARGET_ROOT/$froot/skills/lazyway-io-design/templates/page.html"
  fi
}

# --- Claude Code (frontier set) -------------------------------------------------
if [ "$claude_on" = "1" ]; then
  say "==> Claude Code — CLAUDE.md + .claude/{rules,skills,commands}"
  install_frontier_tree ".claude" ".claude/commands"

  CLAUDE_MD="$TARGET_ROOT/CLAUDE.md"
  test -f "$CLAUDE_MD" || printf '%s\n\n%s\n\n' '# Project rules' \
    'Always-on rules, one file per installed component:' > "$CLAUDE_MD"
  for r in core compose-helper dox master-plan lazyway-io-design; do
    if [ -f "$TARGET_ROOT/.claude/rules/$r.md" ]; then
      grep -qF "@.claude/rules/$r.md" "$CLAUDE_MD" || \
        printf '%s\n' "@.claude/rules/$r.md" >> "$CLAUDE_MD"
    fi
  done

  # ignore other harnesses' trees via permission deny (create only if absent —
  # never clobber an existing settings.json)
  CC_SETTINGS="$TARGET_ROOT/.claude/settings.json"
  if [ ! -f "$CC_SETTINGS" ]; then
    cat > "$CC_SETTINGS" <<'EOF'
{
  "permissions": {
    "deny": [
      "Read(./.cline/**)",
      "Read(./.clinerules/**)",
      "Read(./.agents/**)"
    ]
  }
}
EOF
  else
    say "    NOTE: .claude/settings.json exists — add Read() deny rules for .cline/, .clinerules/, .agents/ yourself if wanted"
  fi
  say "    Claude Code installed"
  say ""
fi

# --- .agents convention: Codex CLI / Antigravity / Gemini CLI -------------------
if [ "$agents_on" = "1" ]; then
  say "==> Codex/Antigravity/Gemini — AGENTS.md pointer + .agents/{rules,skills,workflows}"
  install_frontier_tree ".agents" ".agents/workflows"

  # AGENTS.md pointer section (append-once; the file itself may be/become a DOX root)
  AGENTS_MD="$TARGET_ROOT/AGENTS.md"
  if ! grep -qF '.agents/rules/' "$AGENTS_MD" 2>/dev/null; then
    cat >> "$AGENTS_MD" <<'EOF'

## Agent rules (lazyway-io boilerplate)

Read and follow every markdown file in `.agents/rules/` — they are always-on
rules for this project. On-demand skills live in `.agents/skills/` (Agent
Skills standard). Ignore other harnesses' config trees (`.cline/`,
`.clinerules/`, `.claude/`, `CLAUDE.md`) — they carry these same rules,
retuned for other agents.
EOF
  fi

  # Gemini/Antigravity ignore file
  for line in ".cline/" ".clinerules/" ".clineignore" ".claude/" "CLAUDE.md"; do
    grep -qxF "$line" "$TARGET_ROOT/.geminiignore" 2>/dev/null || \
      printf '%s\n' "$line" >> "$TARGET_ROOT/.geminiignore"
  done
  say "    .agents/ installed (AGENTS.md pointer appended, .geminiignore written)"
  say ""
fi

say "Done. Installed into: $TARGET_ROOT"
say ""
if [ "$cline_on" = "1" ]; then say "Recommended Cline settings: Focus Chain ON | Double-Check Completion ON | Auto Compact ON | Subagents ON | Strict Plan Mode OFF"; fi
say "https://github.com/$BOILERPLATE_REPO#readme"
