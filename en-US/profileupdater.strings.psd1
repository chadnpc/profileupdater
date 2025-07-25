
@{
  ModuleName    = 'profileupdater'
  ModuleVersion = '0.1.1'
  ReleaseNotes  = '# Release Notes

## Version 0.1.1
- **Bug Fix**: Fixed version comparison logic that incorrectly prompted for updates when remote version was older than current version
- **Improvement**: Added explicit check to prevent downgrading unless -Force parameter is used
- **Enhancement**: Improved user messages to clearly indicate when remote version is older
- **Enhancement**: Better confirmation prompts that distinguish between version updates and content-only changes

## Version 0.1.0
- Initial release with basic profile update functionality
- Support for GitHub gist integration
- Backup and restore capabilities
- Version comparison and content diffing
'
}
