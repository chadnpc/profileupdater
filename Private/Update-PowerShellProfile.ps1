class ProfileUpdater {
    [string]$GitHubUsername = 'chadnpc'
    [string]$GistFileName = 'Microsoft.PowerShell_profile.ps1'
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
            'Accept' = 'application/vnd.github.v3+json'
        }
        
        # Add authentication if token is provided
        if ($this.Token) {
            $script:Headers['Authorization'] = "token $($this.Token)"
        }
        
        Write-Host "🔄 PowerShell Profile Updater" -ForegroundColor Cyan
        Write-Host "================================" -ForegroundColor Cyan
        $P = Get-Variable -valueonly PROFILE
        try {
            # Ensure profile directory exists
            $profileDir = Split-Path $P -Parent
            if (-not (Test-Path $profileDir)) {
                New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
                Write-Host "✅ Created profile directory: $profileDir" -ForegroundColor Green
            }
            
            # Create profile file if it doesn't exist
            if (-not (Test-Path $P)) {
                New-Item -ItemType File -Path $P -Force | Out-Null
                Write-Host "✅ Created profile file: $P" -ForegroundColor Green
            }
            
            # Get current profile content and version
            $currentContent = Get-Content $P -Raw -ErrorAction SilentlyContinue
            $currentVersion = $this.GetProfileVersion($currentContent)
            
            Write-Host "📍 Current profile version: $currentVersion" -ForegroundColor Yellow
            
            # Get gist content
            $gistContent = $this.GetGistContent($this.GitHubUsername, $GistId, $this.GistFileName)
            
            if (-not $gistContent) {
                throw "Failed to retrieve gist content"
            }
            
            # Get remote version
            $remoteVersion = $this.GetProfileVersion($gistContent)
            Write-Host "🌐 Remote profile version: $remoteVersion" -ForegroundColor Yellow
            
            # Compare versions and content
            $shouldUpdate = $Force -or ($this.CompareVersions($currentVersion, $remoteVersion)) -or ($this.CompareContent($currentContent, $gistContent))
            
            if (-not $shouldUpdate) {
                Write-Host "✅ Profile is already up to date!" -ForegroundColor Green
                return
            }
            
            # Preview mode
            if ($Preview) {
                $this.ShowChangesPreview($currentContent, $gistContent)
                return
            }
            
            # Confirm update unless forced
            if (-not $Force) {
                $confirmation = Read-Host "🤔 Update profile from version $currentVersion to $remoteVersion ? (Y/n)"
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
                
                # Offer to reload profile
                $reload = Read-Host "🔄 Reload profile now? (Y/n)"
                if ($reload -ne 'n' -and $reload -ne 'N') {
                    . $P
                    Write-Host "✅ Profile reloaded!" -ForegroundColor Green
                }
            
        }
        catch {
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
        <#
        .SYNOPSIS
            Shows usage examples for the PowerShell Profile Updater
        #>
        
        Write-Host "📖 PowerShell Profile Updater - Usage Examples" -ForegroundColor Cyan
        Write-Host "===============================================" -ForegroundColor Cyan
        
        $examples = @(
            @{
                Title = "Basic Update (Public Gist)"
                Command = "Update-PowerShellProfile"
                Description = "Updates from default user 'chadnpc' public gist"
            },
            @{
                Title = "Preview Changes"
                Command = "Update-PowerShellProfile -Preview"
                Description = "Shows what would change without applying updates"
            },
            @{
                Title = "Force Update"
                Command = "Update-PowerShellProfile -Force"
                Description = "Updates without confirmation prompts"
            },
            @{
                Title = "Specific User"
                Command = "Update-PowerShellProfile -GitHubUsername 'yourusername'"
                Description = "Updates from a specific GitHub user's gist"
            },
            @{
                Title = "Specific Gist ID"
                Command = "Update-PowerShellProfile -GistId 'abc123def456'"
                Description = "Updates from a specific gist by ID"
            },
            @{
                Title = "With GitHub Token"
                Command = "Update-PowerShellProfile -Token 'ghp_xxxxxxxxxxxx'"
                Description = "Uses GitHub token for private gists or rate limit avoidance"
            },
            @{
                Title = "Custom Settings"
                Command = "Update-PowerShellProfile -GistFileName 'profile.ps1' -BackupCount 5"
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
        <#
        .SYNOPSIS
            Tests the PowerShell Profile Updater functionality
        
        .DESCRIPTION
            Runs various tests to ensure the profile updater works correctly
        #>
        
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
        $testContent = @"
# Version 1.2.3
# This is a test profile
Write-Host "Hello World"
"@

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
        }
        catch {
            # If version comparison fails, assume update is needed
            return $true
        }
    }
    [bool] CompareContent([string]$Current, [string]$Remote) {
        if ([string]::IsNullOrEmpty($Current) -and -not [string]::IsNullOrEmpty($Remote)) {
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
        }
        else {
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
        if (-not (Test-Path $P)) {
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
    [string] GetGistContent([string]$GitHubUsername, [string]$GistId, [string]$GistFileName) {
        $gistUrl = ''
        try {
            # If specific gist ID is provided, use it directly
            if ($GistId) {
                $gistUrl = "https://api.github.com/gists/$GistId"
                Write-Host "🔍 Fetching gist by ID: $GistId" -ForegroundColor Yellow
            }
            else {
                # Search for gists by username
                Write-Host "🔍 Searching gists for user: $GitHubUsername" -ForegroundColor Yellow
                $gistsUrl = "https://api.github.com/users/$GitHubUsername/gists"

                # Try public gists first
                try {
                    $gists = Invoke-RestMethod -Uri $gistsUrl -Headers $script:Headers -ErrorAction Stop -verbose:$false

                    # Find gist containing the profile file
                    $targetGist = $gists | Where-Object {
                        $_.files.PSObject.Properties.Name -contains $GistFileName
                    } | Select-Object -First 1

                    if (-not $targetGist) {
                        throw "No gist found containing file: $GistFileName"
                    }

                    $gistUrl = $targetGist.url
                    Write-Host "✅ Found gist: $($targetGist.id)" -ForegroundColor Green
                }
                catch {
                    # If public search fails, prompt for authentication
                    Write-Host "⚠️  Public gist search failed. Gist may be private." -ForegroundColor Yellow

                    if (-not $script:Headers.ContainsKey('Authorization')) {
                        $this.Token = Read-Host "Enter GitHub token for private gist access (or press Enter to skip)" -AsSecureString
                        if ($this.Token.Length -gt 0) {
                            $tokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($this.Token))
                            $script:Headers['Authorization'] = "token $tokenPlain"

                            # Retry with authentication
                            $gists = Invoke-RestMethod -Uri $gistsUrl -Headers $script:Headers -ErrorAction Stop -verbose:$false
                            $targetGist = $gists | Where-Object {
                                $_.files.PSObject.Properties.Name -contains $GistFileName
                            } | Select-Object -First 1

                            if (-not $targetGist) {
                                throw "No gist found containing file: $GistFileName"
                            }

                            $gistUrl = $targetGist.url
                        }
                        else {
                            throw "Authentication required for private gist access"
                        }
                    }
                }
            }

            # Get the specific gist
            $gist = Invoke-RestMethod -Uri $gistUrl -Headers $script:Headers -ErrorAction Stop -verbose:$false

            # Find the profile file in the gist
            $profileFile = $gist.files.PSObject.Properties | Where-Object {
                $_.Name -eq $GistFileName -or $_.Name -like "*profile*"
            } | Select-Object -First 1

            if (-not $profileFile) {
                throw "Profile file '$GistFileName' not found in gist"
            }

            Write-Host "📥 Downloading: $($profileFile.Name)" -ForegroundColor Green

            # Get the raw content
            $rawUrl = $profileFile.Value.raw_url
            $content = Invoke-RestMethod -Uri $rawUrl -Headers $script:Headers -ErrorAction Stop -verbose:$false

            return $content
        }
        catch {
            Write-Error "Failed to get gist content: $($_.Exception.Message)"
            return $null
        }
    }
}

function Update-PowerShellProfile {
    <#
    .SYNOPSIS
        Updates your PowerShell profile to the latest version from a GitHub Gist.
    
    .DESCRIPTION
        This function uses the ProfileUpdater class to downloads the latest version of your PowerShell profile from a GitHub Gist,
        compares it with your current profile, and updates it if a newer version is available.
        It supports both public and private gists with robust error handling and backup functionality.
    
    .PARAMETER GitHubUsername
        The GitHub username that owns the gist. Default is 'chadnpc'.
    
    .PARAMETER GistId
        The specific Gist ID to download from. If not provided, the function will search for gists.
    
    .PARAMETER GistFileName
        The name of the profile file in the gist. Default is 'Microsoft.PowerShell_profile.ps1'.
    
    .PARAMETER Force
        Forces the update without version comparison or user confirmation.
    
    .PARAMETER Preview
        Shows a preview of changes without applying them.
    
    .PARAMETER BackupCount
        Number of backup files to keep. Default is 3.
    
    .PARAMETER Token
        GitHub personal access token for private gists or to avoid rate limiting.
    
    .EXAMPLE
        Update-PowerShellProfile
        Updates the profile using default settings (public gist from 'chadnpc').
    
    .EXAMPLE
        Update-PowerShellProfile -GitHubUsername "myusername" -Preview
        Previews changes from a specific user's gist without applying them.
    
    .EXAMPLE
        Update-PowerShellProfile -GistId "b712cb340e0491bc7bb981474a65e57b" -Force
        Forces update from a specific gist ID.
    
    .EXAMPLE
        Update-PowerShellProfile -Token "ghp_xxxxxxxxxxxx"
        Updates using a GitHub token for authentication.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$GitHubUsername = 'chadnpc',

        [Parameter(Mandatory = $false)]
        [string]$GistId,

        [Parameter(Mandatory = $false)]
        [string]$GistFileName = 'Microsoft.PowerShell_profile.ps1',

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$Preview,

        [Parameter(Mandatory = $false)]
        [int]$BackupCount = 3,

        [Parameter(Mandatory = $false)]
        [string]$Token
    )

    process {
        # Create an instance of the ProfileUpdater class
        $updater = [ProfileUpdater]::new()

        # Configure the updater with provided parameters
        $updater.GitHubUsername = $GitHubUsername
        $updater.GistFileName = $GistFileName
        $updater.BackupCount = $BackupCount

        if ($Token) {
            $updater.Token = $Token
        }

        # Call the Update method with appropriate parameters
        $updater.Update($GistId, $Force.IsPresent, $Preview.IsPresent)
    }
}

# Convenience functions for easier access to class functionality
function Test-ProfileUpdater {
    <#
    .SYNOPSIS
        Tests the PowerShell Profile Updater functionality

    .DESCRIPTION
        Creates a ProfileUpdater instance and runs the test suite

    .PARAMETER Interactive
        Whether to run in interactive mode with menu options
    #>
    param(
        [switch]$Interactive
    )

    $updater = [ProfileUpdater]::new()
    $updater.RunTests($Interactive.IsPresent)
}

function Show-ProfileUpdaterUsage {
    <#
    .SYNOPSIS
        Shows usage examples for the PowerShell Profile Updater

    .DESCRIPTION
        Creates a ProfileUpdater instance and displays usage examples
    #>

    $updater = [ProfileUpdater]::new()
    $updater.ShowUsage()
}
