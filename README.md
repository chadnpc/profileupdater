
## [pwsh profile updater](https://www.powershellgallery.com/packages/profileupdater)

🔄 A simple module to manage and version control your powershell $profile

[![Build Module](https://github.com/chadnpc/profileupdater/actions/workflows/build_module.yaml/badge.svg)](https://github.com/chadnpc/profileupdater/actions/workflows/build_module.yaml)
[![Downloads](https://img.shields.io/powershellgallery/dt/profileupdater.svg?style=flat&logo=powershell&color=blue)](https://www.powershellgallery.com/packages/profileupdater)

## Usage

```PowerShell
Install-Module profileupdater
```

then

```PowerShell
Import-Module profileupdater
```

```PowerShell
#🔹 Basic Update (Public Gist)
    Update-PowerShellProfile
#   Updates from default user 'chadnpc' public gist
```

```PowerShell
#🔹 Preview Changes
    Update-PowerShellProfile -Preview
#   Shows what would change without applying updates
```

```PowerShell
#🔹 Force Update
    Update-PowerShellProfile -Force
#   Updates without confirmation prompts
```

```PowerShell
#🔹 Specific User
    Update-PowerShellProfile -GitHubUsername 'yourusername'
#   Updates from a specific GitHub user's gist
```

```PowerShell
#🔹 Specific Gist ID
    Update-PowerShellProfile -GistId 'abc123def456'
#   Updates from a specific gist by ID
```

```PowerShell
#🔹 With GitHub Token
    Update-PowerShellProfile -Token 'ghp_xxxxxxxxxxxx'
#   Uses GitHub token for private gists or rate limit avoidance
```

```PowerShell
#🔹 Custom Settings
    Update-PowerShellProfile -GistFileName 'profile.ps1' -BackupCount 5
#  Custom filename and backup retention settings
```

## License

This project is licensed under the [MIT License](LICENSE).
