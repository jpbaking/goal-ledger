# install.ps1 — installer/updater for jpbaking's boilerplate kit (Windows)
# https://github.com/jpbaking/lazyway-io-boilerplate
#
# Bundles three independent kits into one install:
#   - cline-rules       (required)  -> .clinerules\ core reasoning rules
#   - compose-helper    (required)  -> compose-helper.ps1 + env + its rule/skill
#     (both cline-rules and compose-helper delegate to their own installers)
#   - lazyway-io-design (optional)  -> design system rule + skill (frontend projects)
#
# Usage (from your project root, PowerShell 5.1+ or pwsh):
#   irm https://raw.githubusercontent.com/jpbaking/lazyway-io-boilerplate/main/install.ps1 | iex
#
# Non-interactive (CI / no terminal):
#   $env:ASSUME_YES='1'; irm .../install.ps1 | iex
#
# Include/skip the optional design kit without being asked:
#   $env:WITH_DESIGN='1'; irm .../install.ps1 | iex
#   $env:WITH_DESIGN='0'; irm .../install.ps1 | iex
#
# Install into a different directory (defaults to current directory):
#   $env:BOILERPLATE_TARGET='C:\path\to\project'; irm .../install.ps1 | iex
#
# Note: this boilerplate's own README.md and LICENSE (and this installer
# itself) are never written into the target project — they cover this repo,
# not yours.

& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference    = 'SilentlyContinue'   # WinPS 5.1: progress bar slows downloads badly

    $BoilerplateRepo = 'jpbaking/lazyway-io-boilerplate'

    $ClineRulesInstallUrl    = 'https://raw.githubusercontent.com/jpbaking/cline-rules/main/install.ps1'
    $ComposeHelperInstallUrl = 'https://raw.githubusercontent.com/jpbaking/compose-helper/main/.install-helper/install.ps1'
    $DesignBase              = 'https://raw.githubusercontent.com/jpbaking/lazyway-io-design/main'

    $TargetRoot = if ($env:BOILERPLATE_TARGET) { $env:BOILERPLATE_TARGET } else { (Get-Location).Path }

    function Say([string]$msg) { Write-Host $msg }

    # Note: never call `exit` in here — this whole block is meant to run via
    # `irm ... | iex`, and `exit` inside iex kills the caller's shell session.
    # Failures instead `throw` and are caught once at the bottom.
    function Ask([string]$question) {
        if ($env:ASSUME_YES -eq '1') {
            Say "$question [auto-yes via ASSUME_YES=1]"
            return $true
        }
        try {
            $ans = Read-Host "$question [y/N]"
        } catch {
            Say "$question [no terminal available -- defaulting to No]"
            return $false
        }
        return ($ans -match '^(y|Y|yes|YES)$')
    }

    function Fetch([string]$Url, [string]$OutFile) {
        $dir = Split-Path -Parent $OutFile
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Invoke-WebRequest -UseBasicParsing $Url -OutFile $OutFile
    }

    try {
        if (-not (Test-Path $TargetRoot)) { throw "Target directory '$TargetRoot' does not exist." }

        Say "jpbaking's boilerplate kit -- installer"
        Say "source: github.com/$BoilerplateRepo@main"
        Say "target: $TargetRoot"
        Say ""

        # --- 1/3 cline-rules (required) -------------------------------------
        Say "==> [1/3] cline-rules (required) -- delegating to its own installer"
        $env:CLINE_RULES_TARGET = $TargetRoot
        Invoke-Expression (Invoke-WebRequest -UseBasicParsing $ClineRulesInstallUrl).Content
        Say ""

        # --- 2/3 compose-helper (required) -----------------------------------
        Say "==> [2/3] compose-helper (required) -- delegating to its own installer"
        # compose-helper's installer has no target-directory override -- it
        # always installs into the current directory -- so switch into
        # $TargetRoot for the duration of the call.
        Push-Location $TargetRoot
        try {
            Invoke-Expression (Invoke-WebRequest -UseBasicParsing $ComposeHelperInstallUrl).Content
        } finally {
            Pop-Location
        }
        Say ""

        # --- 3/3 lazyway-io-design (optional) --------------------------------
        Say "==> [3/3] lazyway-io-design (optional -- only if this is a webapp with a frontend)"

        $InstallDesign = switch ($env:WITH_DESIGN) {
            '1'     { $true }
            '0'     { $false }
            default { Ask "    Install the design system rule + skill?" }
        }

        if ($InstallDesign) {
            Fetch "$DesignBase/cline/clinerules/lazyway-io-design.md" (Join-Path $TargetRoot '.clinerules\lazyway-io-design.md')
            Say "    .clinerules\lazyway-io-design.md"

            Fetch "$DesignBase/cline/skills/lazyway-io-design/SKILL.md" (Join-Path $TargetRoot '.cline\skills\lazyway-io-design\SKILL.md')
            Say "    .cline\skills\lazyway-io-design\SKILL.md"

            Fetch "$DesignBase/cline/skills/lazyway-io-design/templates/app.html" (Join-Path $TargetRoot '.cline\skills\lazyway-io-design\templates\app.html')
            Fetch "$DesignBase/cline/skills/lazyway-io-design/templates/page.html" (Join-Path $TargetRoot '.cline\skills\lazyway-io-design\templates\page.html')
            Say "    .cline\skills\lazyway-io-design\templates\"

            Say ""
            Say "    Note: this installs the rule + skill only, not the design/ CSS/JS kit"
            Say "    itself. The skill fetches design/ into the project on demand the"
            Say "    first time it's actually used -- see its Step 0."
        } else {
            Say "    Skipped."
        }

        Say ""
        Say "Done. Installed into: $TargetRoot"
        Say ""
        Say "Recommended Cline settings (see cline-rules README):"
        Say "  Focus Chain: ON | Double-Check Completion: ON | Auto Compact: ON | Subagents: ON | Strict Plan Mode: OFF"
        Say ""
        Say "https://github.com/$BoilerplateRepo#readme"
    }
    catch {
        Write-Error "ERROR: $($_.Exception.Message)"
    }
}
