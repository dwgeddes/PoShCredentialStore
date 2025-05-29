# Changelog

## [Unreleased]
### Added
- Standardize `Get-StoredCredentialPlainText` behavior: return `@()` for missing credentials, warning instead of `Write-Error`
- Export `Get-StoredCredentialPlainText` in the module manifest (`PSCredentialStore.psd1`)
- Applied defensive function templates to `Get-StoredCredential`, `Remove-StoredCredential`, and `Set-StoredCredential`
- Pipeline null-checks and early validation added to `Set-StoredCredential`
- Refactored `New-StoredCredential` to correctly invoke provider `Test` scriptblocks and support pipeline inputs

### Fixed
- Resolved Pester test failures by fixing provider `Test` invocation across public commands
- Suppressed and addressed key PSScriptAnalyzer warnings in test scripts
- Ensured all tests pass under PowerShell 7 on macOS
