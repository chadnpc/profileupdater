#!/usr/bin/env pwsh
using namespace Microsoft.PowerShell
using namespace System.Collections.Generic
using namespace System.Management.Automation

#region    Classes
# $global:profile_initialized = $false

class ProfileCfg {
  [bool] $UseOmp = $true
  [bool] $UseZoxide = $true
  [ExecutionPolicy] $ExecutionPolicy = "RemoteSigned"
  static [string] $scriptroot = (Get-Item $PROFILE).Directory.FullName
  [List[Job]] $jobs = [List[Job]]::new()

  ProfileCfg() {
    [void][ProfileCfg]::From([ProfileCfg]::GetConfigFile(), [ref]$this)
  }
  ProfileCfg([IO.FileInfo]$psd) {
    [void][ProfileCfg]::From($psd, [ref]$this)
  }
  static [ProfileCfg] Create() {
    return [ProfileCfg]::From([ProfileCfg]::GetConfigFile(), [ref][ProfileCfg]::new())
  }
  static [ProfileCfg] Create([IO.FileInfo]$psd) {
    return [ProfileCfg]::From($psd, [ref][ProfileCfg]::new())
  }
  static hidden [ProfileCfg] From([IO.FileInfo]$psd, [ref]$o) {
    $txt = [IO.File]::ReadAllText($psd.FullName)
    if ([string]::IsNullOrWhiteSpace($txt)) {
      throw [InvalidOperationException]::new("Cannot import from empty data file $psd")
    }
    $obj = Import-PowerShellDataFile -Path $psd
    $o.Value.PsObject.Properties.Add([psnoteproperty]::new("omp_json", [IO.Path]::Combine([ProfileCfg]::scriptroot, "alain.omp.json")))
    $obj.Keys.ForEach({ $o.Value.$_ ? ($o.Value.$_ = $obj.$_) : ($o.Value.PsObject.Properties.Add([psnoteproperty]::new($_, $obj.$_))) })
    return $o.Value
  }
  static [IO.FileInfo] GetConfigFile() {
    return [IO.Path]::Combine([ProfileCfg]::scriptroot, "PowerShell_profile_config.psd1")
  }
  [void] Initialize() {
    if ((Get-Variable profile_initialized -ValueOnly -ea Ignore )) { return }
    $initSession = [ref]$this
    $this.jobs.Add((Start-ThreadJob -Name "omp_init" -ScriptBlock { $s = $using:initSession; return $s.value.SetOmpConfig() } -Verbose:$false))
    $this.ResolveDependencies()
    $this.SetVariables()
    $this.SetZoxide()
    $this.SetPSReadLine()
    $this.SetAliases()
    $this.SetFzfOptions()
  }
  [string] SetOmpConfig() {
    if (!$this.UseOmp) { return '' }
    $omp_json = $this.omp_json;
    $data_dir = $this.getOmpDatadir()
    $omp_init_ps1_file = (Get-Variable -ValueOnly IsWindows) ? $(
      [IO.Path]::Exists($data_dir) ? [string](Get-Item -ea Ignore -Path ("$data_dir/init.*.ps1")) : (& oh-my-posh init powershell --config="$omp_json" --print).Substring(3).Split("'")[0]
    ): $(
      $f = [IO.Path]::GetTempPath() + "init." + [Guid]::NewGuid().ToString() + ".ps1";
      [IO.File]::WriteAllText($f, (& oh-my-posh init powershell --config="$omp_json" --print))
      $f
    )

    if (![string]::IsNullOrWhiteSpace($omp_init_ps1_file)) {
      if ([IO.File]::Exists($omp_json)) {
        $l = [IO.File]::ReadAllLines($omp_init_ps1_file)
        if (!$l[0].StartsWith('$VerbosePreference = "silentlyContinue"')) {
          $l[0] = '$VerbosePreference = "silentlyContinue"' + "`n" + $l[0]
        }
        $t = [string]::Join("`n", $l).TrimEnd()
        if ($t.EndsWith("} | Import-Module -Global")) { $t += ' -Verbose:$false' }
        [IO.File]::WriteAllText($omp_init_ps1_file, $t)
      } else {
        Write-Error "Cannot find $omp_json!"
      }
    } else { write-waning "Using omp is disabled" }

    return $omp_init_ps1_file
  }
  [void] ResolveDependencies() {
    Set-Variable VerbosePreference -Value "silentlyContinue" -Scope Global
    Set-Variable WarningPreference -Value "silentlyContinue" -Scope Global
    if (!(Get-Command -Name 'oh-my-posh' -Type Application -ErrorAction SilentlyContinue)) {
      (Get-Variable IsWindows).Value ? (winget install --id=JanDeDobbeleer.OhMyPosh -e) : $null
    }
    if (!(Get-Command -Name 'fzf' -Type Application -ErrorAction SilentlyContinue)) {
      (Get-Variable IsWindows).Value ? (winget install --id=junegunn.fzf -e) : $null
    }
  }
  [void] SetFzfOptions() {
    if (!(Get-Variable IsWindows).Value) {
      Import-Module PSFzf -Verbose:$false
      Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r' -Verbose:$false
    }
  }
  [void] SetZoxide() {
    if ($this.UseZoxide) {
      if (!(Get-Command -Name 'zoxide' -Type Application -ErrorAction SilentlyContinue)) {
        (Get-Variable IsWindows).Value ? (winget install --id=ajeetdsouza.zoxide -e) : $null
      }
      Invoke-Command -ScriptBlock ([ScriptBlock]::Create([string]::join("`n", @(& zoxide init powershell)))) -Verbose:$false
    }
  }
  [void] SetAliases() {
    $a = $this.aliases.GetEnumerator() | Select-Object @{l = 'name'; e = { $_.Key } }, @{l = 'value'; e = { $_.value.InvokeReturnAsIs().Invoke() } }
    $a.Where({ ![string]::IsNullOrWhiteSpace($_.value) }).ForEach({
        # [scriptblock]::Create("Set-Alias -Name $($_.name) -Value $($_.value) -Scope Global -Force").Invoke()
        Set-Alias -Name $_.name -Value $_.value -Scope Global -Force
      }
    )
  }
  [void] SetVariables() {
    Set-Variable profile_initialized -Value $true -Scope Global
    # ----- Environment variables -----
    $null = Start-ThreadJob -Name "SetVariables" -ScriptBlock {
      if ((Get-Variable IsWindows).Value) {
        Set-Env GIT_SSH -Scope Machine -Value "C:\Windows\system32\OpenSSH\ssh.exe" -Verbose:$false
        Set-Env GIT_SSH_COMMAND -Scope Machine -Value "C:\Windows\system32\OpenSSH\ssh.exe -o ControlMaster=auto -o ControlPersist=60s" -Verbose:$false
      }
      Set-Env PATH -Scope Machine -Value ([string]::Join([IO.Path]::PathSeparator, (Get-Item Env:/PATH).value, [IO.Path]::Combine((Get-Variable HOME).value, ".dotnet/tools"))) -Verbose:$false

      if ([IO.Path]::Exists("$((Get-Item Env:/USERPROFILE).value)/.pyenv/bin")) { cliHelper.env\Set-Env -Name PATH -Scope 'Machine' -Value ('{0}{1}{2}' -f (Get-Item Env:/PATH).value, [IO.Path]::PathSeparator, "$((Get-Item Env:/USERPROFILE).value)/.pyenv/bin") }

      # $((gi Env:/USERPROFILE).value)/.local/bin/env
      if ([IO.Path]::Exists("$((Get-Item Env:/USERPROFILE).value)/.local/bin/")) {
        cliHelper.env\Set-Env -Name LOCAL_BIN -Scope 'Machine' -Value "$((Get-Item Env:/USERPROFILE).value)/.local/bin/"
        cliHelper.env\Set-Env -Name PATH -Scope 'Machine' -Value ('{0}{1}{2}' -f (Get-Item Env:/PATH).value, [IO.Path]::PathSeparator, "$((Get-Item Env:/USERPROFILE).value)/.local/bin/")
      }

      # $((gi Env:/USERPROFILE).value)/.local/share/vdhcoapp
      if ([IO.Path]::Exists("$((Get-Item Env:/USERPROFILE).value)/.local/share/vdhcoapp/")) {
        cliHelper.env\Set-Env -Name VDHC_PATH -Scope 'Machine' -Value "$((Get-Item Env:/USERPROFILE).value)/.local/share/vdhcoapp/"
        cliHelper.env\Set-Env -Name PATH -Scope 'Machine' -Value ('{0}{1}{2}' -f (Get-Item Env:/PATH).value, [IO.Path]::PathSeparator, "$((Get-Item Env:/USERPROFILE).value)/.local/share/vdhcoapp/")
      }

      # curl -sSLf https://github.com/aclap-dev/vdhcoapp/releases/latest/download/install.sh | bash
      if ([IO.Path]::Exists("$((Get-Item Env:/USERPROFILE).value)/.bun")) {
        cliHelper.env\Set-Env -Name BUN_INSTALL -Scope 'Machine' -Value "$((Get-Item Env:/USERPROFILE).value)/.bun"
        cliHelper.env\Set-Env -Name PATH -Scope 'Machine' -Value ('{0}{1}{2}' -f (Get-Item Env:/PATH).value, [IO.Path]::PathSeparator, "$((Get-Item Env:/USERPROFILE).value)/.bun/bin")
      }
    }
  }
  [void] SetPSReadLine() {
    # Enable-PowerType
    Set-PSReadLineOption -BellStyle None -Verbose:$false
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -Colors @{ InlinePrediction = '#2F7004' }
    Set-PSReadLineOption -PredictionViewStyle ListView

    Set-PSReadLineKeyHandler -Key Ctrl+Shift+b `
      -BriefDescription BuildCurrentDirectory `
      -LongDescription "Build the current directory" `
      -ScriptBlock {
      [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
      [Microsoft.PowerShell.PSConsoleReadLine]::Insert("dotnet build")
      [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  }
  [void] SetPrompt() {
    # run by an externl function only when initialize was done
    if ($this.jobs.Where({ $_.Name -eq "omp_init" }).Count -ne 0) {
      $timer = [System.Diagnostics.Stopwatch]::StartNew() # lets wait for 10 seconds max, if not then someting went wrong
      while ($this.jobs.Where({ $_.Name -eq "omp_init" }).State -ne "Completed" -and $timer.Elapsed.Seconds -lt 10) {
        #a do nothing loop
      }; $timer.Stop()
      Invoke-Command -ScriptBlock ([ScriptBlock]::Create([IO.File]::ReadAllText(($this.jobs.Where({ $_.Name -eq "omp_init" }) | Receive-Job)))) -Verbose:$false
    } else {
      Write-Error "Please run initialize() first"
    }
    if ((Get-Command fastfetch -Type Application -ea Ignore)) {
      fastfetch --config os
    }
    $global:VerbosePreference = $this.VerbosePreference
    $global:WarningPreference = $this.WarningPreference
  }
  [string] getOmpDatadir() {
    $p = Join-Path ((Get-Variable IsWindows).Value ? $env:LOCALAPPDATA : $ENV:XDG_DATA_DIRS.Split([IO.Path]::PathSeparator).where({ $_ -like "*local*" })[0]) -ChildPath "/oh-my-posh/"
    if (!(Get-Variable IsWindows).Value) { return '' }; if (![IO.Path]::Exists($p)) { New-Item $p -ItemType Directory -Force }
    return $p
  }
}

class ProfileUpdater : PsModulebase {
  [string]$GitHubUsername = 'chadnpc'
  [string]$GistFileName = 'Microsoft.PowerShell_profile.ps1'
  [string]$ConfigFileName = 'PowerShell_profile_config.psd1'
  [int]$BackupCount = 3
  [string]$Token

  ProfileUpdater() {}
  [void] Update([string]$GistId) {
    $this.Update($GistId, $false, $false)
  }
  [void] Update([string]$GistId, [bool]$Force, [bool]$Preview) {
    # Initialize variables
    $script:Headers = @{
      'User-Agent' = 'PowerShell-Profile-Updater/1.0'
      'Accept'     = 'application/vnd.github.v3+json'
    }

    # Add authentication if token is provided
    if ($this.Token) {
      $script:Headers['Authorization'] = "token $($this.Token)"
    }

    Write-Host "🔄 PowerShell Profile Updater" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    $P = Get-Variable -ValueOnly PROFILE
    $profileDir = Split-Path $P -Parent
    $configPath = Join-Path $profileDir $this.ConfigFileName
    try {
      # Ensure profile directory exists
      if (!(Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        Write-Host "✅ Created profile directory: $profileDir" -ForegroundColor Green
      }

      # Create profile file if it doesn't exist
      if (!(Test-Path $P)) {
        New-Item -ItemType File -Path $P -Force | Out-Null
        Write-Host "✅ Created profile file: $P" -ForegroundColor Green
      }

      # Get current profile content and version
      $currentContent = Get-Content $P -Raw -ErrorAction SilentlyContinue
      $currentVersion = $this.GetProfileVersion($currentContent)

      Write-Host "📍 Current profile version: $currentVersion" -ForegroundColor Yellow

      # Get gist content (now returns hashtable with multiple files)
      $gistFiles = $this.GetGistContent($this.GitHubUsername, $GistId, @($this.GistFileName, $this.ConfigFileName))

      if (!$gistFiles -or !$gistFiles[$this.GistFileName]) {
        throw "Failed to retrieve profile content from gist"
      }

      $gistContent = $gistFiles[$this.GistFileName]

      # Get remote version
      $remoteVersion = $this.GetProfileVersion($gistContent)
      Write-Host "🌐 Remote profile version: $remoteVersion" -ForegroundColor Yellow

      # Compare versions and content for profile
      $versionComparison = $this.CompareVersions($currentVersion, $remoteVersion)
      $contentComparison = $this.CompareContent($currentContent, $gistContent)

      # Check if remote version is older than current version
      $currentVer = [version]$currentVersion
      $remoteVer = [version]$remoteVersion
      $isRemoteOlder = $remoteVer -lt $currentVer

      # Only update if conditions are met
      $shouldUpdate = $Force -or $versionComparison -or (($currentVer -eq $remoteVer) -and $contentComparison)

      if ($isRemoteOlder -and !$Force) {
        Write-Host "⚠️  Remote version ($remoteVersion) is older than current version ($currentVersion). Skipping update." -ForegroundColor Yellow
        Write-Host "💡 Use -Force parameter to downgrade if needed." -ForegroundColor Gray
        return
      }

      if (!$shouldUpdate) {
        Write-Host "✅ Profile is already up to date!" -ForegroundColor Green

        # Still check for config file even if profile doesn't need update
        $this.HandleConfigFile($gistFiles, $configPath)
        return
      }

      # Preview mode
      if ($Preview) {
        $this.ShowChangesPreview($currentContent, $gistContent)
        return
      }

      # Confirm update unless forced
      if (!$Force) {
        if ($versionComparison) {
          $confirmation = Read-Host "🤔 Update profile from version $currentVersion to $remoteVersion ? (Y/n)"
        } elseif ($currentVer -eq $remoteVer) {
          $confirmation = Read-Host "🤔 Profile content has changed (same version $currentVersion). Update? (Y/n)"
        } else {
          $confirmation = Read-Host "🤔 Update profile from version $currentVersion to $remoteVersion ? (Y/n)"
        }

        if ($confirmation -eq 'n' -or $confirmation -eq 'N') {
          Write-Host "❌ Update cancelled by user" -ForegroundColor Yellow
          return
        }
      }

      # Create backup
      $this.BackupProfile($this.BackupCount)

      # Update profile
      Set-Content -Path $P -Value $gistContent -Encoding UTF8
      Write-Host "✅ Profile updated successfully!" -ForegroundColor Green

      # Handle config file
      $this.HandleConfigFile($gistFiles, $configPath)

      # Offer to reload profile
      $reload = Read-Host "🔄 Reload profile now? (Y/n)"
      if ($reload -ne 'n' -and $reload -ne 'N') {
        . $P
        Write-Host "✅ Profile reloaded!" -ForegroundColor Green
      }
    } catch {
      Write-Host "❌ Error updating profile: $($_.Exception.Message)" -ForegroundColor Red

      # Attempt to restore from backup if update failed
      $latestBackup = Get-ChildItem (Split-Path $P -Parent) -Filter "*.backup*" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

      if ($latestBackup) {
        $restore = Read-Host "🔄 Restore from latest backup? (Y/n)"
        if ($restore -ne 'n' -and $restore -ne 'N') {
          Copy-Item $latestBackup.FullName $P -Force
          Write-Host "✅ Profile restored from backup" -ForegroundColor Green
        }
      }
    }
  }
  [void] RunTests() {
    $this.RunTests($true)
  }
  [void] RunTests([bool]$interactive) {
    if (!$interactive) { $this.TestUpdate(); return }
    Write-Host "🚀 PowerShell Profile Updater Test Suite" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Choose an option:" -ForegroundColor Yellow
    Write-Host "1. Run tests" -ForegroundColor Green
    Write-Host "2. Show usage examples" -ForegroundColor Green
    Write-Host "3. Exit" -ForegroundColor Green

    $choice = Read-Host "`nEnter your choice (1-3)"

    switch ($choice) {
      "1" { $this.TestUpdate() }
      "2" { $this.ShowUsage() }
      "3" { Write-Host "👋 Goodbye!" -ForegroundColor Cyan }
      default { Write-Host "❌ Invalid choice" -ForegroundColor Red }
    }
  }
  [void] ShowUsage () {
    # .SYNOPSIS
    # Shows usage examples for the PowerShell Profile Updater
    Write-Host "📖 PowerShell Profile Updater - Usage Examples" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan

    $examples = @(
      @{
        Title       = "Basic Update (Public Gist)"
        Command     = "Update-PowerShellProfile"
        Description = "Updates from default user 'chadnpc' public gist"
      },
      @{
        Title       = "Preview Changes"
        Command     = "Update-PowerShellProfile -Preview"
        Description = "Shows what would change without applying updates"
      },
      @{
        Title       = "Force Update"
        Command     = "Update-PowerShellProfile -Force"
        Description = "Updates without confirmation prompts"
      },
      @{
        Title       = "Specific User"
        Command     = "Update-PowerShellProfile -GitHubUsername 'yourusername'"
        Description = "Updates from a specific GitHub user's gist"
      },
      @{
        Title       = "Specific Gist ID"
        Command     = "Update-PowerShellProfile -GistId 'abc123def456'"
        Description = "Updates from a specific gist by ID"
      },
      @{
        Title       = "With GitHub Token"
        Command     = "Update-PowerShellProfile -Token 'ghp_xxxxxxxxxxxx'"
        Description = "Uses GitHub token for private gists or rate limit avoidance"
      },
      @{
        Title       = "Custom Settings"
        Command     = "Update-PowerShellProfile -GistFileName 'profile.ps1' -BackupCount 5"
        Description = "Custom filename and backup retention settings"
      }
    )

    foreach ($example in $examples) {
      Write-Host "`n🔹 $($example.Title)" -ForegroundColor Yellow
      Write-Host "   $($example.Command)" -ForegroundColor Green
      Write-Host "   $($example.Description)" -ForegroundColor Gray
    }

    Write-Host "`n📋 Available Parameters:" -ForegroundColor Cyan
    Write-Host "   -GitHubUsername  : GitHub username (default: 'chadnpc')" -ForegroundColor Gray
    Write-Host "   -GistId          : Specific gist ID" -ForegroundColor Gray
    Write-Host "   -GistFileName    : Profile filename in gist" -ForegroundColor Gray
    Write-Host "   -Force           : Skip confirmations" -ForegroundColor Gray
    Write-Host "   -Preview         : Show changes without applying" -ForegroundColor Gray
    Write-Host "   -BackupCount     : Number of backups to keep (default: 3)" -ForegroundColor Gray
    Write-Host "   -Token           : GitHub personal access token" -ForegroundColor Gray
  }
  [void] TestUpdate() {
    # .DESCRIPTION
    #   Runs various tests to ensure the profile updater works correctly
    Write-Host "🧪 Testing PowerShell Profile Updater" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan

    # Test 1: Check if function is loaded
    Write-Host "`n[+] 1. Testing function availability..." -ForegroundColor Yellow
    if (Get-Command Update-PowerShellProfile -ErrorAction SilentlyContinue) {
      Write-Host "✅ Update-PowerShellProfile function is available" -ForegroundColor Green
    } else {
      Write-Host "❌ Update-PowerShellProfile function not found" -ForegroundColor Red
      return
    }

    # Test 2: Test helper functions
    Write-Host "`n[+] 2. Testing helper functions..." -ForegroundColor Yellow

    # Test version parsing
    $testContent = "`n# Version 1.2.3`n# This is a test profile`nWrite-Host 'Hello World'"

    $version = $this.GetProfileVersion($testContent)
    if ($version -eq "1.2.3") {
      Write-Host "✅ Version parsing works correctly" -ForegroundColor Green
    } else {
      Write-Host "❌ Version parsing failed. Expected '1.2.3', got '$version'" -ForegroundColor Red
    }

    # Test version comparison
    $isNewer = $this.CompareVersions("1.0.0", "1.1.0")
    if ($isNewer) {
      Write-Host "✅ Version comparison works correctly" -ForegroundColor Green
    } else {
      Write-Host "❌ Version comparison failed" -ForegroundColor Red
    }

    # Test 3: Test with preview mode (safe test)
    Write-Host "`n[+] 3. Testing preview mode..." -ForegroundColor Yellow
    try {
      Update-PowerShellProfile -Preview -GitHubUsername "chadnpc" -ErrorAction Stop
      Write-Host "✅ Preview mode executed successfully" -ForegroundColor Green
    } catch {
      Write-Host "⚠️  Preview mode test failed: $($_.Exception.Message)" -ForegroundColor Yellow
      Write-Host "   This might be due to network issues or gist not found" -ForegroundColor Gray
    }

    # Test 4: Check backup functionality
    Write-Host "`n[+] 4. Testing backup functionality..." -ForegroundColor Yellow

    if (Test-Path $(Get-Variable -ValueOnly PROFILE)) {
      try {
        $this.BackupProfile(1)

        $profileDir = Split-Path (Get-Variable -ValueOnly PROFILE) -Parent
        $profileName = Split-Path (Get-Variable -ValueOnly PROFILE) -Leaf
        $backups = Get-ChildItem $profileDir -Filter "$profileName.backup.*"

        if ($backups.Count -gt 0) {
          Write-Host "✅ Backup creation works correctly" -ForegroundColor Green

          # Clean up test backup
          $backups | Remove-Item -Force
          Write-Host "🧹 Cleaned up test backup" -ForegroundColor Gray
        } else {
          Write-Host "❌ Backup creation failed" -ForegroundColor Red
        }
      } catch {
        Write-Host "❌ Backup test failed: $($_.Exception.Message)" -ForegroundColor Red
      }
    } else {
      Write-Host "⚠️  No existing profile found to test backup functionality" -ForegroundColor Yellow
    }

    Write-Host "`n🎉 Testing completed!" -ForegroundColor Cyan
    Write-Host "`n💡 To test with your actual gist, run:" -ForegroundColor Blue
    Write-Host "   Update-PowerShellProfile -Preview" -ForegroundColor Gray
    Write-Host "`n💡 To perform an actual update, run:" -ForegroundColor Blue
    Write-Host "   Update-PowerShellProfile" -ForegroundColor Gray
  }
  # helper methods:
  [version] GetProfileVersion([string]$Content) {
    if ([string]::IsNullOrEmpty($Content)) {
      return "0.0.0"
    }

    if ($Content -match '# Version (?<Version>\d+\.\d+\.\d+)') {
      return $matches.Version
    }

    # Fallback to last modified date if no version found
    if ($Content -match '# Last Modified: (?<LastModified>\d{4}-\d{2}-\d{2})') {
      return "1.0.0"  # Assume version 1.0.0 if only date is found
    }

    return "0.0.0"
  }
  [bool] CompareVersions([string]$Current, [string]$Remote) {
    try {
      $currentVer = [version]$Current
      $remoteVer = [version]$Remote
      return $remoteVer -gt $currentVer
    } catch {
      # If version comparison fails, assume update is needed
      return $true
    }
  }
  [bool] CompareContent([string]$Current, [string]$Remote) {
    if ([string]::IsNullOrEmpty($Current) -and ![string]::IsNullOrEmpty($Remote)) {
      return $true
    }
    # Simple hash comparison
    $currentHash = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($Current)))).Hash
    $remoteHash = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($Remote)))).Hash

    return $currentHash -ne $remoteHash
  }
  [void] ShowChangesPreview([string]$Current, [string]$Remote) {
    Write-Host "`n📋 Profile Update Preview" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan

    if ([string]::IsNullOrEmpty($Current)) {
      Write-Host "Current profile is empty or doesn't exist" -ForegroundColor Yellow
      Write-Host "`nNew profile will contain:" -ForegroundColor Green
      Write-Host $Remote.Substring(0, [Math]::Min(500, $Remote.Length)) -ForegroundColor Gray
      if ($Remote.Length -gt 500) {
        Write-Host "... (truncated)" -ForegroundColor Gray
      }
    } else {
      # Simple diff-like comparison
      $currentLines = $Current -split "`n"
      $remoteLines = $Remote -split "`n"

      Write-Host "Lines in current profile: $($currentLines.Count)" -ForegroundColor Yellow
      Write-Host "Lines in remote profile: $($remoteLines.Count)" -ForegroundColor Yellow

      # Show first few lines of each for comparison
      Write-Host "`nFirst 10 lines of current profile:" -ForegroundColor Cyan
      $currentLines | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

      Write-Host "`nFirst 10 lines of remote profile:" -ForegroundColor Green
      $remoteLines | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }
  }
  [void] BackupProfile() {
    $this.BackupProfile(3)
  }
  [void] BackupProfile([int]$BackupCount) {
    $P = $(Get-Variable -ValueOnly PROFILE)
    if (!(Test-Path $P)) {
      return
    }

    $profileDir = Split-Path $P -Parent
    $profileName = Split-Path $P -Leaf
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = Join-Path $profileDir "$profileName.backup.$timestamp"

    Copy-Item $P $backupPath -Force
    Write-Host "📁 Created backup: $backupPath" -ForegroundColor Green

    # Clean up old backups
    $backups = Get-ChildItem $profileDir -Filter "$profileName.backup.*" |
      Sort-Object LastWriteTime -Descending

    if ($backups.Count -gt $BackupCount) {
      $backups | Select-Object -Skip $BackupCount | Remove-Item -Force
      Write-Host "🧹 Cleaned up old backups (keeping $BackupCount)" -ForegroundColor Gray
    }
  }
  [void] HandleConfigFile([hashtable]$GistFiles, [string]$ConfigPath) {
    if ($GistFiles.ContainsKey($this.ConfigFileName)) {
      if (!(Test-Path $ConfigPath)) {
        try {
          Set-Content -Path $ConfigPath -Value $GistFiles[$this.ConfigFileName] -Encoding UTF8
          Write-Host "✅ Downloaded config file: $($this.ConfigFileName)" -ForegroundColor Green
        } catch {
          Write-Host "⚠️  Failed to save config file: $($_.Exception.Message)" -ForegroundColor Yellow
        }
      } else {
        Write-Host "📋 Config file already exists, skipping download" -ForegroundColor Gray
      }
    } else {
      Write-Host "📋 Config file not found in gist, creatng default" -ForegroundColor Gray
      $this::ReadModuledata("ProfileUpdater").default_profile_config | xconvert Tostring |
        Set-Content -Path $ConfigPath -Encoding UTF8
    }
  }
  [hashtable] GetGistContent([string]$GitHubUsername, [string]$GistId, [string[]]$FileNames) {
    $gistUrl = ''
    $result = @{}

    try {
      # If specific gist ID is provided, use it directly
      if ($GistId) {
        $gistUrl = "https://api.github.com/gists/$GistId"
        Write-Host "🔍 Fetching gist by ID: $GistId" -ForegroundColor Yellow
      } else {
        # Search for gists by username
        Write-Host "🔍 Searching gists for user: $GitHubUsername" -ForegroundColor Yellow
        $gistsUrl = "https://api.github.com/users/$GitHubUsername/gists"

        # Try public gists first
        try {
          $gists = Invoke-RestMethod -Uri $gistsUrl -Headers $script:Headers -ErrorAction Stop -Verbose:$false

          # Find gist containing the primary file (profile)
          $targetGist = $gists | Where-Object {
            $_.files.PSObject.Properties.Name -contains $FileNames[0]
          } | Select-Object -First 1

          if (!$targetGist) {
            throw "No gist found containing file: $($FileNames[0])"
          }

          $gistUrl = $targetGist.url
          Write-Host "✅ Found gist: $($targetGist.id)" -ForegroundColor Green
        } catch {
          # If public search fails, prompt for authentication
          Write-Host "⚠️  Public gist search failed. Gist may be private." -ForegroundColor Yellow

          if (!$script:Headers.ContainsKey('Authorization')) {
            $this.Token = Read-Host "Enter GitHub token for private gist access (or press Enter to skip)" -AsSecureString
            if ($this.Token.Length -gt 0) {
              $tokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($this.Token))
              $script:Headers['Authorization'] = "token $tokenPlain"

              # Retry with authentication
              $gists = Invoke-RestMethod -Uri $gistsUrl -Headers $script:Headers -ErrorAction Stop -Verbose:$false
              $targetGist = $gists | Where-Object {
                $_.files.PSObject.Properties.Name -contains $FileNames[0]
              } | Select-Object -First 1

              if (!$targetGist) {
                throw "No gist found containing file: $($FileNames[0])"
              }

              $gistUrl = $targetGist.url
            } else {
              throw "Authentication required for private gist access"
            }
          }
        }
      }

      # Get the specific gist
      $gist = Invoke-RestMethod -Uri $gistUrl -Headers $script:Headers -ErrorAction Stop -Verbose:$false

      # Process each requested file
      foreach ($fileName in $FileNames) {
        $file = $gist.files.PSObject.Properties | Where-Object {
          $_.Name -eq $fileName -or ($fileName -eq $FileNames[0] -and $_.Name -like "*profile*")
        } | Select-Object -First 1

        if ($file) {
          Write-Host "📥 Downloading: $($file.Name)" -ForegroundColor Green

          # Get the raw content
          $rawUrl = $file.Value.raw_url
          $content = Invoke-RestMethod -Uri $rawUrl -Headers $script:Headers -ErrorAction Stop -Verbose:$false
          $result[$fileName] = $content
        } else {
          Write-Host "📋 File not found in gist: $fileName" -ForegroundColor Gray
        }
      }

      return $result
    } catch {
      Write-Error "Failed to get gist content: $($_.Exception.Message)"
      return @{}
    }
  }
}
#endregion Classes
# Types that will be available to users when they import the module.
$typestoExport = @(
  [ProfileUpdater], [ProfileCfg]
)
$TypeAcceleratorsClass = [PsObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
foreach ($Type in $typestoExport) {
  if ($Type.FullName -in $TypeAcceleratorsClass::Get.Keys) {
    $Message = @(
      "Unable to register type accelerator '$($Type.FullName)'"
      'Accelerator already exists.'
    ) -join ' - '
    "TypeAcceleratorAlreadyExists $Message" | Write-Debug
  }
}
# Add type accelerators for every exportable type.
foreach ($Type in $typestoExport) {
  $TypeAcceleratorsClass::Add($Type.FullName, $Type)
}
# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
  foreach ($Type in $typestoExport) {
    $TypeAcceleratorsClass::Remove($Type.FullName)
  }
}.GetNewClosure();

$scripts = @();
$Public = Get-ChildItem "$PSScriptRoot/Public" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
$scripts += Get-ChildItem "$PSScriptRoot/Private" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
$scripts += $Public

foreach ($file in $scripts) {
  try {
    if ([string]::IsNullOrWhiteSpace($file.fullname)) { continue }
    . "$($file.fullname)"
  } catch {
    Write-Warning "Failed to import function $($file.BaseName): $_"
    $host.UI.WriteErrorLine($_)
  }
}

$Param = @{
  Function = $Public.BaseName
  Cmdlet   = '*'
  Alias    = '*'
  Verbose  = $false
}
Export-ModuleMember @Param