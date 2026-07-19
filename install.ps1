# Project-local installer/updater for Goal Ledger (PowerShell 5.1+).
# Downloads one complete source archive, validates it, and installs from it.

& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    $GoalLedgerRepo = if ($env:GOAL_LEDGER_REPO) { $env:GOAL_LEDGER_REPO } else { 'jpbaking/goal-ledger' }
    $GoalLedgerRef = if ($env:GOAL_LEDGER_REF) { $env:GOAL_LEDGER_REF } else { 'main' }
    $TargetRoot = if ($env:GOAL_LEDGER_TARGET) { $env:GOAL_LEDGER_TARGET } else { (Get-Location).Path }
    $StagingRoot = $null
    $SourceRoot = $null
    $Failure = $null
    $ActiveIncoming = $null
    $ActiveBackup = $null

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

    function Decide([string]$Value, [string]$Question, [string]$Default, [string]$VariableName) {
        switch ($Value) {
            '1' { return $true }
            '0' { return $false }
            '' { return (Ask $Question $Default) }
            default { throw "Expected 1 or 0 for $VariableName; got '$Value'." }
        }
    }

    function Get-TextDocument([string]$Path) {
        $Bytes = [System.IO.File]::ReadAllBytes($Path)
        $Offset = 0
        if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
            $Encoding = New-Object System.Text.UTF8Encoding($true, $true); $Offset = 3
        }
        elseif ($Bytes.Length -ge 4 -and $Bytes[0] -eq 0x00 -and $Bytes[1] -eq 0x00 -and $Bytes[2] -eq 0xFE -and $Bytes[3] -eq 0xFF) {
            $Encoding = New-Object System.Text.UTF32Encoding($true, $true, $true); $Offset = 4
        }
        elseif ($Bytes.Length -ge 4 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE -and $Bytes[2] -eq 0x00 -and $Bytes[3] -eq 0x00) {
            $Encoding = New-Object System.Text.UTF32Encoding($false, $true, $true); $Offset = 4
        }
        elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) {
            $Encoding = New-Object System.Text.UnicodeEncoding($true, $true, $true); $Offset = 2
        }
        elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) {
            $Encoding = New-Object System.Text.UnicodeEncoding($false, $true, $true); $Offset = 2
        }
        else {
            $Encoding = New-Object System.Text.UTF8Encoding($false, $true)
            try { $null = $Encoding.GetString($Bytes) }
            catch { $Encoding = [System.Text.Encoding]::Default }
        }
        $Text = $Encoding.GetString($Bytes, $Offset, $Bytes.Length - $Offset)
        return @{ Text = $Text; Encoding = $Encoding }
    }

    function Set-TextDocument([string]$Path, [string]$Text, [System.Text.Encoding]$Encoding) {
        [System.IO.File]::WriteAllText($Path, $Text, $Encoding)
    }

    function Ensure-Line([string]$File, [string]$Line, [string]$InitialHeading) {
        if (-not (Test-Path -LiteralPath $File)) {
            $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            Set-TextDocument $File "$InitialHeading`r`n`r`n$Line`r`n" $Utf8NoBom
            return
        }
        $Document = Get-TextDocument $File
        if (($Document.Text -split '\r?\n') -contains $Line) { return }
        $Newline = if ($Document.Text.Contains("`r`n")) { "`r`n" } else { "`n" }
        $Text = $Document.Text
        if ($Text.Length -gt 0 -and -not $Text.EndsWith("`n") -and -not $Text.EndsWith("`r")) { $Text += $Newline }
        $Text += "$Line$Newline"
        Set-TextDocument $File $Text $Document.Encoding
    }

    function Ensure-AgentsPointer([string]$File) {
        $RulePath = '.agents/rules/goal-ledger.md'
        if (Test-Path -LiteralPath $File) {
            $Document = Get-TextDocument $File
            if ($Document.Text.Contains($RulePath)) { return }
            $Newline = if ($Document.Text.Contains("`r`n")) { "`r`n" } else { "`n" }
            $Text = $Document.Text
            if ($Text.Length -gt 0 -and -not $Text.EndsWith("`n") -and -not $Text.EndsWith("`r")) { $Text += $Newline }
            $Text += "$Newline## Goal Ledger$Newline$NewlineRead and follow ``.agents/rules/goal-ledger.md``.$Newline"
            $Text += "Reusable procedures live in ``.agents/skills/``; use the matching skill when its$Newline"
            $Text += "description applies.$Newline"
            Set-TextDocument $File $Text $Document.Encoding
            return
        }
        $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $Text = "# Project rules`r`n`r`n## Goal Ledger`r`n`r`nRead and follow ``.agents/rules/goal-ledger.md``.`r`n"
        $Text += "Reusable procedures live in ``.agents/skills/``; use the matching skill when its`r`n"
        $Text += "description applies.`r`n"
        Set-TextDocument $File $Text $Utf8NoBom
    }

    function Prepare-Source {
        if ($env:GOAL_LEDGER_SOURCE) {
            if (-not (Test-Path -LiteralPath $env:GOAL_LEDGER_SOURCE -PathType Container)) {
                throw "GOAL_LEDGER_SOURCE '$($env:GOAL_LEDGER_SOURCE)' is not a directory."
            }
            $ResolvedSource = (Resolve-Path -LiteralPath $env:GOAL_LEDGER_SOURCE).Path
            Say "source: local directory $ResolvedSource"
            return $ResolvedSource
        }

        $NewStagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("goal-ledger-install-" + [Guid]::NewGuid().ToString('N'))
        Set-Variable -Name StagingRoot -Value $NewStagingRoot -Scope 1
        $Archive = Join-Path $NewStagingRoot 'source.zip'
        $Extracted = Join-Path $NewStagingRoot 'source'
        New-Item -ItemType Directory -Path $Extracted -Force | Out-Null
        $EncodedRef = [Uri]::EscapeDataString($GoalLedgerRef)
        $ArchiveUrl = if ($env:GOAL_LEDGER_ARCHIVE_URL) { $env:GOAL_LEDGER_ARCHIVE_URL } else { "https://api.github.com/repos/$GoalLedgerRepo/zipball/$EncodedRef" }
        Say "source: github.com/$GoalLedgerRepo@$GoalLedgerRef"
        if ([System.IO.File]::Exists($ArchiveUrl)) {
            Copy-Item -LiteralPath $ArchiveUrl -Destination $Archive
        }
        else {
            [Net.ServicePointManager]::SecurityProtocol =
                [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -UseBasicParsing $ArchiveUrl -OutFile $Archive
        }
        Expand-Archive -LiteralPath $Archive -DestinationPath $Extracted
        $Directories = @(Get-ChildItem -LiteralPath $Extracted -Directory)
        if ($Directories.Count -ne 1) { throw 'Downloaded archive did not contain exactly one project directory.' }
        return $Directories[0].FullName
    }

    function Validate-Source {
        $Rule = Join-Path $SourceRoot 'rules/goal-ledger.md'
        if (-not (Test-Path -LiteralPath $Rule -PathType Leaf)) { throw 'Source is missing rules/goal-ledger.md.' }
        $Validator = Join-Path $SourceRoot 'skills/goal-ledger/scripts/validate_goal_ledger.py'
        if (-not (Test-Path -LiteralPath $Validator -PathType Leaf)) { throw 'Source is missing the Goal Ledger validator script.' }
        foreach ($Skill in 'goal-ledger', 'goal-ledger-resume', 'goal-ledger-status', 'goal-ledger-abandon') {
            $SkillFile = Join-Path $SourceRoot "skills/$Skill/SKILL.md"
            if (-not (Test-Path -LiteralPath $SkillFile -PathType Leaf)) { throw "Source is missing skills/$Skill/SKILL.md." }
            $Text = [System.IO.File]::ReadAllText($SkillFile)
            if ($Text -notmatch "(?m)^name:\s*$([regex]::Escape($Skill))\s*$") { throw "Skill name does not match directory '$Skill'." }
            if ($Text -notmatch '(?m)^description:') { throw "Skill '$Skill' has no description." }
        }
    }

    function Install-File([string]$SourceFile, [string]$RelativeDestination) {
        $Destination = Join-Path $TargetRoot $RelativeDestination
        $Parent = Split-Path -Parent $Destination
        $Incoming = "$Destination.goal-ledger-install-$PID"
        $Backup = "$Destination.goal-ledger-backup-$PID"
        if (-not (Test-Path -LiteralPath $Parent)) { New-Item -ItemType Directory -Path $Parent -Force | Out-Null }
        if (Test-Path -LiteralPath $Destination -PathType Container) { throw "Expected file destination but found directory: $Destination" }
        if (Test-Path -LiteralPath $Incoming) { throw "Temporary installation path already exists: $Incoming" }
        if (Test-Path -LiteralPath $Backup) { throw "Temporary backup path already exists: $Backup" }
        Set-Variable -Name ActiveIncoming -Value $Incoming -Scope 1
        Set-Variable -Name ActiveBackup -Value $Backup -Scope 1
        Copy-Item -LiteralPath $SourceFile -Destination $Incoming
        if (Test-Path -LiteralPath $Destination) { Move-Item -LiteralPath $Destination -Destination $Backup }
        try {
            Move-Item -LiteralPath $Incoming -Destination $Destination
            if (Test-Path -LiteralPath $Backup) { Remove-Item -LiteralPath $Backup -Force }
            Set-Variable -Name ActiveIncoming -Value $null -Scope 1
            Set-Variable -Name ActiveBackup -Value $null -Scope 1
        }
        catch {
            if (Test-Path -LiteralPath $Backup) { Move-Item -LiteralPath $Backup -Destination $Destination }
            Set-Variable -Name ActiveBackup -Value $null -Scope 1
            throw
        }
    }

    function Install-Tree([string]$SourceTree, [string]$RelativeDestination) {
        $Destination = Join-Path $TargetRoot $RelativeDestination
        $Parent = Split-Path -Parent $Destination
        $Incoming = "$Destination.goal-ledger-install-$PID"
        $Backup = "$Destination.goal-ledger-backup-$PID"
        if (-not (Test-Path -LiteralPath $Parent)) { New-Item -ItemType Directory -Path $Parent -Force | Out-Null }
        if (Test-Path -LiteralPath $Incoming) { throw "Temporary installation path already exists: $Incoming" }
        if (Test-Path -LiteralPath $Backup) { throw "Temporary backup path already exists: $Backup" }
        Set-Variable -Name ActiveIncoming -Value $Incoming -Scope 1
        Set-Variable -Name ActiveBackup -Value $Backup -Scope 1
        Copy-Item -LiteralPath $SourceTree -Destination $Incoming -Recurse
        if (Test-Path -LiteralPath $Destination) { Move-Item -LiteralPath $Destination -Destination $Backup }
        try {
            Move-Item -LiteralPath $Incoming -Destination $Destination
            if (Test-Path -LiteralPath $Backup) { Remove-Item -LiteralPath $Backup -Recurse -Force }
            Set-Variable -Name ActiveIncoming -Value $null -Scope 1
            Set-Variable -Name ActiveBackup -Value $null -Scope 1
        }
        catch {
            if (Test-Path -LiteralPath $Backup) { Move-Item -LiteralPath $Backup -Destination $Destination }
            Set-Variable -Name ActiveBackup -Value $null -Scope 1
            throw
        }
    }

    function Install-Rule([string]$Destination) {
        Install-File (Join-Path $SourceRoot 'rules/goal-ledger.md') "$Destination/goal-ledger.md"
    }

    function Install-Skills([string]$Destination) {
        foreach ($Skill in 'goal-ledger', 'goal-ledger-resume', 'goal-ledger-status', 'goal-ledger-abandon') {
            Install-Tree (Join-Path $SourceRoot "skills/$Skill") "$Destination/$Skill"
        }
    }

    function Test-LegacyActivePlan {
        $LegacyPlan = Join-Path $TargetRoot '.tmp-agent-scratch/MASTER-PLAN.md'
        if (-not (Test-Path -LiteralPath $LegacyPlan)) { return }
        $Document = Get-TextDocument $LegacyPlan
        $StatusLine = $Document.Text -split '\r?\n' | Where-Object { $_ -like '- Plan status: *' } | Select-Object -First 1
        $Status = if ($StatusLine) { $StatusLine.Substring(15) } else { 'unknown' }
        if ($Status -ne 'done') {
            throw "An unfinished legacy MASTER-PLAN exists in .tmp-agent-scratch/ (status: $Status). Resume, finish, abandon, or migrate it before installing; no files were changed."
        }
        Say 'NOTE: completed legacy .tmp-agent-scratch/ left untouched.'
    }

    function Inspect-SameNamedArtifacts {
        foreach ($Path in '.agents/rules/master-plan.md', '.claude/rules/master-plan.md', '.clinerules/master-plan.md',
                          '.agents/skills/master-plan', '.agents/skills/master-plan-resume',
                          '.agents/skills/master-plan-status', '.agents/skills/master-plan-clear',
                          '.claude/skills/master-plan', '.claude/skills/master-plan-resume',
                          '.claude/skills/master-plan-status', '.claude/skills/master-plan-clear',
                          '.cline/skills/master-plan', '.cline/skills/master-plan-resume',
                          '.cline/skills/master-plan-status', '.cline/skills/master-plan-clear',
                          '.claude/commands/master-plan.md', '.claude/commands/master-plan-resume.md',
                          '.claude/commands/master-plan-status.md', '.claude/commands/master-plan-clear.md',
                          '.clinerules/workflows/master-plan.md', '.clinerules/workflows/master-plan-resume.md',
                          '.clinerules/workflows/master-plan-status.md', '.clinerules/workflows/master-plan-clear.md') {
            if (Test-Path -LiteralPath (Join-Path $TargetRoot $Path)) {
                Say "NOTE: existing $Path is not owned by this installer and will be left untouched."
            }
        }
        foreach ($Skill in 'goal-ledger', 'goal-ledger-resume', 'goal-ledger-status', 'goal-ledger-abandon') {
            foreach ($Root in '.agents', '.claude') {
                $Destination = "$Root/skills/$Skill"
                if (Test-Path -LiteralPath (Join-Path $TargetRoot $Destination)) {
                    Say "NOTE: existing $Destination is a same-named installation destination and will be refreshed if selected."
                }
            }
            $Duplicate = ".cline/skills/$Skill"
            if (Test-Path -LiteralPath (Join-Path $TargetRoot $Duplicate)) {
                Say "WARNING: existing $Duplicate is left untouched and may duplicate .agents/skills/$Skill in Cline."
            }
        }
        foreach ($Root in '.agents', '.claude') {
            $Destination = "$Root/rules/goal-ledger.md"
            if (Test-Path -LiteralPath (Join-Path $TargetRoot $Destination)) {
                Say "NOTE: existing $Destination is a same-named installation destination and will be refreshed if selected."
            }
        }
    }

    function Inspect-GlobalCollisions {
        if (-not $HOME) { return }
        foreach ($Skill in 'goal-ledger', 'goal-ledger-resume', 'goal-ledger-status', 'goal-ledger-abandon') {
            foreach ($Root in '.agents/skills', '.cline/skills', '.claude/skills', '.gemini/skills', '.gemini/config/skills') {
                $Path = Join-Path (Join-Path $HOME $Root) $Skill
                if (Test-Path -LiteralPath $Path) {
                    Say "WARNING: global $Path may shadow or duplicate the project skill; verify the selected harness resolves the project adapter."
                }
            }
        }
    }

    function Warn-ClineIgnore {
        $ClineIgnore = Join-Path $TargetRoot '.clineignore'
        if (-not (Test-Path -LiteralPath $ClineIgnore)) { return }
        $Document = Get-TextDocument $ClineIgnore
        $Pattern = $Document.Text -split '\r?\n' | Where-Object {
            $_ -match '\.agents' -and $_ -notmatch '^\s*[#!]' -and $_ -notmatch '^\s*$'
        } | Select-Object -First 1
        if ($Pattern) {
            Say "WARNING: .clineignore pattern '$Pattern' may restrict access to the canonical .agents content; it was preserved. Review the rule and verify Cline can load and use Goal Ledger."
        }
    }


    function Warn-RedundantClaudeImport {
        $ClaudeMd = Join-Path $TargetRoot 'CLAUDE.md'
        if (-not (Test-Path -LiteralPath $ClaudeMd)) { return }
        $Document = Get-TextDocument $ClaudeMd
        if (($Document.Text -split '\r?\n') -contains '@.claude/rules/goal-ledger.md') {
            Say 'WARNING: CLAUDE.md imports @.claude/rules/goal-ledger.md, which Claude also auto-discovers in .claude/rules. The existing line was preserved; remove it after review to avoid redundant guidance.'
        }
    }

    function Test-TreesEqual([string]$Left, [string]$Right) {
        $LeftFiles = @(Get-ChildItem -LiteralPath $Left -File -Recurse)
        $RightFiles = @(Get-ChildItem -LiteralPath $Right -File -Recurse)
        if ($LeftFiles.Count -ne $RightFiles.Count) { return $false }
        foreach ($LeftFile in $LeftFiles) {
            $Relative = $LeftFile.FullName.Substring($Left.Length).TrimStart([char[]]@('\', '/'))
            $RightFile = Join-Path $Right $Relative
            if (-not (Test-Path -LiteralPath $RightFile -PathType Leaf)) { return $false }
            if ((Get-FileHash -LiteralPath $LeftFile.FullName -Algorithm SHA256).Hash -ne
                (Get-FileHash -LiteralPath $RightFile -Algorithm SHA256).Hash) { return $false }
        }
        return $true
    }

    function Verify-OverlappingSkillCopies {
        if (-not ($ClineOn -and $ClaudeOn)) { return }
        foreach ($Skill in 'goal-ledger', 'goal-ledger-resume', 'goal-ledger-status', 'goal-ledger-abandon') {
            $AgentsSkill = Join-Path $TargetRoot ".agents/skills/$Skill"
            $ClaudeSkill = Join-Path $TargetRoot ".claude/skills/$Skill"
            if (-not (Test-TreesEqual $AgentsSkill $ClaudeSkill)) {
                throw "Overlapping Cline/Claude adapters differ for skill '$Skill'."
            }
        }
        Say "NOTE: Cline and Claude require overlapping discovery adapters. Copies are byte-identical; confirm Cline's skill list exposes each Goal Ledger name once."
    }

    try {
        if (-not (Test-Path -LiteralPath $TargetRoot -PathType Container)) { throw "Target directory '$TargetRoot' does not exist." }

        Say 'Goal Ledger -- installer'
        Say "target: $TargetRoot"
        Say ''
        Say '==> Which agent harnesses should this project support?'
        $ClineOn = Decide $env:WITH_CLINE '    Cline (AGENTS.md + .agents/skills)?' 'y' 'WITH_CLINE'
        $ClaudeOn = Decide $env:WITH_CLAUDE '    Claude Code (.claude/rules + .claude/skills)?' 'y' 'WITH_CLAUDE'
        $AgentsOn = Decide $env:WITH_AGENTS '    Codex / Antigravity (AGENTS.md + .agents/)?' 'y' 'WITH_AGENTS'
        $GeminiValue = if (Test-Path Env:WITH_GEMINI) { $env:WITH_GEMINI } else { $env:WITH_AGENTS }
        $GeminiOn = Decide $GeminiValue '    Gemini CLI (GEMINI.md + .agents/skills)?' 'y' 'WITH_GEMINI'
        if (-not ($ClineOn -or $ClaudeOn -or $AgentsOn -or $GeminiOn)) { throw 'Nothing selected -- nothing to do.' }
        Say ''

        Test-LegacyActivePlan
        $SourceRoot = Prepare-Source
        Validate-Source
        Inspect-SameNamedArtifacts
        Inspect-GlobalCollisions

        if ($ClineOn -or $AgentsOn -or $GeminiOn) {
            Say '==> Shared .agents convention -- Goal Ledger'
            Install-Rule '.agents/rules'
            Install-Skills '.agents/skills'
            if ($ClineOn) { Warn-ClineIgnore }
            if ($ClineOn -or $AgentsOn) { Ensure-AgentsPointer (Join-Path $TargetRoot 'AGENTS.md') }
            if ($GeminiOn) { Ensure-Line (Join-Path $TargetRoot 'GEMINI.md') '@.agents/rules/goal-ledger.md' '# Project context' }
            Say '    installed .agents/{rules,skills} and preserved root instruction files'
            Say ''
        }

        if ($ClaudeOn) {
            Say '==> Claude Code -- Goal Ledger'
            Install-Rule '.claude/rules'
            Install-Skills '.claude/skills'
            Warn-RedundantClaudeImport
            Say '    installed auto-discovered .claude/{rules,skills} and preserved CLAUDE.md'
            Say ''
        }

        Verify-OverlappingSkillCopies

        Say "Done. Installed the Goal Ledger rule and skill family into: $TargetRoot"
        Say 'Unrelated and legacy files were inspected but left untouched.'
        Say 'Ask your agent to use the goal-ledger skill for multi-phase work.'
        Say "https://github.com/$GoalLedgerRepo#readme"
    }
    catch {
        $Failure = $_
    }
    finally {
        if ($ActiveIncoming -and (Test-Path -LiteralPath $ActiveIncoming)) {
            Remove-Item -LiteralPath $ActiveIncoming -Recurse -Force
        }
        if ($ActiveBackup -and (Test-Path -LiteralPath $ActiveBackup)) {
            Say "WARNING: interrupted install backup left at $ActiveBackup"
        }
        if ($StagingRoot -and (Test-Path -LiteralPath $StagingRoot)) {
            Remove-Item -LiteralPath $StagingRoot -Recurse -Force
        }
    }
    if ($Failure) {
        throw "ERROR: $($Failure.Exception.Message)"
    }
}
