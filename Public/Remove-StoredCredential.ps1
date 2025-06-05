# PSCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Remove-StoredCredential {
    <#
    .SYNOPSIS
        Removes a credential from the credential store
    .DESCRIPTION
        Deletes a stored credential from the platform-specific credential store
    .PARAMETER Name
        Name of the credential to remove
    .PARAMETER Username
        Specific username to remove (required for macOS when multiple credentials exist with same name)
    .PARAMETER Force
        Remove without confirmation
    .PARAMETER PassThru
        Return the removed credential objects
    .EXAMPLE
        Remove-StoredCredential -Name "MyService" -Force
        Removes the credential named "MyService" without confirmation
    .EXAMPLE
        Remove-StoredCredential -Name "MyService" -PassThru
        Removes the credential and returns the removed object
    .OUTPUTS
        None by default, removed credential objects with -PassThru
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([System.Management.Automation.PSCredential])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,
        
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Username,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$PassThru
    )
    
    process {
        # Validate supported platform
        if (-not $script:IsMacOS) {
            Write-Error -Message "Platform not supported. This module only supports macOS credential stores." -ErrorAction Stop
        }
        
        foreach ($credName in $Name) {
            try {
                # Validate credential name
                if ([string]::IsNullOrWhiteSpace($credName)) {
                    Write-Warning "Skipping empty or null credential name"
                    continue
                }

                Write-Verbose "Checking if credential '$credName' exists"
                
                # Get existing credential(s) - handle username parameter consistently
                $existingCreds = if ($Username) {
                    Get-StoredCredential -Name $credName -Username $Username -ErrorAction SilentlyContinue
                }
                else {
                    Get-StoredCredential -Name $credName -ErrorAction SilentlyContinue
                }
                
                if (-not $existingCreds) {
                    Write-Warning "Credential '$credName' not found"
                    continue
                }
                
                # Handle multiple credentials case - require username specification
                if ($existingCreds -is [System.Array] -and $existingCreds.Count -gt 1) {
                    if (-not $Username) {
                        $usernames = $existingCreds | ForEach-Object { $_.UserName } | Sort-Object -Unique
                        Write-Error -Message "Multiple credentials found for '$credName' with usernames: $($usernames -join ', '). Please specify -Username parameter to identify which credential to remove." -ErrorAction Stop
                    }
                }
                
                # Confirm removal unless -Force is specified
                if (-not $Force -and -not $PSCmdlet.ShouldProcess($credName, "Remove stored credential")) {
                    continue
                }
                
                Write-Verbose "Removing credential '$credName'"
                # Remove from macOS keychain
                try {
                    Remove-MacOSKeychainItem -Name $credName -Username $existingCreds.Username -ErrorAction Stop
                    if ($PassThru) {
                        $removedCred = New-StoredCredentialObject -Name $credName -Username $existingCreds.Username -Comment $existingCreds.Comment -DateCreated $existingCreds.Created -DateModified $existingCreds.Modified -Result "Removed"
                        Write-Output $removedCred
                    }
                }
                Catch {
                    Write-Error -Message "Failed to remove credential '$credName'" -ErrorAction Continue
                }
            }
            catch {
                Write-Error -Message "Failed to remove credential '$credName': $($_.Exception.Message)" -ErrorAction Continue
            }
        }
    }
}