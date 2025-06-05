NAME
    Get-CredentialStoreInfo

SYNOPSIS
    Gets information about the credential store

SYNTAX
    Get-CredentialStoreInfo [<CommonParameters>]

DESCRIPTION
    Returns information about the current platform and credential storage capabilities.
    Useful for diagnostics, platform detection, and troubleshooting credential store issues.

PARAMETERS
    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable.

INPUTS
    None
        This cmdlet does not accept pipeline input.

OUTPUTS
    System.Management.Automation.PSCustomObject
        Returns a custom object with credential store information including:
        - ModuleName: Name of the module
        - Version: Module version
        - Platform: Operating system platform
        - IsWindows: Boolean indicating Windows platform
        - IsMacOS: Boolean indicating macOS platform
        - StorageType: Type of credential storage used
        - SupportedOperations: Array of supported operations
        - Status: Overall health status
        - Issues: Array of detected issues
        - LastChecked: Timestamp of information gathering

NOTES
    Platform Support:
    - macOS: Uses Keychain Services via security command
    - Windows: Planned support for Windows Credential Manager

    Diagnostics:
    - Checks for required platform utilities
    - Validates credential store accessibility
    - Reports platform-specific configuration issues

EXAMPLES
    Example 1: Get basic credential store information
    -------------------------- 
    PS C:\> Get-CredentialStoreInfo

    ModuleName          : PoShCredentialStore
    Version             : 1.0.1
    Platform            : MacOS
    IsWindows           : False
    IsMacOS             : True
    StorageType         : macOS Keychain
    SupportedOperations : {Get, Set, Remove, Test}
    Status              : Healthy
    Issues              : {}
    LastChecked         : 6/5/2025 10:30:15 AM

    Returns comprehensive information about the credential store.

    Example 2: Check for platform compatibility
    -------------------------- 
    PS C:\> $info = Get-CredentialStoreInfo
    PS C:\> if ($info.Status -eq "Healthy") {
    >>     Write-Host "Credential store is ready for use"
    >> } else {
    >>     Write-Warning "Issues detected: $($info.Issues -join ', ')"
    >> }

    Uses the information for conditional logic and error reporting.

    Example 3: Display platform-specific guidance
    -------------------------- 
    PS C:\> $info = Get-CredentialStoreInfo
    PS C:\> switch ($info.Platform) {
    >>     "MacOS" { Write-Host "Using macOS Keychain - may require unlock" }
    >>     "Windows" { Write-Host "Using Windows Credential Manager" }
    >>     default { Write-Warning "Unsupported platform: $($info.Platform)" }
    >> }

    Provides platform-specific user guidance.

    Example 4: Troubleshooting credential issues
    -------------------------- 
    PS C:\> $info = Get-CredentialStoreInfo
    PS C:\> if ($info.Issues.Count -gt 0) {
    >>     Write-Host "Credential store issues detected:" -ForegroundColor Red
    >>     $info.Issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    >> }

    Displays detailed troubleshooting information.

RELATED LINKS
    Get-StoredCredential
    New-StoredCredential
    Set-StoredCredential
    Remove-StoredCredential
    Test-StoredCredential
    about_PoShCredentialStore
