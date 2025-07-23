function Update-PowerShellProfile {
  # .SYNOPSIS
  #     Updates your PowerShell profile to the latest version from a GitHub Gist.

  # .DESCRIPTION
  #     This function uses the ProfileUpdater class to downloads the latest version of your PowerShell profile from a GitHub Gist,
  #     compares it with your current profile, and updates it if a newer version is available.
  #     It supports both public and private gists with robust error handling and backup functionality.

  # .PARAMETER GitHubUsername
  #     The GitHub username that owns the gist. Default is 'chadnpc'.

  # .PARAMETER GistId
  #     The specific Gist ID to download from. If not provided, the function will search for gists.

  # .PARAMETER GistFileName
  #     The name of the profile file in the gist. Default is 'Microsoft.PowerShell_profile.ps1'.

  # .PARAMETER Force
  #     Forces the update without version comparison or user confirmation.

  # .PARAMETER Preview
  #     Shows a preview of changes without applying them.

  # .PARAMETER BackupCount
  #     Number of backup files to keep. Default is 3.

  # .PARAMETER Token
  #     GitHub personal access token for private gists or to avoid rate limiting.

  # .EXAMPLE
  #     Update-PowerShellProfile
  #     Updates the profile using default settings (public gist from 'chadnpc').

  # .EXAMPLE
  #     Update-PowerShellProfile -GitHubUsername "myusername" -Preview
  #     Previews changes from a specific user's gist without applying them.

  # .EXAMPLE
  #     Update-PowerShellProfile -GistId "b712cb340e0491bc7bb981474a65e57b" -Force
  #     Forces update from a specific gist ID.

  # .EXAMPLE
  #     Update-PowerShellProfile -Token "ghp_xxxxxxxxxxxx"
  #     Updates using a GitHub token for authentication.

  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
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
    if ($PSCmdlet.ShouldProcess("`$profile", "Update PowerShell Profile")) {
      $updater.Update($GistId, $Force.IsPresent, $Preview.IsPresent)
    }
  }
}