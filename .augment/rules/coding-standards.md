## .augment/rules/coding-standards.md

```markdown
# PowerShell Coding Standards  
(Class-First Edition)

> **Guiding Principle:** Everything is a class or an enum.  
> Only the *entry point* (the file’s main function) may remain a plain function.  
> All other logic lives in static classes, static methods, and static properties.

---

## 1. Naming & Layout

| Element              | Convention                                           |
|----------------------|------------------------------------------------------|
| **Files**            | PascalCase matching the *primary* public class (`UserManager.ps1`) |
| **Classes**          | PascalCase noun (`UserManager`, `ConfigStore`)       |
| **Enums**            | PascalCase, singular (`LogLevel`, `Color`)           |
| **Static Methods**   | PascalCase verb-noun (`GetData`, `WriteLog`)         |
| **Static Properties**| PascalCase noun (`Cache`, `DefaultTimeout`)          |
| **Private Members**  | Prefix with underscore (`_internalCache`)            |

Formatting rules (unchanged):
- 4-space indentation, no tabs  
- Line length ≤ 115 chars  
- OTBS brace style  
- 2 blank lines between top-level declarations

---

## 2. Class-First Structure

### 2.1 File Template

```powershell
#!/usr/bin/env pwsh
#Requires -Modules PsModuleBase
using namespace System.Collections.Generic
using  namespace  System.Management.Automation
using  namespace  System.Collections.ObjectModel

enum LogLevel {
    Verbose
    Information
    Warning
    Error
}

class Logger {
    static [string] $LogPath = "$PSScriptRoot\app.log"

    static [void] Write([LogLevel] $level, [string] $message) {
        $formatted = "[{0}] {1}" -f $level, $message
        Add-Content -Path [Logger]::LogPath -Value $formatted
    }
}

class UserManager {
    static [List[hashtable]] $Users = [List[hashtable]]::new()

    static [hashtable] GetUser([string] $id) {
        return [UserManager]::Users.Find({ param($u) $u.Id -eq $id })
    }

    static [void] AddUser([hashtable] $user) {
        if ([UserManager]::GetUser($user.Id)) {
            throw "User already exists"
        }
        [UserManager]::Users.Add($user)
        [Logger]::Write([LogLevel]::Information, "Added user $($user.Id)")
    }
}

# Entry-point ONLY
function Invoke-UserManagement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CsvPath
    )
    Import-Csv -Path $CsvPath | ForEach-Object {
        [UserManager]::AddUser($_)
    }
}
```

### 2.2 Golden Rules
1. **No instance members unless absolutely required**  
   Static state & behavior are the default.
2. **No `$this` in static scopes**  
   It is syntactically invalid and indicates accidental instance thinking.
3. **One public class per file**  
   Keeps discovery and auto-loading trivial.

---

## 3. Parameter & Input Patterns

Use **parameter classes** rather than function parameters:

```powershell
#!/usr/bin/env pwsh

class CopyOptions {
    static [string] $Source
    static [string] $Destination
    static [bool]   $Force
}

class FileManager {
    static [void] Copy() {
        if (![CopyOptions]::Force -and (Test-Path ([CopyOptions]::Destination))) {
            throw "Destination exists and -Force not set"
        }
        Copy-Item -Path ([CopyOptions]::Source) -Destination ([CopyOptions]::Destination)
    }
}
```

- Validate inside static methods with `[ValidatePattern()]`, `[ValidateSet()]`, etc.  
- Throw on invalid input immediately; never silently continue.

---

## 4. Error Handling & Logging

Create a **static ErrorHandler class**:

```powershell
#!/usr/bin/env pwsh

class ErrorHandler {
    static [void] Throw([string] $message) {
        [Logger]::Write([LogLevel]::Error, $message)
        throw $message
    }

    static [bool] TryCatch([scriptblock] $action) {
        try {
            & $action
            return $true
        } catch {
            [Logger]::Write([LogLevel]::Error, $_.Exception.Message)
            return $false
        }
    }
}
```

Usage:
```powershell
[ErrorHandler]::TryCatch({
    [FileManager]::Copy()
})
```

---

## 5. Configuration & Constants

Centralize in a **static Config class**:

```powershell
#!/usr/bin/env pwsh

class Config {
    static [int]    $DefaultTimeout = 30
    static [string] $ApiBaseUrl     = 'https://api.example.com/v1'
    static [hashtable] $ColorMap    = @{
        Red   = '#FF0000'
        Green = '#00FF00'
    }
}
```

Never scatter literals throughout the code.

---

## 6. Testing Static Classes

Write Pester tests against the static surface:

```powershell
#!/usr/bin/env pwsh

Describe "UserManager" {
    BeforeEach {
        [UserManager]::Users.Clear()
    }

    It "Adds a user" {
        [UserManager]::AddUser(@{Id = 'u1'; Name = 'Alice' })
        [UserManager]::Users.Count | Should -Be 1
    }
}
```

---

## 7. Security

- Store secrets in **static SecureString properties**; never in plain text.  
- Validate all static inputs as early as possible.  
- Use `[SecureString]` or KeyVault wrappers via dedicated static classes.

---

## 8. Performance

- Static collections (`List<T>`, `HashSet<T>`) are preferred over arrays.  
- Cache expensive computations in **static read-only properties**.  
- Avoid locking unless thread safety is required; document when used.

---

## 9. Migration Path (Function → Class)

Legacy function:
```powershell
function Get-User { ... }
```

Refactor to:
```powershell
class UserQueries {
    static [hashtable] Get([string] $id) { ... }
}
```
Delete the old function; update callers to `[UserQueries]::Get($id)`.

---

## 10. Forbidden Patterns

| Pattern                     | Replacement                     |
|-----------------------------|----------------------------------|
| `function Utility-Helper`   | `class Utility { static [type] Helper() }` |
| Instance methods by default | Static methods (unless stateful object is truly needed) |
| `$this` in static scope     | Remove or refactor to instance class |
| Global variables            | Static properties on a dedicated class |

> When in doubt, create another static class.
```