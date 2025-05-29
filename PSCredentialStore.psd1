@{
    # Module identification
    RootModule = 'PSCredentialStore.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-1234-567890abcdef'
    
    # Module metadata
    Author = 'PSCredentialStore Contributors'
    CompanyName = 'PSCredentialStore'
    Copyright = '(c) 2025 PSCredentialStore Contributors. All rights reserved.'
    Description = 'Cross-platform PowerShell module for secure credential management using native credential stores (Windows Credential Manager, macOS Keychain)'
    
    # PowerShell requirements
    PowerShellVersion = '7.0'
    
    # Functions to export - matches Public folder, Get-StoredCredentialPlainText removed in API v2
    FunctionsToExport = @(
        'Get-StoredCredential',
        'New-StoredCredential', 
        'Set-StoredCredential',
        'Remove-StoredCredential',
        'Test-StoredCredential'
    )
    
    # Cmdlets, variables, and aliases to export
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    # Private data for PowerShell Gallery
    PrivateData = @{
        PSData = @{
            # Tags for discoverability
            Tags = @('Credential', 'Security', 'KeyChain', 'CredentialManager', 'CrossPlatform', 'macOS', 'Windows', 'SecureString', 'Authentication')
            
            # License and project information
            LicenseUri = 'https://github.com/PowerShell/PSCredentialStore/blob/main/LICENSE'
            ProjectUri = 'https://github.com/PowerShell/PSCredentialStore'
            IconUri = 'https://github.com/PowerShell/PSCredentialStore/blob/main/assets/icon.png'
            
            # Release information
            ReleaseNotes = @'
Initial release of PSCredentialStore with the following features:
- Cross-platform credential management (Windows Credential Manager, macOS Keychain)
- Pipeline support for bulk operations
- Rich metadata storage and retrieval
- Comprehensive input validation and security features
- Native OS integration with platform-specific features
- PowerShell 7+ compatibility
'@
            
            # Requirements and compatibility
            RequiredVersion = '7.0'
            SupportedPlatforms = @('Windows', 'macOS')
        }
    }
    
    # Module file list for packaging - removed wildcards to fix import issue
    # FileList = @()  # Comment out problematic FileList
    
    # Help information
    HelpInfoURI = 'https://github.com/PowerShell/PSCredentialStore/blob/main/docs/'
    
    # Compatibility and requirements
    CompatiblePSEditions = @('Core')
    ProcessorArchitecture = 'None'
    RequiredModules = @()
    RequiredAssemblies = @()
    ScriptsToProcess = @()
    TypesToProcess = @()
    FormatsToProcess = @()
    ModuleList = @()
    DscResourcesToExport = @()
}