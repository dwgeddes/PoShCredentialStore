@{
    # Module Identification
    GUID                 = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    
    # Version number of the module
    ModuleVersion        = '0.9.0'

    # Root module file
    RootModule           = 'PoShCredentialStore.psm1'

    # PowerShell version requirements - PowerShell 7.0+ for cross-platform support
    PowerShellVersion    = '7.0'
    
    # Supported PowerShell editions - Core only (PowerShell 7+)
    CompatiblePSEditions = @('Core')

    # Author and company information
    Author               = 'PoShCredentialStore Contributors'
    CompanyName          = 'Community'
    Copyright            = 'Copyright (c) 2025 PoShCredentialStore Contributors. All rights reserved.'

    # Module description
    Description          = 'A PowerShell module for secure credential management using native credential stores. Currently supports macOS Keychain with additional platforms planned for future releases.'

    # Functions to export from this module
    FunctionsToExport    = @(
        # Primary functions
        'Get-StoredCredential',
        'Set-StoredCredential',
        'New-StoredCredential', 
        'Remove-StoredCredential',
        'Test-StoredCredential',
        'Get-CredentialStoreInfo'
    )

    # Cmdlets to export from this module
    CmdletsToExport      = @()

    # Variables to export from this module
    VariablesToExport    = @()

    # Aliases to export from this module
    AliasesToExport      = @()

    # DSC resources to export from this module
    DscResourcesToExport = @()

    # List of all modules packaged with this module
    ModuleList           = @()

    # List of all files packaged with this module
    FileList             = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module
            Tags         = @('Credentials', 'Security', 'CrossPlatform', 'CredentialManager', 'Keychain', 'CRUD', 'PowerShell7')
            
            # A URL to the license for this module
            LicenseUri   = 'https://github.com/dwgeddes/PoShCredentialStore/blob/main/LICENSE'
            
            # A URL to the main website for this project
            ProjectUri   = 'https://github.com/dwgeddes/PoShCredentialStore'
            
            # A URL to an icon representing this module
            IconUri      = ''
            
            # Release notes for this version of the module
            ReleaseNotes = @'
# PoShCredentialStore v0.9.0

## Features
- Secure credential storage with native platform integration
- macOS: Keychain Services via security command
- CRUD operations: Get, Set, Remove, Test credentials
- Platform detection and capability reporting
- Comprehensive parameter validation and error handling
- Pipeline support for batch operations

## Requirements
- PowerShell 7.0 or later
- macOS: security command (built-in)

## Security
- Platform-native credential storage mechanisms
- Secure memory cleanup after operations
- Input validation to prevent injection attacks
- No plain-text credential logging or disk storage
- macOS Keychain security best practices

## Compatibility
- PowerShell 7.0+ (PowerShell Core)
- macOS 10.15+ (Catalina and later) - Currently Supported
- Additional platforms planned for future releases
'@
        }
    }

    # HelpInfo URI of this module
    HelpInfoURI          = ''

    # Default prefix for commands exported from this module
    DefaultCommandPrefix = ''

}