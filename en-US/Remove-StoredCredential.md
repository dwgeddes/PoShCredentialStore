NAME
    Remove-StoredCredential

SYNOPSIS
    Removes a credential from the credential store

SYNTAX
    Remove-StoredCredential [-Name] <String[]> [-Username <String>] [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]

DESCRIPTION
    Deletes a stored credential from the platform-specific credential store.
    Supports confirmation prompts and can return removed credential objects.

PARAMETERS
    -Name <String[]>
        Name of the credential(s) to remove. Accepts pipeline input.
        
        Required?                    true
        Position?                    0
        Default value                None
        Accept pipeline input?       True (ByValue, ByPropertyName)
        Accept wildcard characters?  false

    -Username <String>
        Specific username to remove. Required when multiple credentials exist
        with the same name on macOS.
        
        Required?                    false
        Position?                    named
        Default value                None
        Accept pipeline input?       True (ByPropertyName)
        Accept wildcard characters?  false

    -Force [<SwitchParameter>]
        Remove without confirmation.
        
        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -PassThru [<SwitchParameter>]
        Return the removed credential objects.
        
        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -WhatIf [<SwitchParameter>]
        Shows what would happen if the cmdlet runs without actually removing anything.
        
        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -Confirm [<SwitchParameter>]
        Prompts for confirmation before removing each credential.
        
        Required?                    false
        Position?                    named
        Default value                True (unless -Force is specified)
        Accept pipeline input?       false
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable.

INPUTS
    System.String[]
        You can pipe credential names to Remove-StoredCredential.

OUTPUTS
    None by default
    System.Management.Automation.PSCredential (with -PassThru)
        Returns the removed credential objects when -PassThru is specified.

NOTES
    Platform Support:
    - macOS: Uses Keychain Services via security command
    - Windows: Planned support for Windows Credential Manager

    Security:
    - High impact operation requires confirmation by default
    - Use -Force to bypass confirmation prompts
    - Multiple credentials with same name require -Username specification

EXAMPLES
    Example 1: Remove credential with confirmation
    -------------------------- 
    PS C:\> Remove-StoredCredential -Name "MyService"

    Removes the credential after confirmation prompt.

    Example 2: Remove credential without confirmation
    -------------------------- 
    PS C:\> Remove-StoredCredential -Name "MyService" -Force

    Removes the credential without confirmation.

    Example 3: Remove credential and return object
    -------------------------- 
    PS C:\> Remove-StoredCredential -Name "MyService" -PassThru

    Removes the credential and returns the removed object.

    Example 4: Remove specific credential by username
    -------------------------- 
    PS C:\> Remove-StoredCredential -Name "MyService" -Username "john.doe" -Force

    Removes the specific credential for user "john.doe".

    Example 5: Remove multiple credentials via pipeline
    -------------------------- 
    PS C:\> "Service1", "Service2" | Remove-StoredCredential -Force

    Removes multiple credentials without confirmation.

    Example 6: Preview removal with WhatIf
    -------------------------- 
    PS C:\> Remove-StoredCredential -Name "MyService" -WhatIf

    Shows what would be removed without actually removing anything.

RELATED LINKS
    Get-StoredCredential
    New-StoredCredential
    Set-StoredCredential
    Test-StoredCredential
    Get-CredentialStoreInfo
    about_PoShCredentialStore
