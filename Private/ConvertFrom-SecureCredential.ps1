function ConvertFrom-SecureCredential {
    <#
    .SYNOPSIS
    Converts encrypted credential data back to a PSCredential.
    #>
    [CmdletBinding()]
    [OutputType([PSCredential])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [hashtable]$EncryptedData
    )
    
    try {
        if (-not $EncryptedData.ContainsKey('Username') -or [string]::IsNullOrEmpty($EncryptedData.Username)) {
            throw "Encrypted data missing or invalid username"
        }
        
        if (-not $EncryptedData.ContainsKey('EncryptedPassword') -or [string]::IsNullOrEmpty($EncryptedData.EncryptedPassword)) {
            throw "Encrypted data missing or invalid password"
        }
        
        $securePassword = $EncryptedData.EncryptedPassword | ConvertTo-SecureString
        $credential = New-Object PSCredential($EncryptedData.Username, $securePassword)
        
        if ($null -eq $credential -or [string]::IsNullOrEmpty($credential.UserName)) {
            throw "Failed to create valid PSCredential object"
        }
        
        return $credential
    }
    catch {
        throw "Failed to decrypt credential: $($_.Exception.Message)"
    }
}
