
@{
  ModuleName             = 'profileupdater'
  ModuleVersion          = '0.1.3'
  ReleaseNotes           = '# Release Notes

## Version 0.1.3
'
  default_profile_config = @{
    ExecutionPolicy   = 'Unrestricted'
    WarningPreference = 'SilentlyContinue'
    VerbosePreference = 'Continue'
    UseZoxide         = $false
    UseOmp            = $true
    aliases           = @{
      fetch = { $IsLinux ? 'fastfetch --config os' : $null }
      c     = { 'Clear-Host' }
      files = { switch ($true) {
          $IsLinux { 'thunar'; break }
          $IsWindows { 'explorer'; break }
          default { $null }
        }
      }
    }
  }
}
