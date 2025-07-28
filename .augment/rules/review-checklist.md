# PowerShell Code Review Checklist

## Pre-Review Checklist
- [ ] All tests pass locally
- [ ] Code follows project coding standards
- [ ] Documentation updated (if applicable)
- [ ] No secrets or sensitive data in commits
- [ ] PSScriptAnalyzer shows no warnings/errors

## Code Quality Checklist

### 1. Function Design
- [ ] Uses approved verb-noun naming
- [ ] Follows standard parameter pattern
- [ ] Implements proper pipeline support
- [ ] Has appropriate error handling
- [ ] Includes comment-based help
- [ ] Uses [CmdletBinding()] attribute
- [ ] Supports ShouldProcess for destructive operations
- [ ] Validates all parameters appropriately

### 2. Code Style
- [ ] Consistent indentation (4 spaces)
- [ ] No trailing whitespace
- [ ] Line length <= 115 characters
- [ ] Proper spacing around operators
- [ ] No aliases used
- [ ] Full cmdlet/parameter names
- [ ] Consistent brace style (OTBS)
- [ ] Meaningful variable names

### 3. Security
- [ ] No hard-coded credentials
- [ ] Input validation on all parameters
- [ ] Secure string handling for sensitive data
- [ ] No execution policy modifications
- [ ] Proper error message handling (no sensitive data exposure)
- [ ] Uses approved cryptographic methods
- [ ] Validates file paths to prevent directory traversal

### 4. Performance
- [ ] Efficient pipeline usage
- [ ] Avoids unnecessary memory usage
- [ ] Filters early in pipeline
- [ ] Uses appropriate collection types
- [ ] Implements streaming where possible
- [ ] No unnecessary loops
- [ ] Proper disposal of resources

### 5. Error Handling
- [ ] Comprehensive try/catch blocks
- [ ] Meaningful error messages
- [ ] Uses Write-Error appropriately
- [ ] Includes error action preference
- [ ] Logs errors appropriately
- [ ] Provides helpful suggestions for resolution
- [ ] Handles edge cases gracefully

### 6. Testing
- [ ] Unit tests for all public functions
- [ ] Integration tests for workflows
- [ ] Tests cover edge cases
- [ ] Tests verify error conditions
- [ ] Mock external dependencies
- [ ] Achieves required code coverage
- [ ] Tests are maintainable and readable

## Specific Review Items

### Parameters
- [ ] All mandatory parameters marked
- [ ] Pipeline support implemented where appropriate
- [ ] Parameter sets used for mutually exclusive parameters
- [ ] Default values make sense
- [ ] Parameter validation attributes used
- [ ] Parameter types are specific and appropriate

### Documentation
- [ ] Comment-based help is complete
- [ ] Examples are accurate and helpful
- [ ] Parameter descriptions are clear
- [ ] Links to external documentation provided
- [ ] README.md updated if needed
- [ ] Changelog updated for public changes

### Module Structure
- [ ] Proper module manifest
- [ ] Appropriate file organization
- [ ] Exports explicitly defined
- [ ] Dependencies properly declared
- [ ] Version incremented appropriately
- [ ] Breaking changes documented

### Code Patterns
- [ ] Avoids global variables
- [ ] Uses begin/process/end blocks correctly
- [ ] Implements IDisposable where needed
- [ ] Follows PowerShell idioms
- [ ] No unnecessary complexity
- [ ] Single responsibility principle followed

## Review Process

### 1. Automated Checks
Run these commands before manual review:
```powershell
# PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error, Warning

# Pester tests
Invoke-Pester -Path tests/

# Test coverage
Invoke-Pester -CodeCoverage '*.ps1', '*.psm1'

2. Manual Review Steps

    - Readability: Is the code easy to understand?
    - Maintainability: Can it be easily modified?
    - Testability: Is it properly testable?
    - Reusability: Can components be reused?
    - Performance: Are there any obvious bottlenecks?
    - Security: Any potential vulnerabilities?

3. Review Comments

    Be constructive and specific
    Suggest improvements, don't just criticize
    Provide examples when possible
    Consider the developer's perspective
    Focus on the code, not the person

4. Approval Criteria

    - [ ] All checklist items addressed
    - [ ] Reviewer comments resolved
    - [ ] No blocking issues remain
    - [ ] Meets acceptance criteria
    - [ ] Ready for production use

Post-Review Actions

    - [ ] Merge approved changes
    - [ ] Update documentation
    - [ ] Tag release if applicable
    - [ ] Deploy to appropriate environment
    - [ ] Monitor for issues
