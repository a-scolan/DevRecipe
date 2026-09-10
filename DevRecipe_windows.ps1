[CmdletBinding()]
param(
    [Alias("Profile")]
    [string[]]$Profiles = @("default"),
    [switch]$Preflight,
    [Alias("NoPreflight")]
    [switch]$SkipPreflight,
    [switch]$Review,
    [switch]$DryRun,
    [switch]$Validate,
    [switch]$List,
    [switch]$Status,
    [string[]]$Uninstall = @(),
    [Alias("y")]
    [switch]$Yes,
    [Alias("f")]
    [switch]$Force,
    [switch]$Containers,
    [ValidateSet("Auto", "WSL", "HyperV")]
    [string]$ContainerProvider = "Auto",
    [Alias("DockerAlias")]
    [switch]$EnableDockerAlias,
    [Alias("FeaturesOnly")]
    [switch]$ContainerFeatureSetupOnly,
    [string]$ContainerTargetUserProfile
)

$ErrorActionPreference = "Stop"
$TomlPath = Join-Path $PSScriptRoot "DevRecipe_windows.toml"

# Private runtime helpers for the public preflight and review contracts.
$script:DevRecipePreflightThreshold = 90
$script:DevRecipePreflightMaxEvidence = 3
$script:DevRecipePreflightExcludedIds = @()
$script:DevRecipePreflightProviderMatches = @()
$script:DevRecipePreflightEvidence = @()
$script:DevRecipePreflightFilesystemCache = @()
$script:DevRecipePreflightIncompleteChecks = @()
$script:DevRecipePreflightApproveAll = $false
$script:DevRecipePreflightDeclineAll = $false
$script:DevRecipeReviewActionNumber = 0
$script:DevRecipeReviewApproved = @()
$script:DevRecipeReviewCompleted = @()
$script:DevRecipeReviewRejected = @()
$script:DevRecipeReviewUnreviewed = @()
$script:DevRecipeReviewPending = $null
$script:DevRecipeReviewApproveAll = $false

function Get-DevRecipePreflightScore {
    param([string]$Query, [string]$Evidence)
    $Left = $Query.ToLowerInvariant(); $Right = $Evidence.ToLowerInvariant()
    if ($Left -eq $Right) { return 100 }; if ($Left.Length -eq 0 -or $Right.Length -eq 0) { return 0 }
    $Previous = 0..$Right.Length
    for ($LeftIndex = 1; $LeftIndex -le $Left.Length; $LeftIndex++) {
        $Current = [int[]]::new($Right.Length + 1); $Current[0] = $LeftIndex
        for ($RightIndex = 1; $RightIndex -le $Right.Length; $RightIndex++) {
            $Substitution = $Previous[$RightIndex - 1] + [int]($Left[$LeftIndex - 1] -cne $Right[$RightIndex - 1]); $Deletion = $Previous[$RightIndex] + 1; $Insertion = $Current[$RightIndex - 1] + 1
            $Current[$RightIndex] = [Math]::Min($Substitution, [Math]::Min($Deletion, $Insertion))
        }
        $Previous = $Current
    }
    $Maximum = [Math]::Max($Left.Length, $Right.Length); return [int][Math]::Round((1 - ($Previous[$Right.Length] / $Maximum)) * 100, 0)
}
function Test-DevRecipePreflightSeparatorPrefix {
    param([string]$Query, [string]$Evidence)

    $Tokens = @($Query -split '[^A-Za-z0-9]+' | Where-Object { $_ })
    if ($Tokens.Count -eq 0) { return $false }
    $Pattern = '^' + (($Tokens | ForEach-Object { [regex]::Escape($_) }) -join '[^A-Za-z0-9]*') + '(?=$|[^A-Za-z0-9])'
    return $Evidence -match "(?i)$Pattern"
}
function Get-DevRecipePreflightActionKey { param($Entry) return "$($Entry.Type)|$($Entry.Provider)|$($Entry.Name)|$($Entry.Version)" }
function Test-DevRecipePreflightExcluded { param($Entry) return $script:DevRecipePreflightExcludedIds -contains (Get-DevRecipePreflightActionKey -Entry $Entry) }
function Get-DevRecipePreflightEvidencePriority { param([string]$Source) if ($Source -like "selected-provider-inventory*") { return 1 }; if ($Source -like "os-installation-record*" -or $Source -like "os-registration*") { return 2 }; if ($Source -like "os-location-metadata*" -or $Source -like "os-launcher-record*") { return 3 }; return 4 }
function Start-DevRecipePreflightEvidenceCollection { $script:DevRecipePreflightEvidence = @() }
function Complete-DevRecipePreflightEvidenceCollection {
    if ($script:DevRecipePreflightEvidence.Count -gt 0) {
        Write-Host "Traces found for '$($script:DevRecipePreflightEvidence[0].Query)':" -ForegroundColor Yellow
    }
    $script:DevRecipePreflightEvidence | Sort-Object Priority, @{ Expression = { $_.Score }; Descending = $true }, Source, Location | Select-Object -First $script:DevRecipePreflightMaxEvidence | ForEach-Object { Write-Host "  evidence | query=$($_.Query) | source=$($_.Source) | scope=$($_.Scope) | location=$($_.Location) | matched=$($_.Value) | reason=$($_.Reason) | similarity=$($_.Score)/100 | threshold=$($script:DevRecipePreflightThreshold)/100" }
}
function Write-DevRecipePreflightEvidence {
    param([string]$Query, [string]$Source, [string]$Scope, [string]$Location, [string]$Value)
    $Score = Get-DevRecipePreflightScore -Query $Query -Evidence $Value
    $Reason = if ($Score -eq 100) { "case-insensitive exact match" } elseif ($Score -ge $script:DevRecipePreflightThreshold) { "case-insensitive similarity at or above threshold" } else { $null }
    if ($null -eq $Reason -and (Test-DevRecipePreflightSeparatorPrefix -Query $Query -Evidence $Value)) {
        $Score = 100
        $Reason = "generated separator-flexible prefix match"
    }
    if ($null -eq $Reason) { return $false }
    $script:DevRecipePreflightEvidence += [PSCustomObject]@{ Priority = Get-DevRecipePreflightEvidencePriority -Source $Source; Query = $Query; Source = $Source; Scope = $Scope; Location = $Location; Value = $Value; Reason = $Reason; Score = $Score }; return $true
}
function Write-DevRecipePreflightIncomplete {
    param([string]$Query, [string]$Source, [string]$Scope, [string]$Reason)

    $Record = "$Source|$Scope|$Reason"
    if ($script:DevRecipePreflightIncompleteChecks -notcontains $Record) {
        $script:DevRecipePreflightIncompleteChecks += $Record
    }
}
function Test-DevRecipeWindowsHost { return [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT }
function Find-DevRecipeWindowsRegistryEvidence {
    param([string]$Query); $Found = $false
    foreach ($Path in @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")) {
        try { foreach ($Item in @(Get-ItemProperty -Path $Path -ErrorAction Stop)) { if ([string]::IsNullOrWhiteSpace([string]$Item.DisplayName)) { continue }; $Scope = if ($Path.StartsWith("HKCU:")) { "user" } else { "machine" }; $Location = $Item.PSPath -replace '^Microsoft\.PowerShell\.Core\\Registry::', ''; if (Write-DevRecipePreflightEvidence -Query $Query -Source "os-installation-record:registry" -Scope $Scope -Location $Location -Value ([string]$Item.DisplayName)) { $Found = $true } } } catch { Write-DevRecipePreflightIncomplete -Query $Query -Source "os-installation-record:registry" -Scope "unknown" -Reason "registry view unavailable" }
    }; return $Found
}
function Find-DevRecipeWindowsPathEvidence {
    param([string]$Query)

    $Command = Get-Command -Name $Query -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $Command -or [string]::IsNullOrWhiteSpace([string]$Command.Path)) { return $false }
    return Write-DevRecipePreflightEvidence -Query $Query -Source "os-path-application" -Scope "process" -Location ([string]$Command.Path) -Value ([IO.Path]::GetFileNameWithoutExtension([string]$Command.Path))
}
function Find-DevRecipeWindowsAppPathEvidence {
    param([string]$Query); $Found = $false
    foreach ($Path in @("HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\*", "HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\*", "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\*")) {
        try { foreach ($Item in @(Get-Item -Path $Path -ErrorAction Stop)) { $Scope = if ($Path.StartsWith("HKCU:")) { "user" } else { "machine" }; $Location = $Item.PSPath -replace '^Microsoft\.PowerShell\.Core\\Registry::', ''; if (Write-DevRecipePreflightEvidence -Query $Query -Source "os-launcher-record:app-paths" -Scope $Scope -Location $Location -Value $Item.PSChildName) { $Found = $true } } } catch { Write-DevRecipePreflightIncomplete -Query $Query -Source "os-launcher-record:app-paths" -Scope "unknown" -Reason "App Paths registry view unavailable" }
    }; return $Found
}
function Initialize-DevRecipeWindowsFilesystemCache {
    param([object[]]$Entries)
    if ($script:DevRecipePreflightFilesystemCache.Count -gt 0 -or -not (Test-DevRecipeWindowsHost)) { return }; $Prefixes = @($Entries | ForEach-Object { $_.Name.Substring(0, 1) } | Select-Object -Unique); if ($Prefixes.Count -eq 0) { return }
    $Roots = @(@{ Path = $env:ProgramFiles; Scope = "machine"; Label = "ProgramFiles" }, @{ Path = ${env:ProgramFiles(x86)}; Scope = "machine"; Label = "ProgramFilesX86" }, @{ Path = $env:ProgramData; Scope = "machine"; Label = "ProgramData" }, @{ Path = $env:LOCALAPPDATA; Scope = "user"; Label = "LocalAppData" }, @{ Path = $env:APPDATA; Scope = "user"; Label = "AppData" }, @{ Path = (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"); Scope = "user"; Label = "UserStartMenu" }, @{ Path = (Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs"); Scope = "machine"; Label = "MachineStartMenu" })
    $PrefixList = $Prefixes -join [char]0; $Jobs = foreach ($Root in $Roots) { Start-Job -ScriptBlock { param($Path, $Scope, $Label, [string]$PrefixList); $Prefixes = $PrefixList -split [char]0; if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Container)) { return }; try { $Candidates = @(Get-ChildItem -LiteralPath $Path -Force -Recurse -Depth 3 -ErrorAction Stop | Where-Object { $CandidateName = $_.Name; -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -and @($Prefixes | Where-Object { $_ -and $CandidateName.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0 } | Select-Object -First 2000); foreach ($Candidate in $Candidates) { [PSCustomObject]@{ Scope = $Scope; Label = $Label; Relative = $Candidate.FullName.Substring($Path.Length).TrimStart('\'); Name = $Candidate.Name; Incomplete = $null } }; if ($Candidates.Count -eq 2000) { [PSCustomObject]@{ Scope = $Scope; Label = $Label; Relative = $null; Name = $null; Incomplete = "scan limit reached" } } } catch { [PSCustomObject]@{ Scope = $Scope; Label = $Label; Relative = $null; Name = $null; Incomplete = "root inaccessible or partial scan" } } } -ArgumentList $Root.Path, $Root.Scope, $Root.Label, $PrefixList }
    foreach ($Job in $Jobs) { try { $script:DevRecipePreflightFilesystemCache += @(Receive-Job -Job $Job -Wait -ErrorAction Stop) } catch { $script:DevRecipePreflightFilesystemCache += [PSCustomObject]@{ Scope = "unknown"; Label = "filesystem-worker"; Relative = $null; Name = $null; Incomplete = "filesystem worker unavailable" } } finally { Remove-Job -Job $Job -Force -ErrorAction SilentlyContinue } }
}
function Show-DevRecipeWindowsFilesystemCoverage {
    $FilesystemChecks = @($script:DevRecipePreflightFilesystemCache | Where-Object { $null -ne $_.Incomplete })
    if ($FilesystemChecks.Count -eq 0 -and $script:DevRecipePreflightIncompleteChecks.Count -eq 0) { return }

    Write-Host "`n--- PREFLIGHT COVERAGE NOTE (read-only) ---" -ForegroundColor DarkYellow
    if ($FilesystemChecks.Count -gt 0) {
        $Scopes = @($FilesystemChecks | ForEach-Object { $_.Scope } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
        $ScopeText = if ($Scopes.Count -gt 0) { $Scopes -join "," } else { "unknown" }
        Write-Host "  coverage | source=os-location-metadata | scopes=$ScopeText | incomplete-checks=$($FilesystemChecks.Count) | note=some approved filesystem metadata checks were incomplete; no action is required unless matching evidence is shown"
    }
    foreach ($Record in $script:DevRecipePreflightIncompleteChecks) {
        $Source, $Scope, $Reason = $Record -split '\|', 3
        Write-Host "  coverage | source=$Source | scope=$Scope | note=$Reason; no action is required unless matching evidence is shown"
    }
}
function Find-DevRecipeWindowsFilesystemEvidence { param([string]$Query); $Found = $false; $Prefix = $Query.Substring(0, 1); foreach ($Candidate in $script:DevRecipePreflightFilesystemCache) { if ($null -eq $Candidate.Incomplete -and -not [string]::IsNullOrWhiteSpace($Candidate.Name) -and $Candidate.Name.StartsWith($Prefix, [StringComparison]::OrdinalIgnoreCase)) { if (Write-DevRecipePreflightEvidence -Query $Query -Source "os-location-metadata" -Scope $Candidate.Scope -Location "<$($Candidate.Label)>\$($Candidate.Relative)" -Value $Candidate.Name) { $Found = $true } } }; return $Found }
function Find-DevRecipeWindowsOsMetadataEvidence {
    param([string]$Query); if (-not (Test-DevRecipeWindowsHost)) { return $false }; $Found = Find-DevRecipeWindowsRegistryEvidence -Query $Query; if (Find-DevRecipeWindowsPathEvidence -Query $Query) { $Found = $true }; if (Find-DevRecipeWindowsAppPathEvidence -Query $Query) { $Found = $true }
    try { foreach ($Package in @(Get-AppxPackage -ErrorAction Stop)) { $Location = if ([string]::IsNullOrWhiteSpace([string]$Package.InstallLocation)) { "AppX registration: $($Package.PackageFullName)" } else { [string]$Package.InstallLocation }; if (Write-DevRecipePreflightEvidence -Query $Query -Source "os-registration:appx" -Scope "user" -Location $Location -Value $Package.Name) { $Found = $true } } } catch { Write-DevRecipePreflightIncomplete -Query $Query -Source "os-registration:appx" -Scope "user" -Reason "AppX installed-package registration query failed" }
    if (Find-DevRecipeWindowsFilesystemEvidence -Query $Query) { $Found = $true }
    try { foreach ($Service in @(Get-CimInstance Win32_Service -ErrorAction Stop)) { if (Write-DevRecipePreflightEvidence -Query $Query -Source "os-service-metadata" -Scope "machine" -Location "<service>" -Value ([string]$Service.Name)) { $Found = $true } } } catch { Write-DevRecipePreflightIncomplete -Query $Query -Source "os-service-metadata" -Scope "machine" -Reason "service inventory unavailable" }
    try { foreach ($Task in @(Get-ScheduledTask -ErrorAction Stop)) { if (Write-DevRecipePreflightEvidence -Query $Query -Source "os-task-metadata" -Scope "machine" -Location "<scheduled-task>" -Value ([string]$Task.TaskName)) { $Found = $true } } } catch { Write-DevRecipePreflightIncomplete -Query $Query -Source "os-task-metadata" -Scope "machine" -Reason "task inventory unavailable" }; return $Found
}
function Test-DevRecipeInteractiveTerminal { return [Environment]::UserInteractive -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected }
function Invoke-DevRecipe-Review { if (-not (Test-DevRecipeInteractiveTerminal)) { [Console]::Error.WriteLine("Review requires an interactive TTY; no mutation was attempted."); exit 3 }; Write-Host "`n--- INTERACTIVE REVIEW ---" -ForegroundColor Cyan }
function Complete-DevRecipeReview { if (-not $Review) { return }; if ($null -ne $script:DevRecipeReviewPending) { $script:DevRecipeReviewCompleted += $script:DevRecipeReviewPending; $script:DevRecipeReviewPending = $null }; Write-Host "`n--- REVIEW REPORT ---"; Write-Host "approved: $($script:DevRecipeReviewApproved.Count)"; Write-Host "completed: $($script:DevRecipeReviewCompleted.Count)"; Write-Host "rejected: $($script:DevRecipeReviewRejected.Count)"; Write-Host "unreviewed: $($script:DevRecipeReviewUnreviewed.Count)"; if ($script:DevRecipeReviewUnreviewed.Count -gt 0) { Write-Host "unreviewed detail: $($script:DevRecipeReviewUnreviewed -join '; ')" } }
function Confirm-DevRecipeReviewAction {
    param([string]$Command, [string]$Privilege, [string]$Source, [string]$Effect)
    if (-not $Review) { return }; if ($null -ne $script:DevRecipeReviewPending) { $script:DevRecipeReviewCompleted += $script:DevRecipeReviewPending; $script:DevRecipeReviewPending = $null }; if (-not (Test-DevRecipeInteractiveTerminal)) { $script:DevRecipeReviewUnreviewed += $Command; [Console]::Error.WriteLine("Review requires an interactive TTY; action remains unreviewed: $Command"); Complete-DevRecipeReview; exit 3 }
    $script:DevRecipeReviewActionNumber++; Write-Host "`n--- REVIEW ACTION $($script:DevRecipeReviewActionNumber) ---"; Write-Host "command: $Command"; Write-Host "privilege: $Privilege"; Write-Host "source/target: $Source"; Write-Host "effect: $Effect"
    if ($script:DevRecipeReviewApproveAll) { Write-Host "approval: all remaining review actions" } else { $Answer = Read-Host "Approve this exact action? [y/N/A=all remaining]"; if ($Answer -ceq "A") { $script:DevRecipeReviewApproveAll = $true; Write-Host "approval: all remaining review actions" } elseif ($Answer -notin @("y", "Y", "yes", "Yes", "YES")) { $script:DevRecipeReviewRejected += "$($script:DevRecipeReviewActionNumber):$Command"; $script:DevRecipeReviewUnreviewed += "actions after rejected checkpoint $($script:DevRecipeReviewActionNumber)"; [Console]::Error.WriteLine("Review rejected action $($script:DevRecipeReviewActionNumber); remaining actions are unreviewed."); Complete-DevRecipeReview; exit 3 } }
    $script:DevRecipeReviewApproved += "$($script:DevRecipeReviewActionNumber):$Command"; $script:DevRecipeReviewPending = "$($script:DevRecipeReviewActionNumber):$Command"
}
function Get-DevRecipePreflightViewport {
    param([int]$EntryCount, [int]$WindowHeight)

    $HeaderRows = 4
    $MenuChromeRows = 3
    $MinimumVisibleRows = 3
    $AvailableListRows = $WindowHeight - $HeaderRows - $MenuChromeRows
    if ($EntryCount -le 0 -or $AvailableListRows -lt $MinimumVisibleRows) { return $null }
    return [PSCustomObject]@{
        VisibleRows = [Math]::Min($EntryCount, $AvailableListRows)
        MenuLines = [Math]::Min($EntryCount, $AvailableListRows) + $MenuChromeRows
    }
}
function Invoke-NativeMultiSelect {
    param([object[]]$Entries)

    if ($Entries.Count -eq 0 -or [Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return $null }
    try {
        $WindowHeight = [Console]::WindowHeight
        $WindowWidth = [Console]::WindowWidth
        if ($WindowWidth -lt 24) { return $null }
        $Viewport = Get-DevRecipePreflightViewport -EntryCount $Entries.Count -WindowHeight $WindowHeight
        if ($null -eq $Viewport) { return $null }

        $Selected = [bool[]]::new($Entries.Count)
        $Current = 0
        $FirstVisible = 0
        $ListFocused = $true
        $Button = 0
        $VisibleRows = $Viewport.VisibleRows
        $MenuLines = $Viewport.MenuLines
        $RenderWidth = $WindowWidth - 1
        $PreviousCursorVisible = [Console]::CursorVisible
        Write-Host "`n--- PREFLIGHT CONFLICT SELECTION ---" -ForegroundColor Cyan
        Write-Host "Check exact declared entries to force; unchecked entries are declined."
        Write-Host "Up/Down: move/scroll | Space: toggle | A: all | Left/Right or Tab: buttons | Enter: confirm | Escape: cancel"
        foreach ($Ignored in 1..$MenuLines) { [Console]::WriteLine("") }
        $Top = [Math]::Max(0, [Console]::CursorTop - $MenuLines)

        try {
            [Console]::CursorVisible = $false
            while ($true) {
                if ($Current -lt $FirstVisible) {
                    $FirstVisible = $Current
                } elseif ($Current -ge ($FirstVisible + $VisibleRows)) {
                    $FirstVisible = $Current - $VisibleRows + 1
                }
                $FirstVisible = [Math]::Min([Math]::Max(0, $Entries.Count - $VisibleRows), $FirstVisible)

                $Menu = @()
                $Menu += if ($FirstVisible -gt 0) { "  ^ $FirstVisible more above" } else { "" }
                for ($Row = 0; $Row -lt $VisibleRows; $Row++) {
                    $Index = $FirstVisible + $Row
                    $Entry = $Entries[$Index]
                    $Marker = if ($Selected[$Index]) { "x" } else { " " }
                    $Pointer = if ($ListFocused -and $Index -eq $Current) { ">" } else { " " }
                    $Menu += "$Pointer [$Marker] $($Entry.Type) | $($Entry.Provider) | $($Entry.Name) | $($Entry.Version)"
                }
                $Below = $Entries.Count - ($FirstVisible + $VisibleRows)
                $Menu += if ($Below -gt 0) { "  v $Below more below" } else { "" }
                $CheckedCount = @($Selected | Where-Object { $_ }).Count
                $ForceButton = "[ Force selected ($CheckedCount) ]"
                $CancelButton = "[ Cancel ]"
                if ($ListFocused) {
                    $Menu += "  $ForceButton  $CancelButton"
                } elseif ($Button -eq 0) {
                    $Menu += "> $ForceButton  $CancelButton"
                } else {
                    $Menu += "  $ForceButton  > $CancelButton"
                }

                for ($LineIndex = 0; $LineIndex -lt $Menu.Count; $LineIndex++) {
                    $Line = [string]$Menu[$LineIndex]
                    if ($Line.Length -gt $RenderWidth) {
                        $Line = if ($RenderWidth -gt 3) { $Line.Substring(0, $RenderWidth - 3) + "..." } else { $Line.Substring(0, $RenderWidth) }
                    }
                    [Console]::SetCursorPosition(0, $Top + $LineIndex)
                    [Console]::Write($Line.PadRight([Console]::WindowWidth - 1))
                }
                $Key = [Console]::ReadKey($true)
                switch ($Key.Key) {
                    "UpArrow" { if ($ListFocused) { if ($Current -gt 0) { $Current-- } } else { $ListFocused = $true } }
                    "DownArrow" { if ($ListFocused) { if ($Current -lt ($Entries.Count - 1)) { $Current++ } else { $ListFocused = $false; $Button = 0 } } }
                    "LeftArrow" { if (-not $ListFocused) { $Button = 0 } }
                    "RightArrow" { if (-not $ListFocused) { $Button = 1 } }
                    "Tab" { if ($ListFocused) { $ListFocused = $false; $Button = 0 } else { $Button = 1 - $Button } }
                    "Spacebar" {
                        if ($ListFocused) { $Selected[$Current] = -not $Selected[$Current] }
                        elseif ($Button -eq 0) { return [PSCustomObject]@{ Cancelled = $false; Selected = $Selected } }
                        else { return [PSCustomObject]@{ Cancelled = $true; Selected = [bool[]]::new($Entries.Count) } }
                    }
                    "A" { $SetAll = $Selected -contains $false; for ($Index = 0; $Index -lt $Selected.Count; $Index++) { $Selected[$Index] = $SetAll } }
                    "Enter" { if ($ListFocused -or $Button -eq 0) { return [PSCustomObject]@{ Cancelled = $false; Selected = $Selected } }; return [PSCustomObject]@{ Cancelled = $true; Selected = [bool[]]::new($Entries.Count) } }
                    "Escape" { return [PSCustomObject]@{ Cancelled = $true; Selected = [bool[]]::new($Entries.Count) } }
                }
            }
        } finally {
            [Console]::CursorVisible = $PreviousCursorVisible
            [Console]::SetCursorPosition(0, [Math]::Min([Console]::BufferHeight - 1, $Top + $MenuLines))
            [Console]::WriteLine()
        }
    } catch {
        return $null
    }
}
function Show-DevRecipePreflightProviderMatches {
    if ($script:DevRecipePreflightProviderMatches.Count -eq 0) { return }
    Write-Host "`n--- PREFLIGHT PROVIDER-MANAGED STATE (no action required) ---" -ForegroundColor Green
    foreach ($Match in $script:DevRecipePreflightProviderMatches) {
        Write-Host "  provider-managed | provider=$($Match.Provider) | application=$($Match.Application) | declared-version=$($Match.DeclaredVersion) | installed-version=$($Match.InstalledVersion) | version-match=$($Match.VersionMatch) | decision=skip-no-action"
    }
    Write-Host "Provider inventory matches are reusable installed state; they do not prove historical DevRecipe provenance."
}

function Invoke-DevRecipePreflight {
    param([object[]]$Entries)
    $script:DevRecipePreflightExcludedIds = @(); $script:DevRecipePreflightProviderMatches = @(); $script:DevRecipePreflightApproveAll = $false; $script:DevRecipePreflightDeclineAll = $false; $script:DevRecipePreflightIncompleteChecks = @(); $ScoopEntries = @($Entries | Where-Object { $_.Type -eq "packages" }); $ScoopInventory = if ($ScoopEntries.Count -gt 0) { Get-ScoopInventory } else { [PSCustomObject]@{ State = "not-needed"; PackageIds = @(); Packages = @() } }; $MiseEntries = @($Entries | Where-Object { $_.Type -ne "packages" }); $MiseInventory = if ($MiseEntries.Count -gt 0) { Get-MiseInventory } else { [PSCustomObject]@{ State = "not-needed"; Records = @() } }; $Conflicts = @()
    Write-Host "`n--- PREFLIGHT CONFLICT EVIDENCE (read-only) ---" -ForegroundColor Cyan
    Write-Host "Scanning requested tools and checking your system for existing traces to prevent installation conflicts."
    Write-Host "threshold=$($script:DevRecipePreflightThreshold)/100; name similarity indicates potential collisions, not ownership."
    Initialize-DevRecipeWindowsFilesystemCache -Entries $Entries
    foreach ($Entry in $Entries) {
        $Query = $Entry.Name
        $ProviderMatch = if ($Entry.Type -eq "packages") { Get-ScoopEntryMatch -Inventory $ScoopInventory -Entry $Entry } else { Get-MiseEntryMatch -Inventory $MiseInventory -Entry $Entry }
        if ($ProviderMatch.Status -eq "installed") {
            $script:DevRecipePreflightProviderMatches += [PSCustomObject]@{
                Provider = Get-ProviderLabel -Entry $Entry
                Application = $Entry.Name
                DeclaredVersion = $Entry.Version
                InstalledVersion = if ([string]::IsNullOrWhiteSpace([string]$ProviderMatch.InstalledVersion)) { "unreported" } else { $ProviderMatch.InstalledVersion }
                VersionMatch = $ProviderMatch.VersionMatch
            }
            $script:DevRecipePreflightExcludedIds += (Get-DevRecipePreflightActionKey -Entry $Entry)
            continue
        }
        Start-DevRecipePreflightEvidenceCollection
        Write-Host "`n--- PREFLIGHT CHECK: $Query ---" -ForegroundColor DarkCyan
        $Conflict = $false
        if ($Entry.Type -eq "packages" -and $ScoopInventory.State -ne "ready") {
            Write-DevRecipePreflightIncomplete -Query $Query -Source "Scoop installed-app inventory" -Scope "user" -Reason "not available before Scoop bootstrap or when scoop export fails"
        } elseif ($Entry.Type -ne "packages" -and $MiseInventory.State -ne "ready") {
            Write-DevRecipePreflightIncomplete -Query $Query -Source "Mise installed-tool inventory" -Scope "user" -Reason "not available before Mise installation or when mise ls --installed --json fails"
        }
        if ($ProviderMatch.Status -in @("mismatch", "version-unavailable")) {
            $Conflict = $true
            Write-Host "  provider-conflict | provider=$(Get-ProviderLabel -Entry $Entry) | application=$($Entry.Name) | declared-version=$($Entry.Version) | installed-version=$($ProviderMatch.InstalledVersion) | reason=provider-version-mismatch" -ForegroundColor DarkYellow
        }
        if (Find-DevRecipeWindowsOsMetadataEvidence -Query $Query) { $Conflict = $true }
        Complete-DevRecipePreflightEvidenceCollection
        if ($Conflict) { $Conflicts += $Entry }
    }
    Show-DevRecipePreflightProviderMatches
    Show-DevRecipeWindowsFilesystemCoverage
    if ($Conflicts.Count -eq 0) { return [PSCustomObject]@{ ExitCode = 0; ExcludedIds = @() } }
    if ($Force -is [System.Management.Automation.SwitchParameter] -and $Force.IsPresent) {
        foreach ($Entry in $Conflicts) {
            Write-Host "  decision=force (pre-approved via -Force) | application=$($Entry.Name)"
        }
        return [PSCustomObject]@{ ExitCode = 0; ExcludedIds = @() }
    }
    if (-not (Test-DevRecipeInteractiveTerminal)) { [Console]::Error.WriteLine("Preflight needs human decisions; no mutation was attempted."); return [PSCustomObject]@{ ExitCode = 3; ExcludedIds = @() } }
    $Selection = Invoke-NativeMultiSelect -Entries $Conflicts
    if ($null -ne $Selection) {
        for ($Index = 0; $Index -lt $Conflicts.Count; $Index++) {
            $Entry = $Conflicts[$Index]
            if (-not $Selection.Cancelled -and $Selection.Selected[$Index]) { Write-Host "  decision=force | application=$($Entry.Name)"; continue }
            $script:DevRecipePreflightExcludedIds += (Get-DevRecipePreflightActionKey -Entry $Entry)
            Write-Host "  decision=decline | application=$($Entry.Name)"
        }
        return [PSCustomObject]@{ ExitCode = 0; ExcludedIds = @($script:DevRecipePreflightExcludedIds) }
    }
    foreach ($Entry in $Conflicts) { if ($script:DevRecipePreflightApproveAll) { Write-Host "  decision=force-all | application=$($Entry.Name)"; continue }; if ($script:DevRecipePreflightDeclineAll) { $script:DevRecipePreflightExcludedIds += (Get-DevRecipePreflightActionKey -Entry $Entry); Write-Host "  decision=decline-all | application=$($Entry.Name)"; continue }; $Answer = Read-Host "Force exact declared installation for '$($Entry.Name)'? [y/N/A=all yes/D=all no]"; if ($Answer -ceq "A" -or $Answer -ieq "all yes") { $script:DevRecipePreflightApproveAll = $true; Write-Host "  decision=force-all | application=$($Entry.Name)" } elseif ($Answer -ceq "D" -or $Answer -ieq "all no") { $script:DevRecipePreflightDeclineAll = $true; $script:DevRecipePreflightExcludedIds += (Get-DevRecipePreflightActionKey -Entry $Entry); Write-Host "  decision=decline-all | application=$($Entry.Name)" } elseif ($Answer -notin @("y", "Y", "yes", "Yes", "YES")) { $script:DevRecipePreflightExcludedIds += (Get-DevRecipePreflightActionKey -Entry $Entry); Write-Host "  decision=decline | application=$($Entry.Name)" } else { Write-Host "  decision=force | application=$($Entry.Name)" } }
    return [PSCustomObject]@{ ExitCode = 0; ExcludedIds = @($script:DevRecipePreflightExcludedIds) }
}
# End private runtime helpers.

function Stop-Usage {
    param([string]$Message)

    [Console]::Error.WriteLine($Message)
    [Console]::Error.WriteLine("Usage : .\DevRecipe_windows.ps1 [-Profile ai-agents,cloud] [-Force] [-SkipPreflight] [-Review] [-Validate|-List|-Status|-DryRun|-Uninstall id[,id]] [-Yes|-y] [-Containers [-ContainerProvider Auto|WSL|HyperV] [-DockerAlias]]")
    exit 2
}

function Resolve-Profiles {
    param([string[]]$Requested)

    $KnownProfiles = @("default", "ai_agents", "cloud")
    $SelectedProfiles = @("default")
    foreach ($Value in @($Requested)) {
        foreach ($Candidate in ($Value -split ',')) {
            $ProfileName = $Candidate.Trim().ToLowerInvariant().Replace("-", "_")
            if ([string]::IsNullOrWhiteSpace($ProfileName)) { continue }
            if ($ProfileName -notin $KnownProfiles) {
                Stop-Usage "Unknown profile '$Candidate'. Available profiles: default, ai-agents, cloud."
            }
            if ($ProfileName -notin $SelectedProfiles) {
                $SelectedProfiles += $ProfileName
            }
        }
    }
    return @($SelectedProfiles)
}

function Add-ManifestValidationError {
    param(
        [System.Collections.Generic.List[string]]$Errors,
        [int]$LineNumber,
        [string]$Path,
        [string]$Message
    )

    $Location = if ($LineNumber -gt 0) { "line $LineNumber" } else { "end of file" }
    [void]$Errors.Add("  - $Location, $Path : $Message")
}

function Test-DevRecipeManifest {
    param([string]$ManifestPath)

    $Errors = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        Add-ManifestValidationError -Errors $Errors -LineNumber 0 -Path "manifest" -Message "file not found: $ManifestPath"
    } else {
        try {
            $Lines = @(Get-Content -LiteralPath $ManifestPath -ErrorAction Stop)
        } catch {
            Add-ManifestValidationError -Errors $Errors -LineNumber 0 -Path "manifest" -Message "file is inaccessible: $($_.Exception.Message)"
            $Lines = @()
        }
    }

    if ($Errors.Count -eq 0) {
        $KnownProfiles = @("default", "ai_agents", "cloud")
        $SeenSections = @{}
        $SeenKeys = @{}
        $ProfileSeen = @{}
        $ProfileDescriptions = @{}
        $ProfileUsed = @{}
        $EntryCounts = @{}
        $MetadataSeen = $false
        $SchemaDeclared = $false
        $CurrentKind = $null
        $CurrentSection = $null
        $CurrentProfile = $null
        $CurrentType = $null
        $CurrentProvider = $null
        $CurrentCategory = $null

        for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
            $LineNumber = $Index + 1
            $Line = (($Lines[$Index] -replace '\s+#.*$', '').Trim())
            if ([string]::IsNullOrWhiteSpace($Line) -or $Line.StartsWith('#')) { continue }

            if ($Line.StartsWith("[")) {
                $CurrentKind = $null
                $CurrentSection = $null
                if ($Line -notmatch '^\[(?<section>[^\]]+)\]$') {
                    Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path "section" -Message "invalid TOML header"
                    continue
                }

                $Section = $Matches["section"]
                $Parts = @($Section -split '\.')
                $ValidSection = $Parts.Count -gt 0
                foreach ($Part in $Parts) {
                    if ($Part -notmatch '^[A-Za-z0-9_-]+$') { $ValidSection = $false }
                }
                if (-not $ValidSection) {
                    Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path "section.$Section" -Message "invalid section segment"
                    continue
                }
                if ($SeenSections.ContainsKey($Section)) {
                    Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path "section.$Section" -Message "section declared more than once"
                }
                $SeenSections[$Section] = $true

                if ($Section -eq "metadata") {
                    $MetadataSeen = $true
                    $CurrentKind = "metadata"
                    $CurrentSection = $Section
                    continue
                }
                if ($Section -eq "buckets") {
                    $CurrentKind = "buckets"
                    $CurrentSection = $Section
                    continue
                }
                if ($Parts.Count -eq 2 -and $Parts[0] -eq "profiles") {
                    $CurrentKind = "profile"
                    $CurrentSection = $Section
                    $CurrentProfile = $Parts[1]
                    $ProfileSeen[$CurrentProfile] = $true
                    if ($CurrentProfile -notin $KnownProfiles) {
                        Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path "profiles.$CurrentProfile" -Message "unsupported profile; accepted values: default, ai_agents, cloud"
                    }
                    continue
                }
                if ($Parts.Count -eq 4 -and $Parts[0] -in @("packages", "runtimes", "tools", "containers")) {
                    $CurrentKind = "entry"
                    $CurrentSection = $Section
                    $CurrentType = $Parts[0]
                    $CurrentProfile = $Parts[1]
                    $CurrentProvider = $Parts[2]
                    $CurrentCategory = $Parts[3]
                    $ProfileUsed[$CurrentProfile] = $true
                    $EntryCounts[$CurrentSection] = 0

                    if ($CurrentProfile -notin $KnownProfiles) {
                        Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path "$CurrentType.$CurrentProfile" -Message "unsupported profile; accepted values: default, ai_agents, cloud"
                    }
                    if ($CurrentType -eq "packages" -and $CurrentProvider -ne "os") {
                        Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path $CurrentSection -Message "unsupported provider for Windows; accepted value: os"
                    }
                    if ($CurrentType -in @("runtimes", "tools") -and $CurrentProvider -ne "mise") {
                        Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path $CurrentSection -Message "unsupported provider; accepted value: mise"
                    }
                    if ($CurrentType -eq "containers" -and $CurrentProvider -ne "os") {
                        Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path $CurrentSection -Message "unsupported provider; accepted value: os"
                    }
                    continue
                }

                Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path "section.$Section" -Message "unknown section or invalid TOML level"
                continue
            }

            if ($null -eq $CurrentKind) {
                Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path "syntax" -Message "entry outside a recognised section"
                continue
            }
            if ($Line -notmatch '^(?<key>[^=]+?)\s*=\s*(?<value>.+)$') {
                Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path $CurrentSection -Message "invalid entry; use identifier = value"
                continue
            }

            $KeyToken = $Matches["key"].Trim()
            $Value = $Matches["value"].Trim()
            if ($KeyToken -match '^"(?<quoted>[^"]+)"$') {
                $Key = $Matches["quoted"]
            } elseif ($KeyToken -match '^[A-Za-z0-9_-]+$') {
                $Key = $KeyToken
            } else {
                Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path $CurrentSection -Message "invalid key identifier"
                continue
            }
            $KeyIdentity = "$CurrentSection$([char]31)$Key"
            if ($SeenKeys.ContainsKey($KeyIdentity)) {
                Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path "$CurrentSection.$Key" -Message "key declared more than once"
                continue
            }
            $SeenKeys[$KeyIdentity] = $true

            if ($CurrentKind -eq "metadata") {
                if ($Key -ne "schema_version" -or $Value -ne "2") {
                    Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path "metadata.$Key" -Message "use schema_version = 2"
                } else {
                    $SchemaDeclared = $true
                }
                continue
            }
            if ($CurrentKind -eq "buckets") {
                if ($Value -notmatch '^"(?<url>[^"]*)"$') {
                    Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path "buckets.$Key" -Message "bucket value must be a string (empty for official, URL for custom)"
                }
                continue
            }
            if ($CurrentKind -eq "profile") {
                if ($Key -ne "description" -or $Value -notmatch '^"(?<description>[^"]*)"$' -or [string]::IsNullOrWhiteSpace($Matches["description"])) {
                    Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path "profiles.$CurrentProfile" -Message "text description is required"
                } else {
                    $ProfileDescriptions[$CurrentProfile] = $true
                }
                continue
            }

            $EntryCounts[$CurrentSection] = [int]$EntryCounts[$CurrentSection] + 1
            if ([string]::IsNullOrWhiteSpace($Key) -or $Key -match '\s') {
                Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path $CurrentSection -Message "invalid package identifier"
                continue
            }
            if ($Value -notmatch '^"(?<version>[^"]*)"$') {
                Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path "$CurrentSection.$Key" -Message "version must be a TOML string"
                continue
            }
            $Version = $Matches["version"]
            if ($Version -eq "" -and -not ($CurrentType -eq "runtimes" -and $CurrentCategory -eq "optional")) {
                Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path "$CurrentSection.$Key" -Message "empty version is reserved for runtimes in the optional category"
            } elseif ($Version -ne $Version.Trim()) {
                Add-ManifestValidationError -Errors $Errors -LineNumber $LineNumber -Path "$CurrentSection.$Key" -Message "version must not contain leading or trailing spaces"
            }
        }

        if (-not $MetadataSeen) {
            Add-ManifestValidationError -Errors $Errors -LineNumber 0 -Path "metadata" -Message "[metadata] table is required"
        }
        if ($MetadataSeen -and -not $SchemaDeclared) {
            Add-ManifestValidationError -Errors $Errors -LineNumber 0 -Path "metadata.schema_version" -Message "required key missing; use schema_version = 2"
        }
        if (-not $ProfileSeen.ContainsKey("default")) {
            Add-ManifestValidationError -Errors $Errors -LineNumber 0 -Path "profiles.default" -Message "required profile is missing"
        }
        foreach ($ProfileName in $ProfileSeen.Keys) {
            if ($ProfileName -in $KnownProfiles -and -not $ProfileDescriptions.ContainsKey($ProfileName)) {
                Add-ManifestValidationError -Errors $Errors -LineNumber 0 -Path "profiles.$ProfileName" -Message "text description is required"
            }
        }
        foreach ($ProfileName in $ProfileUsed.Keys) {
            if ($ProfileName -in $KnownProfiles -and -not $ProfileSeen.ContainsKey($ProfileName)) {
                Add-ManifestValidationError -Errors $Errors -LineNumber 0 -Path "profiles.$ProfileName" -Message "profile is used but not declared"
            }
        }
        foreach ($Section in $EntryCounts.Keys) {
            if ($EntryCounts[$Section] -eq 0 -and $Section -notmatch '^runtimes\.[^.]+\.mise\.optional$') {
                Add-ManifestValidationError -Errors $Errors -LineNumber 0 -Path $Section -Message "must contain at least one entry"
            }
        }
    }

    if ($Errors.Count -gt 0) {
        [Console]::Error.WriteLine("Invalid DevRecipe manifest: $ManifestPath")
        foreach ($ValidationError in $Errors) {
            [Console]::Error.WriteLine($ValidationError)
        }
        [Console]::Error.WriteLine("Action: correct the reported entries, then run the recipe again.")
        [Console]::Error.WriteLine("No changes were made.")
        return $false
    }
    return $true
}

function Get-TomlManifestBuckets {
    param([string]$Toml)

    $Buckets = @()
    $InBucketsSection = $false
    foreach ($RawLine in ($Toml -split "\r?\n")) {
        $Line = $RawLine -replace '\s+#.*$', ''
        if ($Line -match '^\s*\[(?<section>[^\]]+)\]\s*$') {
            $InBucketsSection = ($Matches["section"].Trim() -eq "buckets")
            continue
        }
        if ($InBucketsSection -and $Line -match '^\s*(?:"(?<quoted>[^"]+)"|(?<bare>[^=\s]+))\s*=\s*"(?<url>[^"]*)"\s*$') {
            $Name = if ($Matches["quoted"]) { $Matches["quoted"] } else { $Matches["bare"] }
            $Buckets += [PSCustomObject]@{
                Name = $Name
                Url = $Matches["url"]
            }
        }
    }
    return @($Buckets)
}

function Get-TomlManifestEntries {
    param([string]$Toml)

    $Entries = @()
    $CurrentSection = $null
    foreach ($RawLine in ($Toml -split "\r?\n")) {
        $Line = $RawLine -replace '\s+#.*$', ''
        if ($Line -match '^\s*\[(?<section>[^\]]+)\]\s*$') {
            $Parts = @($Matches["section"] -split '\.')
            if ($Parts.Count -eq 4 -and $Parts[0] -in @("packages", "runtimes", "tools")) {
                $CurrentSection = [PSCustomObject]@{
                    Type = $Parts[0]
                    Profile = $Parts[1]
                    Provider = $Parts[2]
                    Category = $Parts[3]
                }
            } else {
                $CurrentSection = $null
            }
            continue
        }
        if ($null -eq $CurrentSection -or $Line -notmatch '^\s*(?:"(?<quoted>[^"]+)"|(?<bare>[^=\s]+))\s*=\s*"(?<version>[^"]*)"\s*$') {
            continue
        }
        $Name = if ($Matches["quoted"]) { $Matches["quoted"] } else { $Matches["bare"] }
        $Entries += [PSCustomObject]@{
            Type = $CurrentSection.Type
            Profile = $CurrentSection.Profile
            Provider = $CurrentSection.Provider
            Category = $CurrentSection.Category
            Name = $Name
            Version = $Matches["version"]
        }
    }
    return @($Entries)
}

function Get-ProviderLabel {
    param($Entry)

    if ($Entry.Type -eq "packages") { return "Scoop" }
    return "Mise"
}

function Show-ManifestList {
    param([object[]]$Entries)

    Write-Host "`n--- DECLARED ENTRIES ---" -ForegroundColor Cyan
    @(
        foreach ($Entry in $Entries) {
            [PSCustomObject]@{
                Profile = $Entry.Profile
                Provider = Get-ProviderLabel -Entry $Entry
                Identifier = $Entry.Name
                Version = $Entry.Version
            }
        }
    ) | Format-Table -AutoSize | Out-Host
    Write-Host "This list comes only from the manifest; no provider was queried."
}

function Test-ExactInventoryId {
    param(
        [string[]]$Ids,
        [string]$Expected
    )

    foreach ($Id in @($Ids)) {
        if ([string]::Equals([string]$Id, $Expected, [System.StringComparison]::Ordinal)) {
            return $true
        }
    }
    return $false
}

function Get-ScoopInventory {
    if ($null -eq (Get-Command scoop -ErrorAction SilentlyContinue)) {
        return [PSCustomObject]@{ State = "unavailable"; PackageIds = @(); Packages = @() }
    }
    try {
        $RawInventory = (& scoop export 2>$null | Out-String)
        if ($LASTEXITCODE -ne 0) {
            return [PSCustomObject]@{ State = "unavailable"; PackageIds = @(); Packages = @() }
        }
        $Export = $RawInventory | ConvertFrom-Json -ErrorAction Stop
        $AppsProperty = $Export.PSObject.Properties["apps"]
        if ($null -eq $AppsProperty -or $null -eq $AppsProperty.Value) {
            return [PSCustomObject]@{ State = "ambiguous"; PackageIds = @(); Packages = @() }
        }
        $Packages = @()
        foreach ($App in @($AppsProperty.Value)) {
            $NameProperty = if ($null -eq $App) { $null } else { $App.PSObject.Properties["Name"] }
            if ($null -eq $NameProperty -or [string]::IsNullOrWhiteSpace([string]$NameProperty.Value)) {
                return [PSCustomObject]@{ State = "ambiguous"; PackageIds = @(); Packages = @() }
            }
            $VersionProperty = $App.PSObject.Properties["Version"]
            $Packages += [PSCustomObject]@{
                Name = [string]$NameProperty.Value
                Version = if ($null -eq $VersionProperty) { "" } else { [string]$VersionProperty.Value }
            }
        }
        return [PSCustomObject]@{ State = "ready"; PackageIds = @($Packages | ForEach-Object Name); Packages = @($Packages) }
    } catch {
        return [PSCustomObject]@{ State = "ambiguous"; PackageIds = @(); Packages = @() }
    }
}

function Get-ScoopEntryMatch {
    param(
        $Inventory,
        $Entry
    )

    if ($Inventory.State -ne "ready") {
        return [PSCustomObject]@{ Status = "unavailable"; InstalledVersion = ""; VersionMatch = "unavailable" }
    }
    $Candidates = @($Inventory.Packages | Where-Object {
        [string]::Equals([string]$_.Name, [string]$Entry.Name, [StringComparison]::Ordinal)
    })
    if ($Candidates.Count -eq 0 -and (Test-ExactInventoryId -Ids $Inventory.PackageIds -Expected $Entry.Name)) {
        # Keep compatibility with provider test seams and older inventory objects that only expose IDs.
        $Candidates = @([PSCustomObject]@{ Name = $Entry.Name; Version = "" })
    }
    if ($Candidates.Count -eq 0) {
        return [PSCustomObject]@{ Status = "missing"; InstalledVersion = ""; VersionMatch = "none" }
    }

    $Candidate = $Candidates[0]
    $InstalledVersion = [string]$Candidate.Version
    if ([string]::Equals([string]$Entry.Version, "latest", [StringComparison]::OrdinalIgnoreCase)) {
        return [PSCustomObject]@{ Status = "installed"; InstalledVersion = $InstalledVersion; VersionMatch = "provider-spec" }
    }
    if ([string]::Equals($InstalledVersion, [string]$Entry.Version, [StringComparison]::Ordinal)) {
        return [PSCustomObject]@{ Status = "installed"; InstalledVersion = $InstalledVersion; VersionMatch = "exact" }
    }
    if ([string]::IsNullOrWhiteSpace($InstalledVersion)) {
        return [PSCustomObject]@{ Status = "version-unavailable"; InstalledVersion = "unreported"; VersionMatch = "unverified" }
    }
    return [PSCustomObject]@{ Status = "mismatch"; InstalledVersion = $InstalledVersion; VersionMatch = "mismatch" }
}

function Get-MiseCommand {
    return Get-Command mise -ErrorAction SilentlyContinue | Select-Object -First 1
}

function Get-MiseInventory {
    $Mise = Get-MiseCommand
    if ($null -eq $Mise) { return [PSCustomObject]@{ State = "unavailable"; Records = @() } }
    try {
        $RawInventory = (& $Mise.Path ls --installed --json 2>$null | Out-String)
        if ($LASTEXITCODE -ne 0) { return [PSCustomObject]@{ State = "unavailable"; Records = @() } }
        if ([string]::IsNullOrWhiteSpace($RawInventory)) { return [PSCustomObject]@{ State = "ready"; Records = @() } }
        $Inventory = $RawInventory | ConvertFrom-Json -ErrorAction Stop
        $Records = @()
        foreach ($ToolProperty in @($Inventory.PSObject.Properties)) {
            foreach ($Record in @($ToolProperty.Value)) {
                if ($null -eq $Record) { continue }
                $InstalledProperty = $Record.PSObject.Properties["installed"]
                if ($null -ne $InstalledProperty -and -not [bool]$InstalledProperty.Value) { continue }
                $VersionProperty = $Record.PSObject.Properties["version"]
                $RequestedVersionProperty = $Record.PSObject.Properties["requested_version"]
                $Records += [PSCustomObject]@{
                    Name = [string]$ToolProperty.Name
                    Version = if ($null -eq $VersionProperty) { "" } else { [string]$VersionProperty.Value }
                    RequestedVersion = if ($null -eq $RequestedVersionProperty) { "" } else { [string]$RequestedVersionProperty.Value }
                }
            }
        }
        return [PSCustomObject]@{ State = "ready"; Records = @($Records) }
    } catch {
        return [PSCustomObject]@{ State = "ambiguous"; Records = @() }
    }
}

function Get-MiseEntryMatch {
    param(
        $Inventory,
        $Entry
    )

    if ($Inventory.State -ne "ready") {
        return [PSCustomObject]@{ Status = "unavailable"; InstalledVersion = ""; VersionMatch = "unavailable" }
    }
    $Candidates = @($Inventory.Records | Where-Object {
        [string]::Equals([string]$_.Name, [string]$Entry.Name, [StringComparison]::Ordinal)
    })
    if ($Candidates.Count -eq 0) {
        return [PSCustomObject]@{ Status = "missing"; InstalledVersion = ""; VersionMatch = "none" }
    }

    if ([string]::Equals([string]$Entry.Version, "latest", [StringComparison]::OrdinalIgnoreCase)) {
        return [PSCustomObject]@{ Status = "installed"; InstalledVersion = [string]$Candidates[0].Version; VersionMatch = "provider-spec" }
    }
    $Exact = @($Candidates | Where-Object {
        [string]::Equals([string]$_.Version, [string]$Entry.Version, [StringComparison]::Ordinal) -or
        [string]::Equals([string]$_.RequestedVersion, [string]$Entry.Version, [StringComparison]::Ordinal)
    })
    if ($Exact.Count -gt 0) {
        return [PSCustomObject]@{ Status = "installed"; InstalledVersion = [string]$Exact[0].Version; VersionMatch = "exact" }
    }
    $InstalledVersions = @($Candidates | ForEach-Object { [string]$_.Version } | Where-Object { $_ })
    $VersionText = if ($InstalledVersions.Count -gt 0) { $InstalledVersions -join "," } else { "unreported" }
    return [PSCustomObject]@{ Status = "mismatch"; InstalledVersion = $VersionText; VersionMatch = "mismatch" }
}

function Get-MiseStatus {
    param(
        $Entry,
        $Inventory
    )

    if ($null -eq $Inventory) { $Inventory = Get-MiseInventory }
    return (Get-MiseEntryMatch -Inventory $Inventory -Entry $Entry).Status
}

function Show-ProviderStatus {
    param([object[]]$Entries)

    $ScoopEntries = @($Entries | Where-Object { $_.Type -eq "packages" })
    $ScoopInventory = if ($ScoopEntries.Count -gt 0) {
        Get-ScoopInventory
    } else {
        [PSCustomObject]@{ State = "not-needed"; PackageIds = @(); Packages = @() }
    }
    $MiseEntries = @($Entries | Where-Object { $_.Type -ne "packages" })
    $MiseInventory = if ($MiseEntries.Count -gt 0) { Get-MiseInventory } else { [PSCustomObject]@{ State = "not-needed"; Records = @() } }

    Write-Host "`n--- DECLARED ENTRY STATUS ---" -ForegroundColor Cyan
    @(
        foreach ($Entry in $Entries) {
            $EntryStatus = if ($Entry.Type -eq "packages") {
                (Get-ScoopEntryMatch -Inventory $ScoopInventory -Entry $Entry).Status
            } else {
                (Get-MiseEntryMatch -Inventory $MiseInventory -Entry $Entry).Status
            }
            [PSCustomObject]@{
                Profile = $Entry.Profile
                Provider = Get-ProviderLabel -Entry $Entry
                Identifier = $Entry.Name
                Version = $Entry.Version
                Status = $EntryStatus
            }
        }
    ) | Format-Table -AutoSize | Out-Host
    Write-Host "“unavailable”: the provider inventory is not accessible."
    Write-Host "A present ID proves only that its provider knows it, not that DevRecipe installed it."
}

function Show-DryRunPlan {
    param(
        [object[]]$OsEntries,
        [object[]]$MiseEntries,
        [object[]]$DeclaredBuckets,
        [bool]$ConfigureMiseShims,
        [bool]$DryRun
    )

    $PlanTitle = if ($DryRun) { "DRY-RUN PLAN (no changes)" } else { "FINAL INSTALLATION PLAN AFTER PREFLIGHT" }
    Write-Host "`n--- $PlanTitle ---" -ForegroundColor Cyan
        Write-Host "Scoop: if absent, run the remote bootstrap `Invoke-RestMethod https://get.scoop.sh | Invoke-Expression`."
    if ($OsEntries.Count -gt 0) {
        $BucketsToAdd = if ($null -ne $DeclaredBuckets -and $DeclaredBuckets.Count -gt 0) {
            $DeclaredBuckets
        } else {
            @([PSCustomObject]@{ Name = "extras"; Url = "" })
        }
        foreach ($Bucket in $BucketsToAdd) {
            Write-Host "Scoop: add the $($Bucket.Name) bucket if absent."
        }
        Write-Host "Scoop: scoop install $((@($OsEntries | ForEach-Object Name) -join ' '))"
    }
    if ($MiseEntries.Count -gt 0) {
        Write-Host "Mise: if absent after the Scoop bootstrap, install the provider with `scoop install mise`."
        Write-Host "Mise: mise install $((@($MiseEntries | ForEach-Object { "$($_.Name)@$($_.Version)" }) -join ' '))"
    }
    if ($ConfigureMiseShims) {
        Write-Host "Mise: mise reshim."
        Write-Host "Mise: add %LOCALAPPDATA%\mise\shims to the user PATH for cmd.exe and new processes."
        Write-Host "Command Processor: configure AutoRun in HKCU to prepend Mise and Scoop shims for cmd.exe and sub-processes."
        Write-Host "Shell startup files: add Mise shims activation commands for available compatible shells: PowerShell, Nushell, Bash, Zsh, Fish, Elvish, and Xonsh."
        Write-Host "Open a new terminal after installation; already-running processes keep their existing PATH."
    }
}

function Invoke-Scoop {
    param([string[]]$Arguments)

    & scoop @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) {
           throw "Scoop failed: scoop $($Arguments -join ' ')"
    }
}

function Initialize-Scoop {
    if ($null -ne (Get-Command scoop -ErrorAction SilentlyContinue)) {
        return
    }
    Write-Host "Bootstrap Scoop..." -ForegroundColor Cyan
    Confirm-DevRecipeReviewAction -Command "Invoke-RestMethod https://get.scoop.sh | Invoke-Expression" -Privilege "user" -Source "https://get.scoop.sh" -Effect "bootstrap Scoop in the current user profile"
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    if ($null -eq (Get-Command scoop -ErrorAction SilentlyContinue)) {
           throw "Scoop was not found after bootstrap."
    }
}

function Add-ScoopBucketIfAbsent {
    param(
        [string]$BucketName,
        [string]$BucketUrl = ""
    )

    $Buckets = @(& scoop bucket list 2>$null | Where-Object { $_ -match "^\s*$([regex]::Escape($BucketName))\s" })
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read Scoop buckets."
    }
    if ($Buckets.Count -eq 0) {
        $AddArgs = @("bucket", "add", $BucketName)
        if (-not [string]::IsNullOrWhiteSpace($BucketUrl)) {
            $AddArgs += $BucketUrl
        }
        Confirm-DevRecipeReviewAction -Command "scoop $($AddArgs -join ' ')" -Privilege "user" -Source "Scoop $BucketName bucket" -Effect "add the Scoop $BucketName bucket"
        Invoke-Scoop -Arguments $AddArgs
    }
}

function Invoke-Mise {
    param([string[]]$Arguments)

    $Mise = Get-MiseCommand
    if ($null -eq $Mise) {
           throw "Mise was not found."
    }
    & $Mise.Path @Arguments
    if ($LASTEXITCODE -ne 0) {
           throw "Mise failed: mise $($Arguments -join ' ')"
    }
}

function Get-DevRecipeShellConfigRoot {
    if (-not [string]::IsNullOrWhiteSpace($env:DEVRECIPE_TEST_SHELL_CONFIG_ROOT)) { return $env:DEVRECIPE_TEST_SHELL_CONFIG_ROOT }
    return $null
}

function Test-DevRecipeShellAvailable {
    param([string[]]$Names)

    if (-not [string]::IsNullOrWhiteSpace($env:DEVRECIPE_TEST_AVAILABLE_SHELLS)) {
        $Available = @($env:DEVRECIPE_TEST_AVAILABLE_SHELLS -split ',' | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
        foreach ($Name in $Names) { if ($Available -contains $Name.ToLowerInvariant()) { return $true } }
        return $false
    }
    foreach ($Name in $Names) { if ($null -ne (Get-Command $Name -ErrorAction SilentlyContinue)) { return $true } }
    return $false
}

function Get-DevRecipePowerShellProfilePaths {
    $TestRoot = Get-DevRecipeShellConfigRoot
    $Paths = @()
    if (Test-DevRecipeShellAvailable -Names @("powershell", "powershell.exe")) {
        $Base = if (-not [string]::IsNullOrWhiteSpace($TestRoot)) { $TestRoot } else { Join-Path $env:USERPROFILE "Documents" }
        $Paths += Join-Path $Base "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    }
    if (Test-DevRecipeShellAvailable -Names @("pwsh", "pwsh.exe")) {
        $Base = if (-not [string]::IsNullOrWhiteSpace($TestRoot)) { $TestRoot } else { Join-Path $env:USERPROFILE "Documents" }
        $Paths += Join-Path $Base "PowerShell\Microsoft.PowerShell_profile.ps1"
    }
    return @($Paths | Select-Object -Unique)
}

function Get-DevRecipeNushellConfigPaths {
    $TestRoot = Get-DevRecipeShellConfigRoot
    if (-not [string]::IsNullOrWhiteSpace($TestRoot)) { $Base = Join-Path $TestRoot "nushell" } else { $Base = Join-Path $env:APPDATA "nushell" }
    return [PSCustomObject]@{
        Env = Join-Path $Base "env.nu"
        Config = Join-Path $Base "config.nu"
    }
}

function Get-DevRecipeMiseShimsPath {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw "LOCALAPPDATA is required to configure the Mise shims path."
    }
    return [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA "mise\shims"))
}

function Get-DevRecipeWindowsUserPath {
    $TestPathFile = $env:DEVRECIPE_TEST_USER_PATH_FILE
    if (-not [string]::IsNullOrWhiteSpace($TestPathFile)) {
        if (Test-Path -LiteralPath $TestPathFile -PathType Leaf) {
            return [IO.File]::ReadAllText($TestPathFile)
        }
        return ""
    }
    return [Environment]::GetEnvironmentVariable("Path", "User")
}

function Set-DevRecipeWindowsUserPath {
    param([string]$Value)

    $TestPathFile = $env:DEVRECIPE_TEST_USER_PATH_FILE
    if (-not [string]::IsNullOrWhiteSpace($TestPathFile)) {
        [IO.File]::WriteAllText($TestPathFile, $Value)
        return
    }
    [Environment]::SetEnvironmentVariable("Path", $Value, "User")
}

function Send-DevRecipeEnvironmentChangeNotification {
    if (-not [string]::IsNullOrWhiteSpace($env:DEVRECIPE_TEST_USER_PATH_FILE)) {
        return
    }
    if ($null -eq ("DevRecipeEnvironmentNotification" -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class DevRecipeEnvironmentNotification {
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd,
        uint Msg,
        UIntPtr wParam,
        string lParam,
        uint fuFlags,
        uint uTimeout,
        out UIntPtr lpdwResult);
}
"@
    }
    $Result = [UIntPtr]::Zero
    [void][DevRecipeEnvironmentNotification]::SendMessageTimeout(
        [IntPtr]0xffff,
        0x001a,
        [UIntPtr]::Zero,
        "Environment",
        0x0002,
        5000,
        [ref]$Result)
}

function Get-DevRecipeScoopShimsPath {
    if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        throw "USERPROFILE is required to configure the Scoop shims path."
    }
    return [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE "scoop\shims"))
}

function Get-DevRecipeShimsPrependCmdPath {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw "LOCALAPPDATA is required to configure the DevRecipe shims script."
    }
    return [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA "DevRecipe\shims_prepend.cmd"))
}

function Get-DevRecipeCommandProcessorAutoRun {
    $TestAutoRunFile = $env:DEVRECIPE_TEST_AUTORUN_FILE
    if (-not [string]::IsNullOrWhiteSpace($TestAutoRunFile)) {
        if (Test-Path -LiteralPath $TestAutoRunFile -PathType Leaf) {
            return [IO.File]::ReadAllText($TestAutoRunFile)
        }
        return ""
    }
    try {
        $RegKey = "HKCU:\Software\Microsoft\Command Processor"
        if (Test-Path -LiteralPath $RegKey) {
            $Prop = Get-ItemProperty -LiteralPath $RegKey -Name "AutoRun" -ErrorAction SilentlyContinue
            if ($null -ne $Prop -and $null -ne $Prop.AutoRun) {
                return [string]$Prop.AutoRun
            }
        }
    } catch { }
    return ""
}

function Set-DevRecipeCommandProcessorAutoRun {
    param([string]$Value)

    $TestAutoRunFile = $env:DEVRECIPE_TEST_AUTORUN_FILE
    if (-not [string]::IsNullOrWhiteSpace($TestAutoRunFile)) {
        [IO.File]::WriteAllText($TestAutoRunFile, $Value)
        return
    }
    $RegKey = "HKCU:\Software\Microsoft\Command Processor"
    if (-not (Test-Path -LiteralPath $RegKey)) {
        New-Item -Path $RegKey -Force | Out-Null
    }
    Set-ItemProperty -LiteralPath $RegKey -Name "AutoRun" -Value $Value -Type String
}

function Ensure-DevRecipeCommandProcessorAutoRun {
    $CmdPath = Get-DevRecipeShimsPrependCmdPath
    $CmdDir = Split-Path -Parent $CmdPath
    if (-not (Test-Path -LiteralPath $CmdDir)) {
        New-Item -ItemType Directory -Force -Path $CmdDir | Out-Null
    }

    $ScriptContent = "@if not defined DEVRECIPE_SHIMS_PREPENDED (set `"DEVRECIPE_SHIMS_PREPENDED=1`" & set `"PATH=%LOCALAPPDATA%\mise\shims;%USERPROFILE%\scoop\shims;%PATH%`")`r`n"
    $WriteScript = $true
    if (Test-Path -LiteralPath $CmdPath -PathType Leaf) {
        $ExistingContent = [IO.File]::ReadAllText($CmdPath)
        if ($ExistingContent -eq $ScriptContent) {
            $WriteScript = $false
        }
    }

    if ($WriteScript) {
        Confirm-DevRecipeReviewAction -Command "Set-Content $CmdPath" -Privilege "user" -Source $CmdPath -Effect "create shim precedence script for cmd.exe sub-processes"
        [IO.File]::WriteAllText($CmdPath, $ScriptContent)
        Write-Host "Created cmd.exe shim precedence script: $CmdPath." -ForegroundColor Green
    }

    $AutoRunSnippet = "if exist `"%LOCALAPPDATA%\DevRecipe\shims_prepend.cmd`" call `"%LOCALAPPDATA%\DevRecipe\shims_prepend.cmd`""
    $CurrentAutoRun = [string](Get-DevRecipeCommandProcessorAutoRun)
    if ($CurrentAutoRun -notlike "*shims_prepend.cmd*") {
        $NewAutoRun = if ([string]::IsNullOrWhiteSpace($CurrentAutoRun)) { $AutoRunSnippet } else { "$AutoRunSnippet & $CurrentAutoRun" }
        Confirm-DevRecipeReviewAction -Command "Set AutoRun in HKCU:\Software\Microsoft\Command Processor" -Privilege "user" -Source "HKCU:\Software\Microsoft\Command Processor" -Effect "execute shim precedence script on cmd.exe startup"
        Set-DevRecipeCommandProcessorAutoRun -Value $NewAutoRun
        Write-Host "Configured cmd.exe AutoRun to prepend Mise and Scoop shims." -ForegroundColor Green
    } else {
        Write-Host "cmd.exe AutoRun already contains DevRecipe shim precedence." -ForegroundColor Yellow
    }
}

function Ensure-DevRecipeMiseShimsUserPath {
    $ShimsPath = Get-DevRecipeMiseShimsPath
    $ScoopShimsPath = Get-DevRecipeScoopShimsPath
    $UserPath = [string](Get-DevRecipeWindowsUserPath)
    $ComparableShimsPath = $ShimsPath -replace '[\\/]+$', ''
    $ComparableScoopShimsPath = $ScoopShimsPath -replace '[\\/]+$', ''
    $IncludeScoop = (Test-Path -LiteralPath $ScoopShimsPath)
    $RemainingUserEntries = @(
        foreach ($ExistingEntry in @($UserPath -split [IO.Path]::PathSeparator)) {
            $TrimmedEntry = ([string]$ExistingEntry).Trim()
            if ([string]::IsNullOrWhiteSpace($TrimmedEntry)) { continue }
            $ExpandedEntry = [Environment]::ExpandEnvironmentVariables($TrimmedEntry) -replace '[\\/]+$', ''
            if ([string]::Equals($ExpandedEntry, $ComparableScoopShimsPath, [StringComparison]::OrdinalIgnoreCase)) {
                $IncludeScoop = $true
                continue
            }
            if (-not [string]::Equals($ExpandedEntry, $ComparableShimsPath, [StringComparison]::OrdinalIgnoreCase)) {
                $TrimmedEntry
            }
        }
    )
    $HeadEntries = if ($IncludeScoop) { @($ShimsPath, $ScoopShimsPath) } else { @($ShimsPath) }
    $UpdatedUserPath = (@($HeadEntries) + @($RemainingUserEntries)) -join [IO.Path]::PathSeparator
    $UserPathChanged = -not [string]::Equals($UserPath, $UpdatedUserPath, [StringComparison]::Ordinal)
    if ($UserPathChanged) {
        Confirm-DevRecipeReviewAction -Command "Set user PATH to include $ShimsPath" -Privilege "user" -Source "HKCU:\Environment\Path" -Effect "make Mise shims available first to cmd.exe and new processes"
        Set-DevRecipeWindowsUserPath -Value $UpdatedUserPath
        Send-DevRecipeEnvironmentChangeNotification
        Write-Host "Mise shims path added first in the user PATH: $ShimsPath. Open a new terminal to use it in cmd.exe." -ForegroundColor Green
    } else {
        Write-Host "Mise shims path is already first in the user PATH: $ShimsPath." -ForegroundColor Yellow
    }

    $ProcessPath = [string]$env:Path
    $IncludeProcessScoop = (Test-Path -LiteralPath $ScoopShimsPath)
    $RemainingProcessEntries = @(
        foreach ($ExistingEntry in @($ProcessPath -split [IO.Path]::PathSeparator)) {
            $TrimmedEntry = ([string]$ExistingEntry).Trim()
            if ([string]::IsNullOrWhiteSpace($TrimmedEntry)) { continue }
            $ExpandedEntry = [Environment]::ExpandEnvironmentVariables($TrimmedEntry) -replace '[\\/]+$', ''
            if ([string]::Equals($ExpandedEntry, $ComparableScoopShimsPath, [StringComparison]::OrdinalIgnoreCase)) {
                $IncludeProcessScoop = $true
                continue
            }
            if (-not [string]::Equals($ExpandedEntry, $ComparableShimsPath, [StringComparison]::OrdinalIgnoreCase)) {
                $TrimmedEntry
            }
        }
    )
    $HeadProcessEntries = if ($IncludeProcessScoop) { @($ShimsPath, $ScoopShimsPath) } else { @($ShimsPath) }
    $UpdatedProcessPath = (@($HeadProcessEntries) + @($RemainingProcessEntries)) -join [IO.Path]::PathSeparator
    if (-not [string]::Equals($ProcessPath, $UpdatedProcessPath, [StringComparison]::Ordinal)) {
        $env:Path = $UpdatedProcessPath
    }
}

function Add-DevRecipeMarkedShellContent {
    param(
        [string]$Path,
        [string]$Marker,
        [string]$Content,
        [string]$Effect
    )

    if ((Test-Path -LiteralPath $Path -PathType Leaf) -and (Select-String -LiteralPath $Path -Pattern $Marker -SimpleMatch -Quiet)) {
        Write-Host "Mise shims activation is already present in $Path." -ForegroundColor Yellow
        return
    }
    $Directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($Directory)) { New-Item -ItemType Directory -Force -Path $Directory | Out-Null }
    Confirm-DevRecipeReviewAction -Command "Add-Content $Path" -Privilege "user" -Source $Path -Effect $Effect
    Add-Content -LiteralPath $Path -Value $Content
    Write-Host "Mise shims activation added to $Path." -ForegroundColor Green
}

function Enable-MiseShellShimsActivation {
    $PowerShellActivation = @'

# DevRecipe: Mise shims activation
$ScoopShims = Join-Path $env:USERPROFILE "scoop\shims"
if (Test-Path -LiteralPath $ScoopShims) {
    $env:Path = "$ScoopShims;" + (($env:Path -split [IO.Path]::PathSeparator | Where-Object { $_ -ne $ScoopShims }) -join [IO.Path]::PathSeparator)
}
if (Get-Command mise -ErrorAction SilentlyContinue) {
    (& mise activate pwsh --shims) | Out-String | Invoke-Expression
}
'@
    foreach ($ProfilePath in @(Get-DevRecipePowerShellProfilePaths | Select-Object -Unique)) {
        Add-DevRecipeMarkedShellContent -Path $ProfilePath -Marker "# DevRecipe: Mise shims activation" -Content $PowerShellActivation -Effect "append Mise-managed shim activation for new PowerShell sessions"
    }

    if (Test-DevRecipeShellAvailable -Names @("nu", "nu.exe")) {
        $NushellPaths = Get-DevRecipeNushellConfigPaths
        Add-DevRecipeMarkedShellContent -Path $NushellPaths.Env -Marker "# DevRecipe: Mise shims activation" -Content @'

# DevRecipe: Mise shims activation
let scoop_shims = ($nu.home-path | path join "scoop" "shims")
if ($scoop_shims | path exists) {
    $env.PATH = ($env.PATH | prepend $scoop_shims)
}
let mise_path = $nu.default-config-dir | path join mise.nu
^mise activate nu --shims | save $mise_path --force
'@ -Effect "append Mise-managed shim activation generator for new Nushell sessions"
        Add-DevRecipeMarkedShellContent -Path $NushellPaths.Config -Marker "# DevRecipe: Mise shims activation" -Content @'

# DevRecipe: Mise shims activation
use ($nu.default-config-dir | path join mise.nu)
'@ -Effect "append Mise-managed shim activation import for new Nushell sessions"
    }

    $TestRoot = Get-DevRecipeShellConfigRoot
    $HomeRoot = if (-not [string]::IsNullOrWhiteSpace($TestRoot)) { $TestRoot } else { $env:USERPROFILE }
    if (Test-DevRecipeShellAvailable -Names @("bash", "bash.exe")) {
        foreach ($BashPath in @((Join-Path $HomeRoot ".bash_profile"), (Join-Path $HomeRoot ".bashrc"))) {
            Add-DevRecipeMarkedShellContent -Path $BashPath -Marker "# DevRecipe: Mise shims activation" -Content @'

# DevRecipe: Mise shims activation
[ -d "$USERPROFILE/scoop/shims" ] && PATH="$USERPROFILE/scoop/shims:$PATH"
eval "$(mise activate bash --shims)"
'@ -Effect "append Mise-managed shim activation for new Bash sessions"
        }
    }
    if (Test-DevRecipeShellAvailable -Names @("zsh", "zsh.exe")) {
        foreach ($ZshPath in @((Join-Path $HomeRoot ".zprofile"), (Join-Path $HomeRoot ".zshrc"))) {
            Add-DevRecipeMarkedShellContent -Path $ZshPath -Marker "# DevRecipe: Mise shims activation" -Content @'

# DevRecipe: Mise shims activation
[ -d "$USERPROFILE/scoop/shims" ] && PATH="$USERPROFILE/scoop/shims:$PATH"
eval "$(mise activate zsh --shims)"
'@ -Effect "append Mise-managed shim activation for new Zsh sessions"
        }
    }
    if (Test-DevRecipeShellAvailable -Names @("fish", "fish.exe")) {
        $FishBase = if (-not [string]::IsNullOrWhiteSpace($TestRoot)) { Join-Path $TestRoot "fish" } else { Join-Path $env:APPDATA "fish" }
        Add-DevRecipeMarkedShellContent -Path (Join-Path $FishBase "config.fish") -Marker "# DevRecipe: Mise shims activation" -Content @'

# DevRecipe: Mise shims activation
if test -d "$USERPROFILE/scoop/shims"
    set -gx PATH "$USERPROFILE/scoop/shims" $PATH
end
mise activate fish --shims | source
'@ -Effect "append Mise-managed shim activation for new Fish sessions"
    }
    if (Test-DevRecipeShellAvailable -Names @("elvish", "elvish.exe")) {
        $ElvishBase = if (-not [string]::IsNullOrWhiteSpace($TestRoot)) { Join-Path $TestRoot "elvish" } else { Join-Path $env:APPDATA "elvish" }
        Add-DevRecipeMarkedShellContent -Path (Join-Path $ElvishBase "rc.elv") -Marker "# DevRecipe: Mise shims activation" -Content @'

# DevRecipe: Mise shims activation
if (test -d $E:USERPROFILE/scoop/shims) {
    set paths = [$E:USERPROFILE/scoop/shims $@paths]
}
eval (mise activate elvish --shims | slurp)
'@ -Effect "append Mise-managed shim activation for new Elvish sessions"
    }
    if (Test-DevRecipeShellAvailable -Names @("xonsh", "xonsh.exe")) {
        Add-DevRecipeMarkedShellContent -Path (Join-Path $HomeRoot ".xonshrc") -Marker "# DevRecipe: Mise shims activation" -Content @'

# DevRecipe: Mise shims activation
import os
scoop_shims = os.path.expanduser("~/scoop/shims")
if os.path.isdir(scoop_shims):
    $PATH.insert(0, scoop_shims)
execx($(mise activate xonsh --shims))
'@ -Effect "append Mise-managed shim activation for new Xonsh sessions"
    }
    Write-Host "Mise shims activation configured for available compatible shells. Open new shell sessions to use Mise-managed commands." -ForegroundColor Green
}

function Test-IsAdministrator {
    $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object System.Security.Principal.WindowsPrincipal($Identity)
    return $Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ContainerPackageKeys {
    param([string]$Toml)

    $Packages = @()
    $InContainerSection = $false
    foreach ($RawLine in ($Toml -split "\r?\n")) {
        $Line = $RawLine -replace '\s+#.*$', ''
        if ($Line -match '^\s*\[(?<section>[^\]]+)\]\s*$') {
            $InContainerSection = $Matches["section"] -match '^containers\.default\.os\.[^.]+$'
            continue
        }
        if ($InContainerSection -and $Line -match '^\s*"?([^"=\s]+)"?\s*=') {
            $Packages += $Matches[1]
        }
    }
    return @($Packages)
}

function Get-ContainerPackages {
    $Packages = @(Get-ContainerPackageKeys -Toml (Get-Content -LiteralPath $TomlPath -Raw -ErrorAction Stop))
    if ($Packages.Count -eq 0) {
        throw "The [containers.default.os.*] sections are empty in $TomlPath."
    }
    return $Packages
}

function Show-ContainerDryRunPlan {
    param(
        [string[]]$Packages,
        [string]$Provider,
        [bool]$DryRun
    )

    $PlanTitle = if ($DryRun) { "CONTAINER DRY-RUN PLAN (no changes)" } else { "FINAL CONTAINER INSTALLATION PLAN AFTER PREFLIGHT" }
    Write-Host "`n--- $PlanTitle ---" -ForegroundColor Cyan
    Write-Host "Scoop: if absent, run the remote bootstrap `Invoke-RestMethod https://get.scoop.sh | Invoke-Expression`."
    Write-Host "Scoop: add the extras bucket if absent."
    Write-Host "Scoop: scoop install $($Packages -join ' ')"
    if ($Provider -eq "Auto") {
        Write-Host "Windows: inspect WSL 2 and Hyper-V; request UAC only if features must be enabled."
    } else {
        Write-Host "Windows: prepare requested Podman provider: $Provider; request UAC only if its features must be enabled."
    }
    Write-Host "Podman: preserve any existing Podman machine or WSL 2 distribution; no machine is created automatically."
    if ($EnableDockerAlias) {
        Write-Host "PowerShell: add docker-to-podman alias only if docker does not already resolve."
    }
}

function Enable-DockerCompatibilityAlias {
    if ($null -eq (Get-Command podman -ErrorAction SilentlyContinue)) {
        throw "Podman must be installed before creating the Docker alias."
    }
    $ExistingDocker = Get-Command docker -ErrorAction SilentlyContinue
    if ($null -ne $ExistingDocker) {
        Write-Warning "Docker alias skipped: 'docker' already resolves to $($ExistingDocker.Definition)."
        return
    }
    $ProfileDirectory = Split-Path -Parent $PROFILE
    New-Item -ItemType Directory -Force -Path $ProfileDirectory | Out-Null
    $Marker = "# DevRecipe: optional Docker-to-Podman compatibility"
    if ((Test-Path $PROFILE) -and (Select-String -Path $PROFILE -Pattern $Marker -SimpleMatch -Quiet)) {
        Write-Host "Docker alias is already present in $PROFILE." -ForegroundColor Yellow
        return
    }
    $AliasDefinition = @'
# DevRecipe: optional Docker-to-Podman compatibility
function docker {
    & podman @args
}
'@
    Confirm-DevRecipeReviewAction -Command "Add-Content $PROFILE" -Privilege "user" -Source $PROFILE -Effect "append the optional docker-to-podman compatibility function"
    Add-Content -Path $PROFILE -Value $AliasDefinition
    Write-Host "Docker alias added to $PROFILE. Open a new PowerShell session to use it." -ForegroundColor Green
}

function Get-OptionalFeature {
    param([string]$Name)

    try {
        return Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction Stop
    } catch {
        return $null
    }
}

function Enable-OptionalFeatureIfNeeded {
    param([string]$Name)

    $Feature = Get-OptionalFeature $Name
    if ($null -eq $Feature) {
        throw "Windows feature '$Name' is not available on this host."
    }
    if ($Feature.State -eq "Enabled") {
        return $false
    }
    Confirm-DevRecipeReviewAction -Command "Enable-WindowsOptionalFeature -FeatureName $Name" -Privilege "elevated" -Source "Windows optional feature $Name" -Effect "enable the selected Windows feature"
    Enable-WindowsOptionalFeature -Online -FeatureName $Name -All -NoRestart | Out-Null
    return $true
}

function Get-ExistingPodmanMachines {
    if ($null -eq (Get-Command podman -ErrorAction SilentlyContinue)) {
        return @()
    }
    $MachineNames = & podman machine list --format '{{.Name}}' 2>$null
    if ($LASTEXITCODE -ne 0) {
        return @()
    }
    return @($MachineNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-ExistingWslPodmanDistributions {
    if ($null -eq (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        return @()
    }
    $Distributions = @(& wsl.exe --list --quiet 2>$null)
    if ($LASTEXITCODE -ne 0) {
        return @()
    }
    $PodmanDistributions = @()
    foreach ($RawDistribution in $Distributions) {
        $Distribution = ([string]$RawDistribution).Replace([string][char]0, "").Trim()
        if ([string]::IsNullOrWhiteSpace($Distribution)) {
            continue
        }
        $Kernel = & wsl.exe --distribution $Distribution --exec uname -r 2>$null
        if ($LASTEXITCODE -ne 0 -or (($Kernel -join "`n") -notmatch '(?i)wsl2|microsoft-standard')) {
            continue
        }
        & wsl.exe --distribution $Distribution --exec sh -lc 'command -v podman >/dev/null 2>&1' 2>$null
        if ($LASTEXITCODE -eq 0) {
            $PodmanDistributions += $Distribution
        }
    }
    return @($PodmanDistributions)
}

function Resolve-ContainerProvider {
    param(
        [ValidateSet("Auto", "WSL", "HyperV")]
        [string]$Provider
    )

    $WslFeature = Get-OptionalFeature "Microsoft-Windows-Subsystem-Linux"
    $VirtualMachinePlatformFeature = Get-OptionalFeature "VirtualMachinePlatform"
    $HyperVFeature = Get-OptionalFeature "Microsoft-Hyper-V-All"
    $WslReady = $null -ne $WslFeature -and $null -ne $VirtualMachinePlatformFeature -and `
        $WslFeature.State -eq "Enabled" -and $VirtualMachinePlatformFeature.State -eq "Enabled"
    $HyperVReady = $null -ne $HyperVFeature -and $HyperVFeature.State -eq "Enabled"

    switch ($Provider) {
        "WSL" {
            if ($null -eq $WslFeature -or $null -eq $VirtualMachinePlatformFeature) {
                throw "WSL 2 is not available on this host."
            }
            return "WSL"
        }
        "HyperV" {
            if ($null -eq $HyperVFeature) {
                throw "Hyper-V is not available on this host or Windows edition."
            }
            return "HyperV"
        }
        default {
            if ($WslReady) { return "WSL" }
            if ($HyperVReady) { return "HyperV" }
            if ($null -ne $WslFeature -and $null -ne $VirtualMachinePlatformFeature) { return "WSL" }
            if ($null -ne $HyperVFeature) { return "HyperV" }
            throw "Neither WSL 2 nor Hyper-V is available on this host."
        }
    }
}

function Confirm-ContainerFeaturePlan {
    param(
        [ValidateSet("WSL", "HyperV")]
        [string]$Provider
    )

    if ($Provider -eq "WSL") {
        foreach ($FeatureName in @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform")) {
            $Feature = Get-OptionalFeature $FeatureName
            if ($null -ne $Feature -and $Feature.State -ne "Enabled") {
                Confirm-DevRecipeReviewAction -Command "Enable-WindowsOptionalFeature -FeatureName $FeatureName" -Privilege "elevated" -Source "Windows optional feature $FeatureName" -Effect "enable the selected Windows feature"
            }
        }
        $WslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"
        if (-not (Test-Path -LiteralPath $WslConfigPath)) {
            Confirm-DevRecipeReviewAction -Command "Set-Content $WslConfigPath" -Privilege "elevated" -Source $WslConfigPath -Effect "create the WSL networking configuration if absent"
        }
    } else {
        $Feature = Get-OptionalFeature "Microsoft-Hyper-V-All"
        if ($null -ne $Feature -and $Feature.State -ne "Enabled") {
            Confirm-DevRecipeReviewAction -Command "Enable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All" -Privilege "elevated" -Source "Windows optional feature Microsoft-Hyper-V-All" -Effect "enable the selected Windows feature"
        }
    }
}

function Invoke-ContainerFeatureSetup {
    param(
        [ValidateSet("WSL", "HyperV")]
        [string]$Provider,
        [string]$TargetUserProfile
    )

    if (-not (Test-IsAdministrator)) {
        throw "-ContainerFeatureSetupOnly must be run by the elevated process started by this recipe."
    }
    $RestartRequired = $false
    if ($Provider -eq "WSL") {
        if (Enable-OptionalFeatureIfNeeded "Microsoft-Windows-Subsystem-Linux") {
            $RestartRequired = $true
        }
        if (Enable-OptionalFeatureIfNeeded "VirtualMachinePlatform") {
            $RestartRequired = $true
        }
        $WslConfigProfile = if ([string]::IsNullOrWhiteSpace($TargetUserProfile)) { $env:USERPROFILE } else { $TargetUserProfile }
        $WslConfigPath = Join-Path $WslConfigProfile ".wslconfig"
        if (-not (Test-Path $WslConfigPath)) {
            Confirm-DevRecipeReviewAction -Command "Set-Content $WslConfigPath" -Privilege "elevated" -Source $WslConfigPath -Effect "create the WSL networking configuration if absent"
            Set-Content -Path $WslConfigPath -Value "[wsl2]`nnetworkingMode=mirrored`ndnsTunneling=true`nfirewall=true"
        } else {
            Write-Host ".wslconfig already exists; the script does not overwrite it."
        }
    } else {
        if (Enable-OptionalFeatureIfNeeded "Microsoft-Hyper-V-All") {
            $RestartRequired = $true
        }
    }
    Write-Host "Selected Podman provider: $Provider" -ForegroundColor Cyan
    return $RestartRequired
}

function Install-ContainerPackages {
    param([string[]]$Packages)

    Initialize-Scoop
    Add-ScoopBucketIfAbsent -BucketName "extras"
    Write-Host "Installing container tools declared in [containers.default.os.*]..." -ForegroundColor Cyan
    if ($Review) {
        foreach ($Package in $Packages) {
            Confirm-DevRecipeReviewAction -Command "scoop install $Package" -Privilege "user" -Source "Scoop package $Package" -Effect "install selected container raw ID"
            Invoke-Scoop -Arguments @("install", $Package)
        }
    } else {
        Confirm-DevRecipeReviewAction -Command "scoop install $($Packages -join ' ')" -Privilege "user" -Source "Scoop packages" -Effect "install selected container raw IDs"
        Invoke-Scoop -Arguments (@("install") + $Packages)
    }
}

function Invoke-ContainerInstallation {
    param(
        [ValidateSet("Auto", "WSL", "HyperV")]
        [string]$Provider,
        [bool]$CreateDockerAlias,
        [string[]]$Packages
    )

    if (Test-IsAdministrator) {
        throw "Run this recipe from a normal PowerShell session. It requests UAC only for Windows features and installs Scoop in your user profile."
    }
    $ExistingMachines = Get-ExistingPodmanMachines
    if ($ExistingMachines.Count -gt 0) {
        Write-Host "Existing Podman machine detected: $($ExistingMachines -join ', ')." -ForegroundColor Yellow
        Write-Host "No provider, package, or alias is changed. Manage this existing environment with its current owner."
        & podman machine list
        return
    }
    $ExistingWslPodmanDistributions = Get-ExistingWslPodmanDistributions
    if ($ExistingWslPodmanDistributions.Count -gt 0) {
        Write-Host "WSL 2 distribution with Podman detected: $($ExistingWslPodmanDistributions -join ', ')." -ForegroundColor Yellow
        Write-Host "No provider, package, or alias is changed. Use or migrate this existing environment explicitly."
        return
    }

    $SelectedProvider = Resolve-ContainerProvider -Provider $Provider
    $EscapedScriptPath = $PSCommandPath.Replace('"', '`"')
    $EscapedUserProfile = $env:USERPROFILE.Replace('"', '`"')
    Confirm-ContainerFeaturePlan -Provider $SelectedProvider
    $ElevationArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$EscapedScriptPath`" -ContainerFeatureSetupOnly -ContainerProvider $SelectedProvider -ContainerTargetUserProfile `"$EscapedUserProfile`""
    try {
        Confirm-DevRecipeReviewAction -Command "Start-Process powershell.exe -Verb RunAs $ElevationArguments" -Privilege "elevated" -Source $PSCommandPath -Effect "launch the narrowly scoped Windows feature setup"
        $ElevatedProcess = Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $ElevationArguments -Wait -PassThru -ErrorAction Stop
    } catch {
        if ($_.Exception.NativeErrorCode -eq 1223) {
            Write-Host "UAC elevation cancelled: container installation skipped." -ForegroundColor Yellow
            return
        }
        throw
    }
    if ($ElevatedProcess.ExitCode -eq 3010) {
        Write-Host "Restart Windows, then run this recipe again with -Containers. No container package was installed." -ForegroundColor Yellow
        return
    }
    if ($ElevatedProcess.ExitCode -ne 0) {
        exit $ElevatedProcess.ExitCode
    }

    Install-ContainerPackages -Packages $Packages
    if ($CreateDockerAlias) {
        Enable-DockerCompatibilityAlias
    }
    Write-Host "Compose is available through 'podman compose' via docker-compose." -ForegroundColor Green
    Write-Host "Create one machine with 'podman machine init --now --provider $($SelectedProvider.ToLowerInvariant())', then run 'podman machine start'." -ForegroundColor Green
}

function Get-RequestedRemovalIds {
    param([string[]]$Values)

    $Ids = @()
    foreach ($Value in @($Values)) {
        foreach ($Candidate in ($Value -split ',')) {
            $Id = $Candidate.Trim()
            if ([string]::IsNullOrWhiteSpace($Id)) {
                Stop-Usage "-Uninstall cannot contain an empty value."
            }
            $AlreadyRequested = $false
            foreach ($ExistingId in $Ids) {
                if ([string]::Equals($ExistingId, $Id, [System.StringComparison]::Ordinal)) {
                    $AlreadyRequested = $true
                    break
                }
            }
            if (-not $AlreadyRequested) { $Ids += $Id }
        }
    }
    return @($Ids)
}

function Resolve-RemovalPlan {
    param(
        [object[]]$Entries,
        [string[]]$Ids
    )

    $Plan = @()
    foreach ($Id in $Ids) {
        $Candidates = @($Entries | Where-Object {
            [string]::Equals([string]$_.Name, $Id, [System.StringComparison]::Ordinal)
        })
        if ($Candidates.Count -eq 0) {
            throw "Removal refused: '$Id' is not declared in the selected profiles."
        }
        if ($Candidates.Count -gt 1) {
            throw "Removal refused: '$Id' is declared more than once; select a more specific profile."
        }
        $Plan += $Candidates[0]
    }
    return @($Plan)
}

function Show-RemovalPlan {
    param(
        [object[]]$Plan,
        [bool]$Confirmed
    )

    Write-Host "`n--- REMOVAL PLAN ---" -ForegroundColor Cyan
    @(
        foreach ($Entry in $Plan) {
            [PSCustomObject]@{
                Provider = Get-ProviderLabel -Entry $Entry
                Identifier = $Entry.Name
                Version = $Entry.Version
            }
        }
    ) | Format-Table -AutoSize | Out-Host
    if (-not $Confirmed) {
        Write-Host "Plan only. Add -Yes to execute these exact removals."
    }
    Write-Host "A present ID does not prove DevRecipe installed it: this action can remove a declared ID installed by someone else."
    Write-Host "No configuration, Scoop bootstrap, bucket, container, Windows feature, or global clean-up is removed."
}

function Test-RemovalPreconditions {
    param([object[]]$Plan)

    $ScoopPlan = @($Plan | Where-Object { $_.Type -eq "packages" })
    $MisePlan = @($Plan | Where-Object { $_.Type -ne "packages" })
    if ($ScoopPlan.Count -gt 0) {
        $ScoopInventory = Get-ScoopInventory
        if ($ScoopInventory.State -ne "ready") {
            throw "Scoop inventory is unavailable or ambiguous; no removal."
        }
        foreach ($Entry in $ScoopPlan) {
            if (-not (Test-ExactInventoryId -Ids $ScoopInventory.PackageIds -Expected $Entry.Name)) {
                throw "Scoop does not list '$($Entry.Name)'; no removal."
            }
        }
    }
    if ($MisePlan.Count -gt 0) {
        $MiseInventory = Get-MiseInventory
        foreach ($Entry in $MisePlan) {
            if ((Get-MiseEntryMatch -Inventory $MiseInventory -Entry $Entry).Status -ne "installed") {
                throw "Mise does not list '$($Entry.Name)@$($Entry.Version)'; no removal."
            }
        }
    }
}

function Invoke-RemovalPlan {
    param([object[]]$Plan)

    # Remove runtime/tool specs first so uninstalling Scoop's mise package cannot block them.
    foreach ($Entry in @($Plan | Where-Object { $_.Type -ne "packages" })) {
        Confirm-DevRecipeReviewAction -Command "mise uninstall $($Entry.Name)@$($Entry.Version)" -Privilege "user" -Source "Mise runtime store" -Effect "remove the exact declared Mise spec"
        Invoke-Mise -Arguments @("uninstall", "$($Entry.Name)@$($Entry.Version)")
    }
    foreach ($Entry in @($Plan | Where-Object { $_.Type -eq "packages" })) {
        Confirm-DevRecipeReviewAction -Command "scoop uninstall $($Entry.Name)" -Privilege "user" -Source "Scoop package" -Effect "remove the exact declared raw ID"
        Invoke-Scoop -Arguments @("uninstall", $Entry.Name)
    }
}

if ($ContainerFeatureSetupOnly) {
    if (-not (Test-DevRecipeManifest -ManifestPath $TomlPath)) {
        exit 2
    }
    $RestartRequired = Invoke-ContainerFeatureSetup -Provider $ContainerProvider -TargetUserProfile $ContainerTargetUserProfile
    if ($RestartRequired) {
        Write-Host "Restart Windows, then run this recipe again with -Containers before installing Podman." -ForegroundColor Yellow
        exit 3010
    }
    exit 0
}

$RequestedRemovalIds = Get-RequestedRemovalIds -Values $Uninstall
$HasUninstall = $RequestedRemovalIds.Count -gt 0
# Every Windows installation plan, including DryRun, Review, and Containers, preflights before continuing.
$RunInstallationPreflight = (-not ($Validate -or $List -or $Status -or $HasUninstall)) -and (-not $SkipPreflight)
$ReadOnlyModes = @()
if ($Validate) { $ReadOnlyModes += "Validate" }
if ($List) { $ReadOnlyModes += "List" }
if ($Status) { $ReadOnlyModes += "Status" }
if ($HasUninstall) { $ReadOnlyModes += "Uninstall" }
if ($ReadOnlyModes.Count -gt 1) {
    Stop-Usage "Choose only one mode: -Validate, -List, -Status, or -Uninstall."
}
if ($DryRun -and ($Validate -or $List -or $Status -or $HasUninstall)) {
    Stop-Usage "-DryRun cannot be combined with another mode."
}
if ($Preflight -and ($Validate -or $List -or $Status -or $HasUninstall)) {
    Stop-Usage "-Preflight is limited to installation or -DryRun."
}
if ($Review -and ($Validate -or $List -or $Status -or ($HasUninstall -and -not $Yes))) {
    Stop-Usage "-Review is limited to installation or removal confirmed with -Yes."
}
if ($Review -and $DryRun) {
    Stop-Usage "-Review cannot be combined with -DryRun."
}
if ($Yes -and -not $HasUninstall) {
    Stop-Usage "-Yes requires -Uninstall."
}
if ($Containers -and ($Validate -or $List -or $Status -or $HasUninstall)) {
    Stop-Usage "-Containers is compatible only with installation or -DryRun."
}
if ($EnableDockerAlias -and -not $Containers) {
    Stop-Usage "-EnableDockerAlias requires -Containers."
}
if ($PSBoundParameters.ContainsKey("ContainerProvider") -and -not $Containers) {
    Stop-Usage "-ContainerProvider requires -Containers."
}

if (-not (Test-DevRecipeManifest -ManifestPath $TomlPath)) {
    exit 2
}
if ($Validate) {
    Write-Host "Valid manifest: $(Split-Path $TomlPath -Leaf) (DevRecipe v2 contract)." -ForegroundColor Green
    exit 0
}
if ($Containers) {
    $ContainerPackages = @(Get-ContainerPackages)
    $ContainerEntries = @(
        foreach ($Package in $ContainerPackages) {
            [PSCustomObject]@{ Type = "packages"; Provider = "os"; Name = $Package; Version = "latest" }
        }
    )
    if ($RunInstallationPreflight) {
        $PreflightResult = Invoke-DevRecipePreflight -Entries $ContainerEntries
        if ($PreflightResult.ExitCode -ne 0) { exit $PreflightResult.ExitCode }
        $ContainerPackages = @($ContainerEntries | Where-Object { -not (Test-DevRecipePreflightExcluded -Entry $_) } | ForEach-Object Name)
        if (-not $DryRun) {
            Show-ContainerDryRunPlan -Packages $ContainerPackages -Provider $ContainerProvider -DryRun $false
        }
    }
    if ($ContainerPackages.Count -eq 0) {
        Write-Host "No container actions remain after preflight; no changes were made." -ForegroundColor Yellow
        exit 0
    }
    if ($DryRun) {
        Show-ContainerDryRunPlan -Packages $ContainerPackages -Provider $ContainerProvider -DryRun $true
        exit 0
    }
    if ($Review) {
        Invoke-DevRecipe-Review
    }
    Invoke-ContainerInstallation -Provider $ContainerProvider -CreateDockerAlias $EnableDockerAlias -Packages $ContainerPackages
    Complete-DevRecipeReview
    exit 0
}

$Content = Get-Content -LiteralPath $TomlPath -Raw
$DeclaredBuckets = @(Get-TomlManifestBuckets -Toml $Content)
$SelectedProfiles = @(Resolve-Profiles -Requested $Profiles)
$SelectedEntries = @(
    Get-TomlManifestEntries -Toml $Content | Where-Object {
        $_.Profile -in $SelectedProfiles -and -not [string]::IsNullOrWhiteSpace($_.Version)
    }
)
if ($SelectedEntries.Count -eq 0) {
    throw "No active package or Mise tool exists for the selected profiles."
}

if ($List) {
    Show-ManifestList -Entries $SelectedEntries
    exit 0
}
if ($Status) {
    Show-ProviderStatus -Entries $SelectedEntries
    exit 0
}
if ($HasUninstall) {
    $RemovalPlan = Resolve-RemovalPlan -Entries $SelectedEntries -Ids $RequestedRemovalIds
    Show-RemovalPlan -Plan $RemovalPlan -Confirmed $Yes
    if ($Yes) {
        if ($Review) { Invoke-DevRecipe-Review }
        Test-RemovalPreconditions -Plan $RemovalPlan
        Invoke-RemovalPlan -Plan $RemovalPlan
        Complete-DevRecipeReview
    }
    exit 0
}

$InstallEntries = @($SelectedEntries)
$SelectedMiseEntries = @($SelectedEntries | Where-Object { $_.Type -in @("runtimes", "tools") -and $_.Provider -eq "mise" })
$OsEntries = @($InstallEntries | Where-Object { $_.Type -eq "packages" })
$MiseEntries = @($InstallEntries | Where-Object { $_.Type -in @("runtimes", "tools") -and $_.Provider -eq "mise" })
if ($RunInstallationPreflight) {
    $PreflightResult = Invoke-DevRecipePreflight -Entries $InstallEntries
    if ($PreflightResult.ExitCode -ne 0) { exit $PreflightResult.ExitCode }
    $InstallEntries = @($InstallEntries | Where-Object { -not (Test-DevRecipePreflightExcluded -Entry $_) })
    $OsEntries = @($InstallEntries | Where-Object { $_.Type -eq "packages" })
    $MiseEntries = @($InstallEntries | Where-Object { $_.Type -in @("runtimes", "tools") -and $_.Provider -eq "mise" })
    if (-not $DryRun) {
        Show-DryRunPlan -OsEntries $OsEntries -MiseEntries $MiseEntries -DeclaredBuckets $DeclaredBuckets -ConfigureMiseShims ($SelectedMiseEntries.Count -gt 0) -DryRun $false
    }
}
if ($DryRun) {
    Show-DryRunPlan -OsEntries $OsEntries -MiseEntries $MiseEntries -DeclaredBuckets $DeclaredBuckets -ConfigureMiseShims ($SelectedMiseEntries.Count -gt 0) -DryRun $true
    exit 0
}

if ($Review) { Invoke-DevRecipe-Review }

Write-Host "Selected profiles: $($SelectedProfiles -join ', ')" -ForegroundColor Cyan
Initialize-Scoop
if ($OsEntries.Count -gt 0) {
    $BucketsToAdd = if ($DeclaredBuckets.Count -gt 0) {
        $DeclaredBuckets
    } else {
        @([PSCustomObject]@{ Name = "extras"; Url = "" })
    }
    foreach ($Bucket in $BucketsToAdd) {
        Add-ScoopBucketIfAbsent -BucketName $Bucket.Name -BucketUrl $Bucket.Url
    }
    if ($Review) {
        foreach ($Entry in $OsEntries) {
            Confirm-DevRecipeReviewAction -Command "scoop install $($Entry.Name)" -Privilege "user" -Source "Scoop package $($Entry.Name)" -Effect "install selected package raw ID"
            Invoke-Scoop -Arguments @("install", $Entry.Name)
        }
    } else {
        Confirm-DevRecipeReviewAction -Command "scoop install $((@($OsEntries | ForEach-Object Name) -join ' '))" -Privilege "user" -Source "Scoop packages" -Effect "install selected package raw IDs"
        Invoke-Scoop -Arguments (@("install") + @($OsEntries | ForEach-Object Name))
    }
}
if ($MiseEntries.Count -gt 0) {
    if ($null -eq (Get-MiseCommand)) {
        Confirm-DevRecipeReviewAction -Command "scoop install mise" -Privilege "user" -Source "Scoop package mise" -Effect "install the Mise provider"
        Invoke-Scoop -Arguments @("install", "mise")
    }
    if ($Review) {
        foreach ($Entry in $MiseEntries) {
            $Spec = "$($Entry.Name)@$($Entry.Version)"
            Confirm-DevRecipeReviewAction -Command "mise install $Spec" -Privilege "user" -Source "Mise runtime store" -Effect "install selected exact Mise spec"
            Invoke-Mise -Arguments @("install", $Spec)
        }
    } else {
        Confirm-DevRecipeReviewAction -Command "mise install $((@($MiseEntries | ForEach-Object { "$($_.Name)@$($_.Version)" }) -join ' '))" -Privilege "user" -Source "Mise runtime store" -Effect "install selected exact Mise specs"
        Invoke-Mise -Arguments (@("install") + @($MiseEntries | ForEach-Object { "$($_.Name)@$($_.Version)" }))
    }
}
if ($SelectedMiseEntries.Count -gt 0 -and $null -ne (Get-MiseCommand)) {
    Confirm-DevRecipeReviewAction -Command "mise reshim" -Privilege "user" -Source "Mise runtime store" -Effect "generate shims for installed Mise tools"
    Invoke-Mise -Arguments @("reshim")
    Ensure-DevRecipeMiseShimsUserPath
    Enable-MiseShellShimsActivation
    Ensure-DevRecipeCommandProcessorAutoRun
}
Write-Host "`n--- SUBMITTED ENTRIES ---" -ForegroundColor Cyan
Show-ManifestList -Entries $InstallEntries
Complete-DevRecipeReview
