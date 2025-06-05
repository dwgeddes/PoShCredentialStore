NAME
    Get-StoredCredential

SYNOPSIS
    Retrieves a stored credential from the credential store

SYNTAX
    Get-StoredCredential [[-Name] <String[]>] [-Username <String>] [<CommonParameters>]

DESCRIPTION
    Gets a previously stored credential from the platform-specific credential store.
    If no name is specified, returns all stored credentials. Supports filtering by
    username when multiple credentials exist with the same name.

PARAMETERS
    -Name <String[]>
        Name of the credential(s) to retrieve. Accepts pipeline input.
        If not specified, returns all stored credentials.
        
        Required?                    false
        Position?                    0
        Default value                None
        Accept pipeline input?       True (ByValue, ByPropertyName)
        Accept wildcard characters?  false

    -Username <String>
        Username of the credential to retrieve. Useful when multiple credentials
        exist with the same name.
        
        Required?                    false
        Position?                    named
        Default value                None
        Accept pipeline input?       false
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable.

INPUTS
    System.String[]
        You can pipe credential names to Get-StoredCredential.

OUTPUTS
    System.Management.Automation.PSCredential
        Returns PSCredential objects with extended properties (Name, Comment, 
        Created, Modified).

NOTES
    Platform Support:
    - macOS: Uses Keychain Services via security command
    - Windows: Planned support for Windows Credential Manager

    The returned PSCredential objects include additional properties:
    - Name: The credential identifier
    - Comment: Optional description
    - Created: Creation timestamp
    - Modified: Last modification timestamp

EXAMPLES
    Example 1: Get a specific credential
    -------------------------- 
    PS C:\> Get-StoredCredential -Name "MyService"

    Returns the credential named "MyService".

    Example 2: Get credential with specific username
    -------------------------- 
    PS C:\> Get-StoredCredential -Name "MyService" -Username "john.doe"

    Returns the credential named "MyService" for user "john.doe".

    Example 3: List all stored credentials
    -------------------------- 
    PS C:\> Get-StoredCredential

    Returns all stored credentials in the credential store.

    Example 4: Get multiple credentials via pipeline
    -------------------------- 
    PS C:\> "Service1", "Service2" | Get-StoredCredential

    Returns credentials for Service1 and Service2.

RELATED LINKS
    New-StoredCredential
    Set-StoredCredential
    Remove-StoredCredential
    Test-StoredCredential
    Get-CredentialStoreInfo
    about_PoShCredentialStore
