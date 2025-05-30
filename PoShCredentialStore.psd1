```powershell
@{
    # Module Identification
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    
    # Version number of the module
    ModuleVersion = '1.0.0'

    # Root module file
    RootModule = 'PoShCredentialStore.psm1'

    # PowerShell version requirements - PowerShell 7.0+ for cross-platform support
    PowerShellVersion = '7.0'
    
    # Supported PowerShell editions - Core only (PowerShell 7+)
    CompatiblePSEditions = @('Core')

    # Explicitly export public functions for better control
    FunctionsToExport = @(
        'Get-PoShCredential',
        'Set-PoShCredential', 
        'Remove-PoShCredential',
        'Get-CredentialStoreInfo'
    )

    # No variables or aliases to export
    VariablesToExport = @()
    AliasesToExport = @()

    # Module metadata
    Description = 'A cross-platform PowerShell module for secure credential management using native credential stores (Windows Credential Manager, macOS Keychain, Linux in-memory storage).'
    Author = 'PoShCredentialStore Contributors'
    CompanyName = 'Community'
    Copyright = 'Copyright (c) 2024 PoShCredentialStore Contributors. All rights reserved.'

    # Dependencies
    RequiredModules = @()
    RequiredAssemblies = @()

    # File version
    FileVersion = '1.0.0.0'

    # Private data for module
    PrivateData = @{
        PSData = @{
            # PSGallery metadata
            Tags = @('Credentials', 'Security', 'CrossPlatform', 'CredentialManager', 'Keychain', 'CRUD', 'PowerShell7')
            ProjectUri = 'https://github.com/username/PoShCredentialStore'
            LicenseUri = 'https://github.com/username/PoShCredentialStore/blob/main/LICENSE'
            ReleaseNotes = @'
# PoShCredentialStore v1.0.0

## Features
- Cross-platform credential storage with native platform integration
- Windows: Credential Manager via CredMan utility
- macOS: Keychain Services via security command
- Linux/Other: Secure in-memory storage
- CRUD operations: Get, Set, Remove, Test credentials
- Platform detection and capability reporting
- Comprehensive parameter validation and error handling
- Pipeline support for batch operations

## Requirements
- PowerShell 7.0 or later (cross-platform support)
- Windows: CredMan utility (optional, falls back to in-memory)
- macOS: security command (built-in)
- Linux: No additional requirements

## Security
- Platform-native credential storage mechanisms
- Secure memory cleanup after operations
- Input validation to prevent injection attacks
- No plain-text credential logging or disk storage
- Cross-platform security best practices

## Compatibility
- PowerShell 7.0+ (PowerShell Core)
- Windows 10/11, Windows Server 2019+
- macOS 10.15+ (Catalina and later)
- Linux distributions with PowerShell 7.0+
'@
        }
    }
}
```