
function ConvertFrom-SecureStringToPlainText {
    <#
    .SYNOPSIS
    Converts a SecureString to plain text safely.
    
    .DESCRIPTION
    Internal helper function that properly converts SecureString objects to plain text
    using the correct BSTR conversion method. Ensures proper memory cleanup.
    
    .PARAMETER SecureString
    The SecureString to convert to plain text.
    
    .OUTPUTS
    [string] The plain text representation of the SecureString.
    
    .NOTES
    This function is based on the working solution provided by the user.
    Uses PtrToStringBSTR (not PtrToStringUni) for proper BSTR conversion.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Security.SecureString]$SecureString
    )
    
    try {
        # Convert SecureString to BSTR
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        
        # Convert BSTR to plaintext string using the correct method
        $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        
        return $plainText
    }
    finally {
        # Clean up the BSTR pointer for security
        if ($bstr -ne [System.IntPtr]::Zero) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}
