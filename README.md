# PoShCredentialStore

A cross-platform PowerShell module for secure credential management using native credential stores.

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PoShCredentialStore.svg)](https://www.powershellgallery.com/packages/PoShCredentialStore)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform Support](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows*-blue.svg)](#platform-support)

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Commands](#commands)
- [Platform Support](#platform-support)
- [Examples](#examples)
- [Security Considerations](#security-considerations)
- [Requirements](#requirements)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
- [Support](#support)

## Overview

The PoShCredentialStore module provides a unified interface for storing and retrieving credentials using native credential stores. This ensures maximum security by leveraging the operating system's built-in credential management capabilities.

**Currently Supported:**
- **macOS**: Keychain Services (via security command) ✅

**Planned:**
- **Windows**: Additional platform support planned for future releases 🚧

**Recent Updates:**
- Fixed password truncation issue on macOS (v1.0.1)
- Enhanced SecureString handling and conversion
- Improved error handling and validation
- Added comprehensive test coverage

## Installation

### From PowerShell Gallery (Recommended)
```powershell
# Install for current user
Install-Module -Name PoShCredentialStore -Scope CurrentUser

# Install system-wide (requires admin privileges)
Install-Module -Name PoShCredentialStore -Scope AllUsers
```

### Manual Installation
1. Download the latest release from [GitHub](https://github.com/PowerShell/PoShCredentialStore/releases)
2. Extract to your PowerShell modules directory:
   - **Current User**: `$env:USERPROFILE\Documents\PowerShell\Modules\` (Windows)
   - **Current User**: `~/.local/share/powershell/Modules/` (macOS/Linux)
   - **All Users**: `$env:ProgramFiles\PowerShell\Modules\` (Windows)
3. Import the module:
```powershell
Import-Module PoShCredentialStore
```

### Verify Installation
```powershell
# Check module information
Get-Module PoShCredentialStore -ListAvailable

# Verify platform support
Get-CredentialStoreInfo
```

## Quick Start

```powershell
# Store a credential using the recommended New-StoredCredential function
$cred = Get-Credential -Message "Enter your service credentials"
New-StoredCredential -Name "MyService" -Credential $cred -Comment "Production API access"

# Alternative: Store using username and password parameters
$securePass = ConvertTo-SecureString "MyPassword" -AsPlainText -Force
New-StoredCredential -Name "MyService" -UserName "myuser" -Password $securePass

# Retrieve a credential
$storedCred = Get-StoredCredential -Name "MyService"

# Use the credential with REST APIs
if ($storedCred) {
    $headers = @{
        'Authorization' = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($storedCred.UserName):$($storedCred.GetNetworkCredential().Password)")))"
    }
    Invoke-RestMethod -Uri "https://api.service.com/data" -Headers $headers
}

# Update an existing credential
Set-StoredCredential -Name "MyService" -Comment "Updated production access"

# Test if a credential exists
if (Test-StoredCredential -Name "MyService") {
    Write-Host "Credential is available"
}

# Remove a credential
Remove-StoredCredential -Name "MyService" -Force
```

## Commands

| Command | Description | Status |
|---------|-------------|--------|
| `New-StoredCredential` | Creates a new credential in the store | ✅ |
| `Get-StoredCredential` | Retrieves a credential from the store | ✅ |
| `Set-StoredCredential` | Updates an existing credential in the store | ✅ |
| `Remove-StoredCredential` | Removes a credential from the store | ✅ |
| `Test-StoredCredential` | Tests if a credential exists in the store | ✅ |
| `Get-CredentialStoreInfo` | Gets platform and storage information | ✅ |

### Compatibility Aliases
For backward compatibility, these alias functions are available:
| Alias | Maps To |
|-------|---------|
| `Get-PoShCredential` | `Get-StoredCredential` |
| `Set-PoShCredential` | `Set-StoredCredential` |
| `Remove-PoShCredential` | `Remove-StoredCredential` |

## Platform Support

### macOS ✅
- Uses Keychain Services via `security` command
- Integrates with macOS Passwords app and Keychain Access
- Credentials are stored in the user's keychain
- May require keychain unlock for access
- **Requirement**: macOS 10.15+ (Catalina)
- **Dependencies**: `security` command (built-in)

**Known Issues Fixed in v1.0.1:**
- ✅ Password truncation issue resolved
- ✅ Improved SecureString conversion
- ✅ Enhanced error handling for keychain operations

### Windows 🚧 (Planned)
- Additional platform support planned for future releases
- Native credential store integration when implemented
- **Requirement**: To be determined based on implementation approach

**Note**: Additional platform support is planned for future releases. Currently, this module supports macOS only.

## Examples

### Basic Operations
```powershell
# Create a credential with comment
$cred = Get-Credential -UserName "api-user" -Message "Enter API credentials"
New-StoredCredential -Name "ProductionAPI" -Credential $cred -Comment "Main production API access"

# Create credential from individual components
$securePass = ConvertTo-SecureString "MySecretPassword" -AsPlainText -Force
New-StoredCredential -Name "DatabaseConn" -UserName "dbuser" -Password $securePass -Comment "Database connection"

# Check if credential exists before using it
if (Test-StoredCredential -Name "ProductionAPI") {
    $cred = Get-StoredCredential -Name "ProductionAPI"
    Write-Host "Found credential for: $($cred.UserName)"
} else {
    Write-Warning "Production API credentials not found"
}

# Update only the comment (password remains unchanged)
Set-StoredCredential -Name "ProductionAPI" -Comment "Updated: Main production API access with rate limiting"

# Remove credential
Remove-StoredCredential -Name "ProductionAPI" -Force
```

### Advanced Pipeline Operations
```powershell
# Batch credential management
$services = @(
    @{Name = "Service1"; User = "user1@domain.com"; Pass = "Pass1!"},
    @{Name = "Service2"; User = "user2@domain.com"; Pass = "Pass2!"},
    @{Name = "Service3"; User = "user3@domain.com"; Pass = "Pass3!"}
)

# Create multiple credentials
$services | ForEach-Object {
    $securePass = ConvertTo-SecureString $_.Pass -AsPlainText -Force
    New-StoredCredential -Name $_.Name -UserName $_.User -Password $securePass -Comment "Auto-generated"
}

# Check which credentials exist
$existingCreds = $services.Name | Where-Object { Test-StoredCredential -Name $_ }
Write-Host "Found credentials for: $($existingCreds -join ', ')"

# Retrieve all stored credentials
$allCreds = Get-StoredCredential
Write-Host "Total stored credentials: $($allCreds.Count)"
$allCreds | ForEach-Object { Write-Host "  - [$($_.Name)] $($_.UserName)" }

# Clean up using pipeline
$services.Name | Remove-StoredCredential -Force
```

### Real-World Usage Scenarios
```powershell
# Example 1: REST API with Bearer token
$apiCred = Get-StoredCredential -Name "GitHubAPI"
if ($apiCred) {
    $headers = @{
        'Authorization' = "Bearer $($apiCred.GetNetworkCredential().Password)"
        'Accept' = 'application/vnd.github.v3+json'
    }
    $repos = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Headers $headers
    Write-Host "Found $($repos.Count) repositories"
}

# Example 2: Database connection string
$dbCred = Get-StoredCredential -Name "ProductionDB"
if ($dbCred) {
    $connectionString = "Server=prod-sql;Database=MainDB;User ID=$($dbCred.UserName);Password=$($dbCred.GetNetworkCredential().Password);Encrypt=true"
    # Use connection string with your database operations
}

# Example 3: Conditional credential creation for automation
$requiredCreds = @("EmailSMTP", "CloudStorage", "MonitoringAPI")
$missingCreds = $requiredCreds | Where-Object { -not (Test-StoredCredential -Name $_) }

if ($missingCreds) {
    Write-Warning "Missing required credentials: $($missingCreds -join ', ')"
    Write-Host "Please run the setup script to configure these credentials."
} else {
    Write-Host "All required credentials are available. Starting automation..."
}
```

## Security Considerations

- Credentials stored using platform-native security mechanisms
- Memory cleanup performed after sensitive operations
- Input validation prevents malformed credential names
- Platform-specific security features leveraged
- No credentials logged or written to disk in plain text

## Requirements

- **PowerShell**: 7.0 or later (cross-platform support)
- **macOS**: macOS 10.15+ (Catalina) with `security` command (built-in)
- **Windows**: Windows 10/11 or Windows Server 2019+ [Planned]

**Important**: This module currently supports macOS only. Windows support is planned for a future release.

### PowerShell Compatibility
- ✅ PowerShell 7.0+
- ❌ Windows PowerShell 5.1 (not supported due to cross-platform requirements)

### Platform Requirements
| Platform | Status | Requirements |
|----------|--------|--------------|
| macOS 10.15+ | ✅ Supported | `security` command (built-in) |
| Windows 10+ | 🚧 Planned | To be determined |
| Linux | ❌ Not Planned | No native credential store |

## Troubleshooting

### Platform Detection
First, verify your platform is supported:
```powershell
Get-CredentialStoreInfo
```

### Common Issues

#### macOS: Keychain Access Issues
**Problem**: "Keychain access denied" or credential operations fail

**Solutions**:
1. **Unlock keychain manually**:
   ```bash
   security unlock-keychain ~/Library/Keychains/login.keychain-db
   ```

2. **Check keychain permissions**:
   - Open Keychain Access app
   - Go to Preferences → Reset My Default Keychain
   - Verify your login keychain is unlocked

3. **Verify security command**:
   ```bash
   which security
   /usr/bin/security --version
   ```

4. **Reset keychain if corrupted**:
   ```bash
   # Backup first, then reset
   security delete-keychain ~/Library/Keychains/login.keychain-db
   # System will recreate on next login
   ```

#### macOS: Password Truncation (Fixed in v1.0.1)
**Problem**: Stored passwords are truncated or corrupted

**Solution**: Update to version 1.0.1 or later. If still experiencing issues:
```powershell
# Remove and recreate the affected credential
Remove-StoredCredential -Name "ProblemCredential" -Force
New-StoredCredential -Name "ProblemCredential" -Credential $newCred
```

#### General: Credential Not Found
**Problem**: `Get-StoredCredential` returns null for existing credentials

**Troubleshooting Steps**:
1. **Verify exact credential name** (case-sensitive):
   ```powershell
   Get-StoredCredential  # List all credentials
   ```

2. **Check platform support**:
   ```powershell
   $info = Get-CredentialStoreInfo
   if ($info.Status -ne "Healthy") {
       $info.Issues | ForEach-Object { Write-Warning $_ }
   }
   ```

3. **Verify user context**:
   - Credentials are user-specific
   - Ensure you're running as the same user who stored the credential

#### Module Loading Issues
**Problem**: Module import fails or functions not available

**Solutions**:
1. **Check PowerShell version**:
   ```powershell
   $PSVersionTable.PSVersion  # Must be 7.0+
   ```

2. **Force reimport**:
   ```powershell
   Remove-Module PoShCredentialStore -Force -ErrorAction SilentlyContinue
   Import-Module PoShCredentialStore -Force
   ```

3. **Verify installation**:
   ```powershell
   Get-Module PoShCredentialStore -ListAvailable
   ```

### Getting Detailed Help
```powershell
# Get comprehensive help for any function
Get-Help New-StoredCredential -Full
Get-Help Get-StoredCredential -Examples
Get-Help Set-StoredCredential -Parameter Name

# Check module documentation
Get-Help about_PoShCredentialStore

# Enable verbose logging for troubleshooting
$VerbosePreference = "Continue"
Get-StoredCredential -Name "TestCred" -Verbose
```

### Reporting Issues
If you encounter persistent issues:

1. **Gather diagnostic information**:
   ```powershell
   $info = Get-CredentialStoreInfo
   $info | ConvertTo-Json | Out-File "diagnostic-info.json"
   ```

2. **Enable verbose logging** and capture the output
3. **Report the issue** with:
   - Your platform (macOS version)
   - PowerShell version
   - Exact error messages
   - Steps to reproduce

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
