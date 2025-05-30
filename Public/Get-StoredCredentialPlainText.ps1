function Get-StoredCredentialPlainText {
    <#
    .SYNOPSIS
        Retrieves stored credentials with passwords in plain text format
    .DESCRIPTION
        Gets previously saved credentials from the native credential store and returns the password
        as plain text. This function should be used with extreme caution as it exposes sensitive
        password information in an unencrypted format.
    .PARAMETER Name
        The unique name of the credential to retrieve. Supports pipeline input.
    .EXAMPLE
        Get-StoredCredentialPlainText -Name "MyApp"
        # Retrieves the credential named "MyApp" with plain text password
    .EXAMPLE
        "App1", "App2" | Get-StoredCredentialPlainText
        # Retrieves multiple credentials via pipeline with plain text passwords
    .OUTPUTS
        [PSCustomObject] Credential object with plain text password
    .NOTES
        WARNING: This function returns passwords in plain text format. Use with extreme caution
        and ensure the output is properly secured and not logged.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    
    process {
        # Pipeline null input: skip processing
        if ($null -eq $Name) { return }

        try {
            Write-Warning "This function returns passwords in plain text. Use with caution."
            Write-Verbose "Starting credential retrieval for '$Name'"
            
            # Get the stored credential (assuming Get-StoredCredential exists)
            Write-Verbose "Calling Get-StoredCredential for '$Name'"
            $storedCred = Get-StoredCredential -Name $Name
            if (-not $storedCred) {
                Write-Warning "Credential '$Name' not found"
                return @()
            }
            Write-Verbose "Retrieved credential object of type: $($storedCred.GetType().Name)"
            
            # Validate the credential object structure (New API format)
            if (-not $storedCred.Password) {
                Write-Error "Stored credential '$Name' has no Password property"
                return @()
            }
            Write-Verbose "Password SecureString exists, type: $($storedCred.Password.GetType().Name)"
            
            # Convert SecureString to plain text using working helper function
            Write-Verbose "Converting SecureString to plain text"
            $plainPassword = ConvertFrom-SecureStringToPlainText -SecureString $storedCred.Password
            Write-Verbose "Plain text conversion successful, length: $($plainPassword.Length)"
            
            [PSCustomObject]@{
                Username = $storedCred.Username
                Password = $plainPassword
                Name = $Name
                RetrievedAt = Get-Date
            }
        }
        catch {
            Write-Error "Error retrieving credential '$Name': $($_.Exception.Message)"
            Write-Verbose "Exception type: $($_.Exception.GetType().Name)"
            Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
            if ($_.Exception.InnerException) {
                Write-Verbose "Inner exception: $($_.Exception.InnerException.Message)"
            }
            return @()
        }
    }
}
