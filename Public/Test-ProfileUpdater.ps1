# Convenience functions for easier access to class functionality
function Test-ProfileUpdater {
  # .SYNOPSIS
  #     Tests the PowerShell Profile Updater functionality
  # .DESCRIPTION
  #     Creates a ProfileUpdater instance and runs the test suite
  # .PARAMETER Interactive
  #     Whether to run in interactive mode with menu options
  param(
    [switch]$Interactive
  )

  $updater = [ProfileUpdater]::new()
  $updater.RunTests($Interactive.IsPresent)
}