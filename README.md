# PSCredentialStore

A cross-platform PowerShell module for securely storing and retrieving credentials using native OS credential stores - Windows Credential Manager and macOS Keychain.

## Features

- **Cross-platform support**: Windows Credential Manager and macOS Keychain
- **Native OS integration**: Uses built-in credential storage mechanisms
- **Metadata support**: Store additional information with credentials (description, URL, application)
- **Simple, consistent PowerShell interface** across platforms
- **Pipeline support**: Process multiple credentials efficiently
- **Secure memory handling**: Proper cleanup of sensitive data
- **Input validation**: Comprehensive security checks for credential names

## Requirements

- PowerShell 7.0 or later
- Windows 10/11 or macOS 10.14+

## Installation

### From PowerShell Gallery (Recommended)

```powershell
Install-Module -Name PSCredentialStore -Scope CurrentUser
```

### Manual Installation

1. Download or clone this repository
2. Copy the PSCredentialStore folder to a location in your `$PSModulePath`
3. Import the module with `Import-Module PSCredentialStore`

## Usage

### Storing a credential

```powershell
# Basic credential storage
$cred = Get-Credential
New-StoredCredential -Name "MyApplication" -Credential $cred

# With metadata
New-StoredCredential -Name "WebAPI" -Credential $cred -Description "Production API" -URL "https://api.example.com" -Application "MyApp"

# Update existing credential
Set-StoredCredential -Name "MyApplication" -Credential $newCred
```

### Retrieving a credential

```powershell
# Get a specific credential
$cred = Get-StoredCredential -Name "MyApplication"
$username = $cred.UserName
$password = $cred.Credential.GetNetworkCredential().Password  # Only use this in secure contexts!

# Access metadata
$description = $cred.Description
$url = $cred.URL
```

### Listing all credentials

```powershell
# List all stored credentials with metadata
Get-StoredCredential | ForEach-Object {
    Write-Host "$($_.Name): $($_.UserName) - $($_.Description)"
}
```

### Removing a credential

```powershell
Remove-StoredCredential -Name "MyApplication"

# Remove multiple credentials
"App1", "App2", "App3" | Remove-StoredCredential -Force
```

### Testing if a credential exists

```powershell
if (Test-StoredCredential -Name "MyApplication") {
    Write-Host "Credential exists!"
} else {
    Write-Host "Credential not found."
}
```

### macOS-specific features

```powershell
# Store with iCloud Keychain sync disabled
New-StoredCredential -Name "LocalOnly" -Credential $cred -Metadata @{ Synchronizable = $false }
```

## Commands

| Command                  | Description                                                                 |
|--------------------------|-----------------------------------------------------------------------------|
| `New-StoredCredential`   | Creates a new credential in the credential store (fails if already exists) |
| `Set-StoredCredential`   | Updates an existing credential in the credential store                      |
| `Get-StoredCredential`   | Retrieves a credential or lists all credentials                             |
| `Remove-StoredCredential`| Removes a credential from the credential store                              |
| `Test-StoredCredential`  | Tests if a credential exists in the credential store                        |

## Metadata Support

PSCredentialStore supports storing additional metadata with credentials:

- **Description**: Human-readable description of the credential
- **URL**: Associated URL or service endpoint
- **Application**: Application or service name
- **Custom metadata**: Store additional key-value pairs

### Platform-specific metadata storage

- **Windows**: Metadata stored as JSON files in `%LOCALAPPDATA%\PSCredentialStore\metadata\`
- **macOS**: Metadata stored as JSON files in `~/.pscredentialstore/metadata/`

## Security Features

- **Input validation**: Comprehensive checks prevent injection attacks
- **Memory cleanup**: Secure disposal of sensitive data
- **Platform integration**: Uses OS-native security mechanisms
- **Access control**: Respects OS-level credential access permissions

## Testing

This module uses [Pester](https://github.com/pester/Pester) for testing.

To run all tests:

```powershell
pwsh ./Tests/Invoke-Tests.ps1
```

To run platform-specific tests:

```powershell
# Run only unit tests
pwsh ./Tests/Invoke-Tests.ps1 -Tag "Unit"

# Run Windows-specific tests
pwsh ./Tests/Invoke-Tests.ps1 -Tag "Windows"

# Run macOS-specific tests  
pwsh ./Tests/Invoke-Tests.ps1 -Tag "MacOS"
```

## Platform Support

| Platform | Credential Store | Metadata Storage | Status |
|----------|------------------|------------------|--------|
| Windows  | Credential Manager | Local JSON files | ✅ Supported |
| macOS    | Keychain | Local JSON files | ✅ Supported |
| Linux    | - | - | ❌ Not supported |

## Troubleshooting

### Windows
- Ensure you have permissions to access Windows Credential Manager
- Run PowerShell as Administrator if encountering permission issues

### macOS
- Unlock your keychain if prompted
- Grant PowerShell access to Keychain when requested
- Use `security unlock-keychain` if automation is needed

## Contributing

Contributions are welcome! Please ensure:
- All tests pass on both Windows and macOS
- New features include appropriate tests
- Documentation is updated for new functionality