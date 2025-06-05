NAME
    New-StoredCredential

SYNOPSIS
    Creates a new stored credential

SYNTAX
    New-StoredCredential [-UserName] <String> [-Password] <SecureString> [-Name] <String> [-Comment <String>] [-Force] [<CommonParameters>]
    
    New-StoredCredential [-Credential] <PSCredential> [-Name] <String> [-Comment <String>] [-Force] [<CommonParameters>]

DESCRIPTION
    Creates and stores a new credential in the platform-specific credential store.
    Can accept either username/password parameters or a PSCredential object.

PARAMETERS
    -UserName <String>
        Username for the credential.
        
        Required?                    true
        Position?                    0
        Default value                None
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -Password <SecureString>
        SecureString password for the credential.
        
        Required?                    true
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
        Name to store the credential under.
        
        Required?                    true
        Position?                    2 (CreateNew), 1 (FromCredential)
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
        Overwrite existing credential if it exists.
        
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
        You can pipe PSCredential objects to New-StoredCredential.

OUTPUTS
    System.Management.Automation.PSCredential
        Returns the newly created credential object with extended properties.

NOTES
    Platform Support:
    - macOS: Uses Keychain Services via security command
    - Windows: Planned support for Windows Credential Manager

    Security:
    - Passwords must be provided as SecureString objects
    - Credentials are stored using platform-native security mechanisms
    - Memory cleanup is performed after operations

EXAMPLES
    Example 1: Create credential with username and password
    -------------------------- 
    PS C:\> $securePass = ConvertTo-SecureString "MyPassword" -AsPlainText -Force
    PS C:\> New-StoredCredential -UserName "TestUser" -Password $securePass -Name "MyService" -Comment "Production service account"

    Creates a new credential with a comment.

    Example 2: Create credential from PSCredential object
    -------------------------- 
    PS C:\> $cred = Get-Credential
    PS C:\> New-StoredCredential -Credential $cred -Name "MyService"

    Creates a credential from an existing PSCredential object.

    Example 3: Overwrite existing credential
    -------------------------- 
    PS C:\> New-StoredCredential -UserName "NewUser" -Password $securePass -Name "ExistingService" -Force

    Overwrites an existing credential with the -Force parameter.

RELATED LINKS
    Get-StoredCredential
    Set-StoredCredential
    Remove-StoredCredential
    Test-StoredCredential
    Get-CredentialStoreInfo
    about_PoShCredentialStore
