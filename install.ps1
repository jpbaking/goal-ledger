# Project-local installer/updater for Goal Ledger (PowerShell 5.1+).
# Installs the Goal Ledger rule and skill family.

& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    $GoalLedgerRepo = 'jpbaking/goal-ledger'
    $GoalLedgerRef = if ($env:GOAL_LEDGER_REF) { $env:GOAL_LEDGER_REF } else { 'main' }
    $ContentBase = "https://raw.githubusercontent.com/$GoalLedgerRepo/$GoalLedgerRef"
    $TargetRoot = if ($env:GOAL_LEDGER_TARGET) { $env:GOAL_LEDGER_TARGET } else { (Get-Location).Path }

    function Say([string]$Message) { Write-Host $Message }

    function Ask([string]$Question, [string]$Default = 'n') {
        if ($env:ASSUME_YES -eq '1') {
            Say "$Question [auto-yes via ASSUME_YES=1]"
            return $true
        }
        $Hint = if ($Default -eq 'y') { '[Y/n]' } else { '[y/N]' }
        try { $Answer = Read-Host "$Question $Hint" }
        catch {
            Say "$Question [no terminal -- defaulting to $Default]"
            return ($Default -eq 'y')
        }
        if ($Answer -match '^(y|Y|yes|YES)$') { return $true }
        if ($Answer -match '^(n|N|no|NO)$') { return $false }
        return ($Default -eq 'y')
    }

    function Decide([string]$Value, [string]$Question, [string]$Default) {
        switch ($Value) {
            '1' { return $true }
            '0' { return $false }
            default { return (Ask $Question $Default) }
        }
    }

    function Fetch([string]$Url, [string]$OutFile) {
        $Directory = Split-Path -Parent $OutFile
        if ($Directory -and -not (Test-Path $Directory)) {
            New-Item -ItemType Directory -Path $Directory -Force | Out-Null
        }
        Invoke-WebRequest -UseBasicParsing $Url -OutFile $OutFile
    }

    function Ensure-Line([string]$File, [string]$Line) {
        if (-not (Test-Path $File)) {
            Set-Content -Path $File -Value $Line
            return
        }
        $Lines = @(Get-Content $File)
        if ($Lines -notcontains $Line) { Add-Content -Path $File -Value $Line }
    }

    function Install-Rule([string]$Destination) {
        Fetch "$ContentBase/rules/goal-ledger.md" (Join-Path $TargetRoot "$Destination\goal-ledger.md")
    }

    function Install-Skills([string]$Destination) {
        foreach ($Skill in 'goal-ledger', 'goal-ledger-resume', 'goal-ledger-status', 'goal-ledger-abandon') {
            Fetch "$ContentBase/skills/$Skill/SKILL.md" (Join-Path $TargetRoot "$Destination\$Skill\SKILL.md")
        }
    }

    function Remove-GeneratedFile([string]$RelativePath) {
        $Path = Join-Path $TargetRoot $RelativePath
        if (Test-Path -LiteralPath $Path -PathType Leaf) { Remove-Item -LiteralPath $Path -Force }
    }

    function Remove-GeneratedTree([string]$RelativePath) {
        $Path = Join-Path $TargetRoot $RelativePath
        if (Test-Path -LiteralPath $Path -PathType Container) { Remove-Item -LiteralPath $Path -Recurse -Force }
    }

    function Remove-LegacyAdapters {
        foreach ($Root in '.agents', '.claude') {
            foreach ($Component in 'core', 'compose-helper', 'dox', 'lazyway-io-design', 'master-plan') {
                Remove-GeneratedFile "$Root\rules\$Component.md"
                Remove-GeneratedTree "$Root\skills\$Component"
            }
            foreach ($Skill in 'dox-audit', 'dox-child', 'dox-fix', 'dox-init', 'dox-upgrade',
                               'master-plan-resume', 'master-plan-status', 'master-plan-clear') {
                Remove-GeneratedTree "$Root\skills\$Skill"
            }
            foreach ($Wrapper in 'compose-helper', 'dox-audit', 'dox-child', 'dox-fix', 'dox-init', 'dox-upgrade',
                                  'lazyway-io-design', 'master-plan', 'master-plan-resume', 'master-plan-status',
                                  'master-plan-clear') {
                Remove-GeneratedFile "$Root\commands\$Wrapper.md"
                Remove-GeneratedFile "$Root\workflows\$Wrapper.md"
            }
        }

        foreach ($Component in '00-core-reasoning-rules', 'core', 'compose-helper', 'dox', 'lazyway-io-design', 'master-plan', 'plan-execute') {
            Remove-GeneratedFile ".clinerules\$Component.md"
        }
        foreach ($Skill in 'compose-helper', 'dox-audit', 'dox-child', 'dox-fix', 'dox-init', 'dox-upgrade',
                           'lazyway-io-design', 'master-plan', 'master-plan-resume', 'master-plan-status',
                           'master-plan-clear', 'plan-execute') {
            Remove-GeneratedTree ".cline\skills\$Skill"
            Remove-GeneratedFile ".clinerules\workflows\$Skill.md"
        }
    }

    function Remove-ClaudeLegacyImports {
        $ClaudeMd = Join-Path $TargetRoot 'CLAUDE.md'
        if (-not (Test-Path $ClaudeMd)) { return }
        $Retired = @(
            '@.claude/rules/core.md',
            '@.claude/rules/compose-helper.md',
            '@.claude/rules/dox.md',
            '@.claude/rules/lazyway-io-design.md',
            '@.claude/rules/master-plan.md'
        )
        $Original = @(Get-Content $ClaudeMd)
        $Lines = @($Original | Where-Object { $Retired -notcontains $_ })
        if ($Lines.Count -ne $Original.Count) { Set-Content -Path $ClaudeMd -Value $Lines }
    }

    function Migrate-AgentsPointer {
        $AgentsMd = Join-Path $TargetRoot 'AGENTS.md'
        if (-not (Test-Path $AgentsMd)) { return }
        $Legacy = 'Read and follow `core.md` and `master-plan.md` in `.agents/rules/`.'
        $Replacement = 'Read and follow every Markdown file in `.agents/rules/`.'
        $Original = @(Get-Content $AgentsMd)
        $Lines = @($Original | ForEach-Object {
            if ($_ -eq '## Agent rules (lazyway-io boilerplate)') { '## Goal Ledger' }
            elseif ($_ -eq $Legacy) { $Replacement }
            else { $_ }
        })
        if (($Original -join "`n") -ne ($Lines -join "`n")) { Set-Content -Path $AgentsMd -Value $Lines }
    }

    function Test-LegacyActivePlan {
        $LegacyPlan = Join-Path $TargetRoot '.tmp-agent-scratch\MASTER-PLAN.md'
        if (-not (Test-Path $LegacyPlan)) { return }
        $StatusLine = Get-Content $LegacyPlan | Where-Object { $_ -like '- Plan status: *' } | Select-Object -First 1
        $Status = if ($StatusLine) { $StatusLine.Substring(15) } else { 'unknown' }
        if ($Status -ne 'done') {
            throw "An unfinished legacy MASTER-PLAN exists in .tmp-agent-scratch\ (status: $Status). Resume, finish, abandon, or migrate it before upgrading; no files were changed."
        }
        Say "NOTE: completed legacy .tmp-agent-scratch\ left untouched; .goal-ledger\ is used for new goals."
    }

    function Allow-AgentsForCline {
        $ClineIgnore = Join-Path $TargetRoot '.clineignore'
        if (-not (Test-Path $ClineIgnore)) { return }
        $Original = @(Get-Content $ClineIgnore)
        $Lines = @($Original | Where-Object { $_ -ne '.agents/' })
        if ($Lines.Count -ne $Original.Count) { Set-Content -Path $ClineIgnore -Value $Lines }
    }

    try {
        if (-not (Test-Path $TargetRoot -PathType Container)) {
            throw "Target directory '$TargetRoot' does not exist."
        }

        Say "Goal Ledger -- installer"
        Say "source: github.com/$GoalLedgerRepo@$GoalLedgerRef"
        Say "target: $TargetRoot"
        Say ""
        Say "==> Which agent harnesses should this project support?"
        $ClineOn = Decide $env:WITH_CLINE "    Cline (AGENTS.md + .agents\skills)?" 'y'
        $ClaudeOn = Decide $env:WITH_CLAUDE "    Claude Code (CLAUDE.md + .claude\)?" 'y'
        $AgentsOn = Decide $env:WITH_AGENTS "    Codex / Antigravity / Gemini (AGENTS.md + .agents\)?" 'y'
        if (-not ($ClineOn -or $ClaudeOn -or $AgentsOn)) { throw 'Nothing selected -- nothing to do.' }
        Say ""

        Test-LegacyActivePlan

        if ($ClineOn -or $AgentsOn) {
            Say "==> Shared AGENTS convention -- Goal Ledger"
            Install-Rule '.agents\rules'
            Install-Skills '.agents\skills'

            $AgentsMd = Join-Path $TargetRoot 'AGENTS.md'
            $HasPointer = (Test-Path $AgentsMd) -and ((Get-Content -Raw $AgentsMd) -match [regex]::Escape('.agents/rules/'))
            if (-not $HasPointer) {
                $Pointer = @'

## Goal Ledger

Read and follow every Markdown file in `.agents/rules/`.
Reusable procedures live in `.agents/skills/`; use the matching skill when its
description applies.
'@
                Add-Content -Path $AgentsMd -Value $Pointer
            }
            if ($ClineOn) { Allow-AgentsForCline }
            Say "    installed .agents\{rules,skills} and preserved AGENTS.md"
            Say ""
        }

        if ($ClaudeOn) {
            Say "==> Claude Code -- Goal Ledger"
            Install-Rule '.claude\rules'
            Install-Skills '.claude\skills'

            $ClaudeMd = Join-Path $TargetRoot 'CLAUDE.md'
            if (-not (Test-Path $ClaudeMd)) { Set-Content -Path $ClaudeMd -Value "# Project rules`n" }
            Ensure-Line $ClaudeMd '@.claude/rules/goal-ledger.md'
            Say "    installed .claude\{rules,skills} and preserved CLAUDE.md"
            Say ""
        }

        Remove-LegacyAdapters
        Remove-ClaudeLegacyImports
        Migrate-AgentsPointer

        Say "Done. Installed the Goal Ledger rule and skill family into: $TargetRoot"
        Say "Previously installed compose-helper scripts and DOX content inside AGENTS.md are left untouched; remove them manually if no longer wanted."
        Say "Ask your agent to use the goal-ledger skill for multi-phase work."
        Say "https://github.com/$GoalLedgerRepo#readme"
    }
    catch {
        Write-Error "ERROR: $($_.Exception.Message)"
    }
}
