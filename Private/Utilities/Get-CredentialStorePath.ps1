function Get-CredentialStorePath {
    <#
    .SYNOPSIS
    Gets the file system path for storing credentials on non-Windows platforms.
    
    .DESCRIPTION
    Generates cross-platform file paths for credential storage, following
    platform-specific conventions for secure storage locations.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter()]
        [ValidateSet('User', 'Machine')]
        [string]$Scope = 'User'
    )
    
    # Sanitize the name for use in file path
    $safeName = $Name -replace '[^\w\-_.]', '_'
    $scopeLower = $Scope.ToLower()
    
    if ($Scope -eq 'Machine') {
        if ($PSVersionTable.Platform -eq 'Unix') {
            $basePath = '/etc/poshcredentialstore'
        } else {
            $basePath = Join-Path $env:ProgramData 'PoShCredentialStore'
        }
    } else {
        if ($PSVersionTable.Platform -eq 'Unix') {
            $basePath = Join-Path $env:HOME '.poshcredentialstore'
        } elseif ($env:APPDATA) {
            $basePath = Join-Path $env:APPDATA 'PoShCredentialStore'
        } else {
            $basePath = Join-Path $env:USERPROFILE 'AppData\Roaming\PoShCredentialStore'
        }
    }
    
    $scopePath = Join-Path $basePath $scopeLower
    return Join-Path $scopePath "$safeName.cred"
}
