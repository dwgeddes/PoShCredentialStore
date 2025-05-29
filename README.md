# PSCredentialStore

PSCredentialStore is a cross-platform PowerShell module for secure credential management using native credential stores (Windows Credential Manager and macOS Keychain). It provides cmdlets to create, retrieve, update, and remove credentials, with full pipeline support and rich metadata capabilities.

## Features
- Cross-platform support: Windows Credential Manager, macOS Keychain
- Pipeline input/output for bulk operations
- Secure handling of PSCredential objects
- Rich metadata storage and retrieval
- Standardized error handling and validation
- Fully tested with Pester and static analysis

## Requirements
- PowerShell 7.0 or later
- Supported platforms: Windows, macOS

## Installation
Install from PowerShell Gallery:
```powershell
Install-Module -Name PSCredentialStore -Scope CurrentUser
```

Or clone the repository and import locally:
```powershell
git clone https://github.com/PowerShell/PSCredentialStore.git
Import-Module ./PSCredentialStore/PSCredentialStore.psd1
```

## Usage Examples

### Get stored credential
```powershell
# Retrieve one credential
Get-StoredCredential -Name "MyApp"

# List all credentials
Get-StoredCredential

# Pipeline support
"App1","App2" | Get-StoredCredential
```

### Get plain-text password (use with caution)
```powershell
Get-StoredCredentialPlainText -Name "MyApp"
```

### Create new credential
```powershell
$cred = Get-Credential -Message "Enter credentials for MyApp"
New-StoredCredential -Name "MyApp" -Credential $cred -Description "App credentials" -Url "https://example.com"
```

### Update existing credential
```powershell
Set-StoredCredential -Name "MyApp" -Credential $cred -Description "Updated description"
```

### Remove credential
```powershell
Remove-StoredCredential -Name "MyApp" -Force
```

### Test for credential existence
```powershell
Test-StoredCredential -Name "MyApp"
```

## Changelog
See [CHANGELOG.md](CHANGELOG.md) for details on recent updates.

## Contributing
Contributions are welcome! Please open issues and pull requests at https://github.com/PowerShell/PSCredentialStore.
