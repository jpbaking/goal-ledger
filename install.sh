#!/bin/sh
# install.sh — installer/updater for jpbaking's boilerplate kit
# https://github.com/jpbaking/lazyway-io-boilerplate
#
# Bundles three independent kits into one install:
#   - cline-rules       (required)  -> .clinerules/ core reasoning rules
#   - compose-helper    (required)  -> compose-helper.sh + env + its rule/skill
#     (both cline-rules and compose-helper delegate to their own installers)
#   - lazyway-io-design (optional)  -> design system rule + skill (frontend projects)
#
# Usage (from your project root):
#   curl -fsSL https://raw.githubusercontent.com/jpbaking/lazyway-io-boilerplate/main/install.sh | sh
#
# Non-interactive (CI / no terminal):
#   curl -fsSL .../install.sh | ASSUME_YES=1 sh
#
# Include the optional design kit without being asked:
#   curl -fsSL .../install.sh | WITH_DESIGN=1 sh
# Skip it without being asked:
#   curl -fsSL .../install.sh | WITH_DESIGN=0 sh
#
# Optional: install into a different directory (defaults to current directory):
#   curl -fsSL .../install.sh | sh -s -- /path/to/project
#
# What it does:
#   - required kits are always installed/updated, no prompt
#   - cline-rules and compose-helper installs are both delegated to their own
#     installers (safe merge/renumber logic for .clinerules/, and env-file key
#     diffing for compose-helper.env, live there — not duplicated here)
#   - the design kit is asked about unless WITH_DESIGN is set
#   - this boilerplate's own README.md and LICENSE (and this installer itself)
#     are never written into the target project — they cover this repo, not yours

set -eu

BOILERPLATE_REPO="jpbaking/lazyway-io-boilerplate"
BOILERPLATE_REF="${LAZYWAY_BOILERPLATE_REF:-main}"

CLINE_RULES_INSTALL_URL="https://raw.githubusercontent.com/jpbaking/cline-rules/main/install.sh"
COMPOSE_HELPER_INSTALL_URL="https://raw.githubusercontent.com/jpbaking/compose-helper/main/.install-helper/install.sh"

DESIGN_BASE="https://raw.githubusercontent.com/jpbaking/lazyway-io-design/main"

TARGET_ROOT="${1:-.}"

say()  { printf '%s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
abort(){ say ""; say "Aborted — nothing further was changed."; exit 1; }

if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -q -O "$2" "$1"; }
else
  die "Neither curl nor wget found."
fi

# Yes/no prompt that works under `curl | sh` (stdin is the pipe) — read the
# controlling terminal directly instead. No terminal at all -> default No.
ask() {
  if [ "${ASSUME_YES:-0}" = "1" ]; then
    say "$1 [auto-yes via ASSUME_YES=1]"
    return 0
  fi
  if ! ( : < /dev/tty > /dev/tty ) 2>/dev/null; then
    say "$1 [no terminal available — defaulting to No]"
    return 1
  fi
  while :; do
    printf '%s [y/N] ' "$1" > /dev/tty
    IFS= read -r ans < /dev/tty || ans=""
    case "$ans" in
      y|Y|yes|YES) return 0 ;;
      n|N|no|NO|"") return 1 ;;
    esac
  done
}

[ -d "$TARGET_ROOT" ] || die "Target directory '$TARGET_ROOT' does not exist."

say "jpbaking's boilerplate kit — installer"
say "source: github.com/$BOILERPLATE_REPO@$BOILERPLATE_REF"
say "target: $TARGET_ROOT"
say ""

# --- 1/3 cline-rules (required) ---------------------------------------------
say "==> [1/3] cline-rules (required) — delegating to its own installer"
if ! curl -fsSL "$CLINE_RULES_INSTALL_URL" 2>/dev/null | sh -s -- "$TARGET_ROOT"; then
  die "cline-rules install failed. See https://github.com/jpbaking/cline-rules"
fi
say ""

# --- 2/3 compose-helper (required) ------------------------------------------
say "==> [2/3] compose-helper (required) — delegating to its own installer"
if ! ( cd "$TARGET_ROOT" && curl -fsSL "$COMPOSE_HELPER_INSTALL_URL" 2>/dev/null | bash ); then
  die "compose-helper install failed. See https://github.com/jpbaking/compose-helper"
fi
say ""

# --- 3/3 lazyway-io-design (optional) ---------------------------------------
say "==> [3/3] lazyway-io-design (optional — only if this is a webapp with a frontend)"

install_design=1
case "${WITH_DESIGN:-}" in
  1) install_design=0 ;;
  0) install_design=1 ;;
  *)
    if ask "    Install the design system rule + skill?"; then
      install_design=0
    fi
    ;;
esac

if [ "$install_design" -eq 0 ]; then
  mkdir -p "$TARGET_ROOT/.clinerules" "$TARGET_ROOT/.cline/skills/lazyway-io-design/templates"

  fetch "$DESIGN_BASE/cline/clinerules/lazyway-io-design.md" \
    "$TARGET_ROOT/.clinerules/lazyway-io-design.md"
  say "    .clinerules/lazyway-io-design.md"

  fetch "$DESIGN_BASE/cline/skills/lazyway-io-design/SKILL.md" \
    "$TARGET_ROOT/.cline/skills/lazyway-io-design/SKILL.md"
  say "    .cline/skills/lazyway-io-design/SKILL.md"

  fetch "$DESIGN_BASE/cline/skills/lazyway-io-design/templates/app.html" \
    "$TARGET_ROOT/.cline/skills/lazyway-io-design/templates/app.html"
  fetch "$DESIGN_BASE/cline/skills/lazyway-io-design/templates/page.html" \
    "$TARGET_ROOT/.cline/skills/lazyway-io-design/templates/page.html"
  say "    .cline/skills/lazyway-io-design/templates/"

  say ""
  say "    Note: this installs the rule + skill only, not the design/ CSS/JS kit"
  say "    itself. The skill fetches design/ into the project on demand the"
  say "    first time it's actually used — see its Step 0."
else
  say "    Skipped."
fi

say ""
say "Done. Installed into: $TARGET_ROOT"
say ""
say "Recommended Cline settings (see cline-rules README):"
say "  Focus Chain: ON | Double-Check Completion: ON | Auto Compact: ON | Subagents: ON | Strict Plan Mode: OFF"
say ""
say "https://github.com/$BOILERPLATE_REPO#readme"
