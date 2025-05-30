function ConvertTo-SecureCredential {
    <#
    .SYNOPSIS
    Converts a PSCredential to encrypted data for storage.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCredential]$Credential
    )
    
    try {
        if ([string]::IsNullOrEmpty($Credential.UserName)) {
            throw "Credential username cannot be null or empty"
        }
        
        $encryptedPassword = $Credential.Password | ConvertFrom-SecureString
        
        if ([string]::IsNullOrEmpty($encryptedPassword)) {
            throw "Failed to encrypt credential password"
        }
        
        return @{
            Username = $Credential.UserName
            EncryptedPassword = $encryptedPassword
            Timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
            Platform = $PSVersionTable.Platform
            PSVersion = $PSVersionTable.PSVersion.ToString()
        }
    }
    catch {
        throw "Failed to encrypt credential: $($_.Exception.Message)"
    }
}
