NAME
    Test-StoredCredential

SYNOPSIS
    Tests if a credential exists in the credential store

SYNTAX
    Test-StoredCredential [-Name] <String[]> [-Username <String>] [<CommonParameters>]

DESCRIPTION
    Checks whether a named credential exists in the platform-specific credential store.
    Returns a boolean value indicating existence without retrieving the actual credential.

PARAMETERS
    -Name <String[]>
        Name of the credential(s) to test. Accepts pipeline input.
        
        Required?                    true
        Position?                    0
        Default value                None
        Accept pipeline input?       True (ByValue, ByPropertyName)
        Accept wildcard characters?  false

    -Username <String>
        Specific username to test. Useful for additional specificity when
        multiple credentials exist with the same name.
        
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
        You can pipe credential names to Test-StoredCredential.

OUTPUTS
    System.Boolean
        Returns $true if the credential exists, $false otherwise.

NOTES
    Platform Support:
    - macOS: Uses Keychain Services via security command
    - Windows: Planned support for Windows Credential Manager

    Performance:
    - This is a lightweight operation that doesn't retrieve credential data
    - Useful for conditional logic and validation scenarios
    - Returns false for invalid or inaccessible credentials

EXAMPLES
    Example 1: Test if credential exists
    -------------------------- 
    PS C:\> Test-StoredCredential -Name "MyService"
    True

    Returns $true if credential exists, $false otherwise.

    Example 2: Test specific credential by username
    -------------------------- 
    PS C:\> Test-StoredCredential -Name "MyService" -Username "john.doe"
    False

    Tests for specific username/service combination.

    Example 3: Conditional credential creation
    -------------------------- 
    PS C:\> if (-not (Test-StoredCredential -Name "MyService")) {
    >>     New-StoredCredential -Name "MyService" -Credential $cred
    >> }

    Creates a credential only if it doesn't already exist.

    Example 4: Test multiple credentials via pipeline
    -------------------------- 
    PS C:\> "Service1", "Service2", "Service3" | Test-StoredCredential
    True
    False
    True

    Tests multiple credentials and returns boolean results for each.

    Example 5: Check credentials in a validation script
    -------------------------- 
    PS C:\> $services = @("Database", "API", "Cache")
    PS C:\> $missing = $services | Where-Object { -not (Test-StoredCredential -Name $_) }
    PS C:\> if ($missing) { Write-Warning "Missing credentials: $($missing -join ', ')" }

    Identifies missing credentials from a list of required services.

RELATED LINKS
    Get-StoredCredential
    New-StoredCredential
    Set-StoredCredential
    Remove-StoredCredential
    Get-CredentialStoreInfo
    about_PoShCredentialStore
