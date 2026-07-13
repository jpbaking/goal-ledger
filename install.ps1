# install.ps1 — installer/updater for jpbaking's boilerplate kit (Windows)
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
#   $env:WITH_CLINE='1'|'0'    Cline        -> .clinerules\ + .cline\
#   $env:WITH_CLAUDE='1'|'0'   Claude Code  -> CLAUDE.md + .claude\
#   $env:WITH_AGENTS='1'|'0'   Codex/Antigravity/Gemini -> AGENTS.md + .agents\
#
# Component selection:
#   $env:WITH_DESIGN='1'|'0'   lazyway-io-design rule+skill (default: ask, No)
#   DOX and master-plan: when Cline is installed, upstream cline-rules asks
#   and the answer is mirrored to the other harnesses; without Cline, this
#   installer asks directly (default No each).
#
# Each installed harness also gets an ignore file / setting so it does not
# read the other harnesses' config trees (AGENTS.md itself is never ignored —
# it is the shared DOX contract).
#
# Usage (from your project root, PowerShell 5.1+ or pwsh):
#   irm https://raw.githubusercontent.com/jpbaking/lazyway-io-boilerplate/main/install.ps1 | iex
# Non-interactive:  $env:ASSUME_YES='1'; irm ... | iex
# Other directory:  $env:BOILERPLATE_TARGET='C:\path\to\project'; irm ... | iex
#
# This repo's own README.md and LICENSE (and this installer itself) are never
# written into the target project — they cover this repo, not yours.

& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference    = 'SilentlyContinue'   # WinPS 5.1: progress bar slows downloads badly

    $BoilerplateRepo = 'jpbaking/lazyway-io-boilerplate'
    $BoilerplateRef  = if ($env:LAZYWAY_BOILERPLATE_REF) { $env:LAZYWAY_BOILERPLATE_REF } else { 'main' }

    $ClineRulesInstallUrl    = 'https://raw.githubusercontent.com/jpbaking/cline-rules/main/install.ps1'
    $ComposeHelperInstallUrl = 'https://raw.githubusercontent.com/jpbaking/compose-helper/main/.install-helper/install.ps1'
    $DesignBase              = 'https://raw.githubusercontent.com/jpbaking/lazyway-io-design/main'
    $Sets                    = "https://raw.githubusercontent.com/jpbaking/lazyway-io-boilerplate/$BoilerplateRef/sets"

    $TargetRoot = if ($env:BOILERPLATE_TARGET) { $env:BOILERPLATE_TARGET } else { (Get-Location).Path }

    function Say([string]$msg) { Write-Host $msg }

    # Note: never call `exit` in here — this whole block runs via `irm | iex`,
    # and `exit` inside iex kills the caller's shell. Failures `throw` instead.
    function Ask([string]$Question, [string]$Default = 'n') {
        if ($env:ASSUME_YES -eq '1') {
            Say "$Question [auto-yes via ASSUME_YES=1]"
            return $true
        }
        $hint = if ($Default -eq 'y') { '[Y/n]' } else { '[y/N]' }
        try {
            $ans = Read-Host "$Question $hint"
        } catch {
            Say "$Question [no terminal -- defaulting to $Default]"
            return ($Default -eq 'y')
        }
        if ($ans -match '^(y|Y|yes|YES)$') { return $true }
        if ($ans -match '^(n|N|no|NO)$')   { return $false }
        return ($Default -eq 'y')
    }

    # env override ('1'/'0') or ask; $Default is the ask default
    function Decide([string]$EnvVal, [string]$Question, [string]$Default) {
        switch ($EnvVal) {
            '1'     { return $true }
            '0'     { return $false }
            default { return (Ask $Question $Default) }
        }
    }

    function Fetch([string]$Url, [string]$OutFile) {
        $dir = Split-Path -Parent $OutFile
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Invoke-WebRequest -UseBasicParsing $Url -OutFile $OutFile
    }

    function EnsureLine([string]$File, [string]$Line) {
        if (-not (Test-Path $File)) { Set-Content -Path $File -Value $Line; return }
        $text = Get-Content -Raw $File
        if ($text -notmatch [regex]::Escape($Line)) { Add-Content -Path $File -Value $Line }
    }

    try {
        if (-not (Test-Path $TargetRoot)) { throw "Target directory '$TargetRoot' does not exist." }

        Say "jpbaking's boilerplate kit -- installer"
        Say "source: github.com/$BoilerplateRepo@$BoilerplateRef"
        Say "target: $TargetRoot"
        Say ""

        # --- Selection --------------------------------------------------------
        Say "==> Which agent harnesses should this project support?"
        $ClineOn  = Decide $env:WITH_CLINE  "    Cline (.clinerules\ + .cline\, small-model set)?" 'y'
        $ClaudeOn = Decide $env:WITH_CLAUDE "    Claude Code (CLAUDE.md + .claude\, frontier set)?" 'y'
        $AgentsOn = Decide $env:WITH_AGENTS "    Codex / Antigravity / Gemini (AGENTS.md + .agents\, frontier set)?" 'y'
        if (-not ($ClineOn -or $ClaudeOn -or $AgentsOn)) { throw "Nothing selected -- nothing to do." }

        $DesignOn = Decide $env:WITH_DESIGN "    Include the lazyway-io-design component (webapps with a frontend)?" 'n'
        Say ""

        # --- compose-helper (always -- the script serves every harness) --------
        Say "==> compose-helper -- delegating to its own installer"
        Push-Location $TargetRoot
        try {
            try {
                Invoke-Expression (Invoke-WebRequest -UseBasicParsing $ComposeHelperInstallUrl).Content
            } catch {
                throw "compose-helper install failed. See https://github.com/jpbaking/compose-helper ($($_.Exception.Message))"
            }
        } finally { Pop-Location }
        Say ""

        # --- Cline (small-model set) --------------------------------------------
        if ($ClineOn) {
            Say "==> Cline -- delegating to cline-rules, then overlaying the small-model set"
            $env:CLINE_RULES_TARGET = $TargetRoot
            try {
                Invoke-Expression (Invoke-WebRequest -UseBasicParsing $ClineRulesInstallUrl).Content
            } catch {
                throw "cline-rules install failed. See https://github.com/jpbaking/cline-rules ($($_.Exception.Message))"
            }

            Fetch "$Sets/small/rules/00-core-reasoning-rules.md" (Join-Path $TargetRoot '.clinerules\00-core-reasoning-rules.md')

            if (Test-Path (Join-Path $TargetRoot '.clinerules\dox.md')) {
                Fetch "$Sets/shared/rules/dox.md" (Join-Path $TargetRoot '.clinerules\dox.md')
                Fetch "$Sets/shared/skills/dox-init/SKILL.md" (Join-Path $TargetRoot '.cline\skills\dox-init\SKILL.md')
                Fetch "$Sets/shared/skills/dox-init/templates/AGENTS.md" (Join-Path $TargetRoot '.cline\skills\dox-init\templates\AGENTS.md')
                if (Test-Path (Join-Path $TargetRoot '.cline\skills\dox-upgrade\SKILL.md')) {
                    Fetch "$Sets/shared/skills/dox-upgrade/SKILL.md" (Join-Path $TargetRoot '.cline\skills\dox-upgrade\SKILL.md')
                }
            }

            $LegacyRule = Join-Path $TargetRoot '.clinerules\plan-execute.md'
            $MpRule     = Join-Path $TargetRoot '.clinerules\master-plan.md'
            if ((Test-Path $LegacyRule) -or (Test-Path $MpRule)) {
                Remove-Item -Force -ErrorAction SilentlyContinue $LegacyRule
                Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $TargetRoot '.clinerules\workflows\plan-execute.md')
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $TargetRoot '.cline\skills\plan-execute')
                Fetch "$Sets/small/rules/master-plan.md" $MpRule
                foreach ($S in 'master-plan', 'master-plan-resume', 'master-plan-status', 'master-plan-clear') {
                    Fetch "$Sets/small/skills/$S/SKILL.md" (Join-Path $TargetRoot ".cline\skills\$S\SKILL.md")
                }
            }

            if ($DesignOn) {
                Fetch "$DesignBase/cline/clinerules/lazyway-io-design.md" (Join-Path $TargetRoot '.clinerules\lazyway-io-design.md')
                Fetch "$DesignBase/cline/skills/lazyway-io-design/SKILL.md" (Join-Path $TargetRoot '.cline\skills\lazyway-io-design\SKILL.md')
                Fetch "$DesignBase/cline/skills/lazyway-io-design/templates/app.html" (Join-Path $TargetRoot '.cline\skills\lazyway-io-design\templates\app.html')
                Fetch "$DesignBase/cline/skills/lazyway-io-design/templates/page.html" (Join-Path $TargetRoot '.cline\skills\lazyway-io-design\templates\page.html')
            }

            foreach ($Wf in 'compose-helper', 'dox-audit', 'dox-child', 'dox-fix', 'dox-init', 'dox-upgrade',
                            'lazyway-io-design', 'master-plan', 'master-plan-resume', 'master-plan-status',
                            'master-plan-clear') {
                if (Test-Path (Join-Path $TargetRoot ".cline\skills\$Wf\SKILL.md")) {
                    Fetch "$Sets/small/workflows/$Wf.md" (Join-Path $TargetRoot ".clinerules\workflows\$Wf.md")
                }
            }

            # ignore the other harnesses' trees (never AGENTS.md -- shared DOX)
            $ClineIgnore = Join-Path $TargetRoot '.clineignore'
            foreach ($Line in '.claude/', 'CLAUDE.md', '.agents/', '.geminiignore') {
                EnsureLine $ClineIgnore $Line
            }
            Say "    Cline installed (.clinerules\ .cline\ .clineignore)"
            Say ""
        }

        # --- Component flags for the frontier harnesses -------------------------
        $DoxOn = $false; $MpOn = $false
        if ($ClineOn) {
            $DoxOn = Test-Path (Join-Path $TargetRoot '.clinerules\dox.md')
            $MpOn  = Test-Path (Join-Path $TargetRoot '.clinerules\master-plan.md')
        } elseif ($ClaudeOn -or $AgentsOn) {
            $DoxOn = Ask "==> Include the DOX component (AGENTS.md doc framework)?" 'n'
            $MpOn  = Ask "==> Include the master-plan component (persistent task plans)?" 'n'
            Say ""
        }

        # One shared routine: install the frontier set under $FRoot,
        # with commands/workflows under $FCmds.
        function Install-FrontierTree([string]$FRoot, [string]$FCmds) {
            Fetch "$Sets/frontier/rules/core.md" (Join-Path $TargetRoot "$FRoot\rules\core.md")
            Fetch "$Sets/shared/rules/compose-helper.md" (Join-Path $TargetRoot "$FRoot\rules\compose-helper.md")
            if ($DoxOn) { Fetch "$Sets/shared/rules/dox.md" (Join-Path $TargetRoot "$FRoot\rules\dox.md") }
            if ($MpOn)  { Fetch "$Sets/frontier/rules/master-plan.md" (Join-Path $TargetRoot "$FRoot\rules\master-plan.md") }
            if ($DesignOn) { Fetch "$Sets/shared/rules/lazyway-io-design.md" (Join-Path $TargetRoot "$FRoot\rules\lazyway-io-design.md") }

            $Skills = @('compose-helper')
            if ($DoxOn)    { $Skills += 'dox-audit', 'dox-child', 'dox-fix', 'dox-init', 'dox-upgrade' }
            if ($DesignOn) { $Skills += 'lazyway-io-design' }
            foreach ($S in $Skills) {
                Fetch "$Sets/shared/skills/$S/SKILL.md" (Join-Path $TargetRoot "$FRoot\skills\$S\SKILL.md")
                Fetch "$Sets/frontier/commands/$S.md" (Join-Path $TargetRoot "$FCmds\$S.md")
            }
            if ($MpOn) {
                foreach ($S in 'master-plan', 'master-plan-resume', 'master-plan-status', 'master-plan-clear') {
                    Fetch "$Sets/frontier/skills/$S/SKILL.md" (Join-Path $TargetRoot "$FRoot\skills\$S\SKILL.md")
                    Fetch "$Sets/frontier/commands/$S.md" (Join-Path $TargetRoot "$FCmds\$S.md")
                }
            }
            if ($DoxOn) {
                Fetch "$Sets/shared/skills/dox-init/templates/AGENTS.md" (Join-Path $TargetRoot "$FRoot\skills\dox-init\templates\AGENTS.md")
            }
            if ($DesignOn) {
                Fetch "$Sets/shared/skills/lazyway-io-design/templates/app.html" (Join-Path $TargetRoot "$FRoot\skills\lazyway-io-design\templates\app.html")
                Fetch "$Sets/shared/skills/lazyway-io-design/templates/page.html" (Join-Path $TargetRoot "$FRoot\skills\lazyway-io-design\templates\page.html")
            }
        }

        # --- Claude Code (frontier set) ------------------------------------------
        if ($ClaudeOn) {
            Say "==> Claude Code -- CLAUDE.md + .claude\{rules,skills,commands}"
            Install-FrontierTree '.claude' '.claude\commands'

            $ClaudeMd = Join-Path $TargetRoot 'CLAUDE.md'
            if (-not (Test-Path $ClaudeMd)) {
                Set-Content -Path $ClaudeMd -Value "# Project rules`n`nAlways-on rules, one file per installed component:`n"
            }
            foreach ($R in 'core', 'compose-helper', 'dox', 'master-plan', 'lazyway-io-design') {
                if (Test-Path (Join-Path $TargetRoot ".claude\rules\$R.md")) {
                    EnsureLine $ClaudeMd "@.claude/rules/$R.md"
                }
            }

            $CcSettings = Join-Path $TargetRoot '.claude\settings.json'
            if (-not (Test-Path $CcSettings)) {
                $SettingsJson = @'
{
  "permissions": {
    "deny": [
      "Read(./.cline/**)",
      "Read(./.clinerules/**)",
      "Read(./.agents/**)"
    ]
  }
}
'@
                Set-Content -Path $CcSettings -Value $SettingsJson
            } else {
                Say "    NOTE: .claude\settings.json exists -- add Read() deny rules for .cline\, .clinerules\, .agents\ yourself if wanted"
            }
            Say "    Claude Code installed"
            Say ""
        }

        # --- .agents convention: Codex CLI / Antigravity / Gemini CLI -------------
        if ($AgentsOn) {
            Say "==> Codex/Antigravity/Gemini -- AGENTS.md pointer + .agents\{rules,skills,workflows}"
            Install-FrontierTree '.agents' '.agents\workflows'

            $AgentsMd = Join-Path $TargetRoot 'AGENTS.md'
            $Pointer = @'

## Agent rules (lazyway-io boilerplate)

Read and follow every markdown file in `.agents/rules/` — they are always-on
rules for this project. On-demand skills live in `.agents/skills/` (Agent
Skills standard). Ignore other harnesses' config trees (`.cline/`,
`.clinerules/`, `.claude/`, `CLAUDE.md`) — they carry these same rules,
retuned for other agents.
'@
            $HasPointer = (Test-Path $AgentsMd) -and ((Get-Content -Raw $AgentsMd) -match [regex]::Escape('.agents/rules/'))
            if (-not $HasPointer) { Add-Content -Path $AgentsMd -Value $Pointer }

            $GeminiIgnore = Join-Path $TargetRoot '.geminiignore'
            foreach ($Line in '.cline/', '.clinerules/', '.clineignore', '.claude/', 'CLAUDE.md') {
                EnsureLine $GeminiIgnore $Line
            }
            Say "    .agents\ installed (AGENTS.md pointer appended, .geminiignore written)"
            Say ""
        }

        Say "Done. Installed into: $TargetRoot"
        Say ""
        if ($ClineOn) {
            Say "Recommended Cline settings: Focus Chain ON | Double-Check Completion ON | Auto Compact ON | Subagents ON | Strict Plan Mode OFF"
        }
        Say "https://github.com/$BoilerplateRepo#readme"
    }
    catch {
        Write-Error "ERROR: $($_.Exception.Message)"
    }
}
