# PoShCredentialStore

A cross-platform PowerShell module for secure credential management using native credential stores.

## Overview

The PoShCredentialStore module provides a unified interface for storing and retrieving credentials across different platforms:

- **Windows**: Windows Credential Manager (via CredMan utility)
- **macOS**: Keychain Services (via security command)
- **Linux/Other**: Secure in-memory storage for cross-platform compatibility

## Installation

### From PowerShell Gallery (Recommended)
```powershell
Install-Module -Name PoShCredentialStore -Scope CurrentUser
```

### Manual Installation
1. Download the module
2. Place in your PowerShell modules directory
3. Import the module:
```powershell
Import-Module PoShCredentialStore
```

## Quick Start

```powershell
# Store a credential
$cred = Get-Credential -Message "Enter your service credentials"
Set-PoShCredential -Name "MyService" -Credential $cred

# Retrieve a credential
$storedCred = Get-PoShCredential -Name "MyService"

# Use the credential
if ($storedCred) {
    Invoke-RestMethod -Uri "https://api.service.com" -Credential $storedCred
}

# Remove a credential
Remove-PoShCredential -Name "MyService"
```

## Commands

| Command | Description |
|---------|-------------|
| `Set-PoShCredential` | Creates or updates a credential in the store |
| `Get-PoShCredential` | Retrieves a credential from the store |
| `Remove-PoShCredential` | Removes a credential from the store |
| `Get-CredentialStoreInfo` | Gets platform and storage information |

## Platform Support

### Windows
- Uses Windows Credential Manager via CredMan utility
- Persistent storage with system-level security
- **Requirement**: CredMan utility must be available

### macOS
- Uses Keychain Services via `security` command
- Integrates with macOS Passwords app
- May require keychain unlock for access

### Linux and Other Platforms
- Secure in-memory credential storage
- Session-based persistence
- Full cross-platform compatibility

## Examples

### Basic Operations
```powershell
# Create a credential
$cred = Get-Credential
Set-PoShCredential -Name "Database" -Credential $cred

# Check if credential exists
$exists = Get-PoShCredential -Name "Database"
if ($exists) {
    Write-Host "Credential found"
}

# Remove credential
Remove-PoShCredential -Name "Database"
```

### Pipeline Operations
```powershell
# Check multiple services
"Service1", "Service2", "Service3" | ForEach-Object {
    $cred = Get-PoShCredential -Name $_
    Write-Host "$_: $(if($cred){'Found'}else{'Missing'})"
}
```

### Error Handling
```powershell
try {
    $cred = Get-PoShCredential -Name "CriticalService"
    if ($cred) {
        # Use credential safely
        $result = Invoke-RestMethod -Uri "https://api.example.com" -Credential $cred
    } else {
        Write-Warning "Credentials not found for CriticalService"
    }
}
catch {
    Write-Error "Failed to retrieve credentials: $($_.Exception.Message)"
}
```

## Security Considerations

- Credentials stored using platform-native security mechanisms
- Memory cleanup performed after sensitive operations
- Input validation prevents malformed credential names
- Platform-specific security features leveraged
- No credentials logged or written to disk in plain text

## Requirements

- PowerShell 5.1 or later
- **Windows**: CredMan utility (for Credential Manager access)
- **macOS**: `security` command (built-in)
- **Linux**: No additional requirements (in-memory storage)

## Troubleshooting

### Common Issues

1. **Windows: CredMan not found**
   - Install CredMan utility or use in-memory storage
   - Verify PATH includes CredMan location

2. **macOS: Keychain access denied**
   - Unlock keychain manually
   - Check keychain permissions

3. **General: Credential not found**
   - Verify credential name spelling
   - Check platform support with `Get-CredentialStoreInfo`

### Getting Help
```powershell
# Get detailed help for any command
Get-Help Set-PoShCredential -Full
Get-Help Get-PoShCredential -Examples

# Check platform information
Get-CredentialStoreInfo
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- GitHub Issues: [Repository Issues](https://github.com/PowerShell/PoShCredentialStore/issues)
- PowerShell Gallery: [Module Page](https://www.powershellgallery.com/packages/PoShCredentialStore)
