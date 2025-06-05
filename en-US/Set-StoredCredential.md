NAME
    Set-StoredCredential

SYNOPSIS
    Updates an existing stored credential

SYNTAX
    Set-StoredCredential [[-UserName] <String>] [[-Password] <SecureString>] [-Name] <String> [-Comment <String>] [-Force] [-PassThru] [<CommonParameters>]
    
    Set-StoredCredential [-Credential] <PSCredential> [-Name] <String> [-Comment <String>] [-Force] [-PassThru] [<CommonParameters>]

DESCRIPTION
    Updates or creates a credential in the platform-specific credential store.
    Can update individual properties (username, password, comment) or replace
    the entire credential using a PSCredential object.

PARAMETERS
    -UserName <String>
        Username for the credential. Optional when updating existing credential.
        
        Required?                    false
        Position?                    0
        Default value                None
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -Password <SecureString>
        SecureString password for the credential. Optional when updating existing credential.
        
        Required?                    false
        Position?                    1
        Default value                None
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -Credential <PSCredential>
        PSCredential object to store.
        
        Required?                    true
        Position?                    0
        Default value                None
        Accept pipeline input?       True (ByValue)
        Accept wildcard characters?  false

    -Name <String>
        Name of the credential to update.
        
        Required?                    true
        Position?                    1
        Default value                None
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -Comment <String>
        Optional comment/description for the credential.
        
        Required?                    false
        Position?                    named
        Default value                None
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -Force [<SwitchParameter>]
        Create credential if it doesn't exist.
        
        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -PassThru [<SwitchParameter>]
        Return the updated credential object.
        
        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable.

INPUTS
    System.Management.Automation.PSCredential
        You can pipe PSCredential objects to Set-StoredCredential.

OUTPUTS
    None by default
    System.Management.Automation.PSCredential (with -PassThru)
        Returns the updated credential object when -PassThru is specified.

NOTES
    Platform Support:
    - macOS: Uses Keychain Services via security command
    - Windows: Planned support for Windows Credential Manager

    Behavior:
    - If the credential doesn't exist and -Force is not specified, an error is thrown
    - Omitted parameters retain their existing values from the stored credential
    - When multiple credentials exist with the same name, -Username must be specified

EXAMPLES
    Example 1: Update only the comment
    -------------------------- 
    PS C:\> Set-StoredCredential -Name "MyService" -Comment "Updated comment only"

    Updates only the comment of an existing credential without changing the password.

    Example 2: Update password and comment
    -------------------------- 
    PS C:\> $newPass = ConvertTo-SecureString "NewPassword" -AsPlainText -Force
    PS C:\> Set-StoredCredential -Name "MyService" -Password $newPass -Comment "Updated password"

    Updates both the password and comment of an existing credential.

    Example 3: Update from PSCredential object
    -------------------------- 
    PS C:\> $cred = Get-Credential
    PS C:\> Set-StoredCredential -Credential $cred -Name "MyService" -PassThru

    Updates a credential from PSCredential and returns the updated object.

    Example 4: Create credential if it doesn't exist
    -------------------------- 
    PS C:\> Set-StoredCredential -Name "NewService" -UserName "TestUser" -Password $securePass -Force

    Creates a new credential if it doesn't exist using the -Force parameter.

RELATED LINKS
    Get-StoredCredential
    New-StoredCredential
    Remove-StoredCredential
    Test-StoredCredential
    Get-CredentialStoreInfo
    about_PoShCredentialStore
