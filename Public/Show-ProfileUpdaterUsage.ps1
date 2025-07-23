function Show-ProfileUpdaterUsage {
  # .SYNOPSIS
  #     Shows usage examples for the PowerShell Profile Updater
  # .DESCRIPTION
  #     Creates a ProfileUpdater instance and displays usage examples
  $updater = [ProfileUpdater]::new()
  $updater.ShowUsage()
}
