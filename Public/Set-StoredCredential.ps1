# PSCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Set-StoredCredential {
    <#
    .SYNOPSIS
        Updates an existing stored credential
    .DESCRIPTION
        Updates or creates a credential in the platform-specific credential store
    .PARAMETER UserName
        Username for the credential (optional when updating existing credential)
    .PARAMETER Password
        SecureString password for the credential
    .PARAMETER Credential
        PSCredential object to store
    .PARAMETER Name
        Name to store the credential under
    .PARAMETER Comment
        Optional comment/description for the credential
    .PARAMETER Force
        Create credential if it doesn't exist
    .PARAMETER PassThru
        Return the updated credential object
    .EXAMPLE
        Set-StoredCredential -Name "MyService" -Comment "Updated comment only"
        Updates only the comment of an existing credential without changing the password
    .EXAMPLE
        Set-StoredCredential -UserName "TestUser" -Password (ConvertTo-SecureString "Password" -AsPlainText -Force) -Name "MyService" -Comment "Updated password"
        Updates an existing credential with a new password and comment
    .EXAMPLE
        $cred = Get-Credential; Set-StoredCredential -Credential $cred -Name "MyService" -PassThru
        Updates a credential from existing PSCredential and returns the updated object
    .OUTPUTS
        None by default, PSCredential object with -PassThru
    #>
    [CmdletBinding(DefaultParameterSetName = 'CreateNew')]
    [OutputType([System.Management.Automation.PSCredential])]
    param(
        [Parameter(Position = 0, ParameterSetName = 'CreateNew')]
        [ValidateNotNullOrEmpty()]
        [string]$UserName,
        
        [Parameter(Position = 1, ParameterSetName = 'CreateNew')]
        [ValidateNotNull()]
        [SecureString]$Password,
        
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ParameterSetName = 'FromCredential')]
        [ValidateNotNull()]
        [PSCredential]$Credential,
        
        [Parameter(Mandatory, Position = 1, ParameterSetName = 'CreateNew')]
        [Parameter(Mandatory, Position = 1, ParameterSetName = 'FromCredential')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter()]
        [string]$Comment,
        
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
        
        # Validate credential name
        if ([string]::IsNullOrWhiteSpace($Name)) {
            Write-Error -Message "Name parameter cannot be empty" -ErrorAction Stop
        }

        # Determine final credential values
        if ($PSCmdlet.ParameterSetName -eq 'FromCredential') {
            $UserName = $Credential.UserName
            $Password = $Credential.Password
        }
        
        # Check if credential exists - handle username parameter consistently
        $existingCred = Get-StoredCredential -Name $Name -ErrorAction SilentlyContinue
        
        # Handle multiple credentials case - require username specification
        if ($existingCred -is [System.Array] -and $existingCred.Count -gt 1) {
            if (-not $UserName) {
                $usernames = $existingCred | ForEach-Object { $_.UserName } | Sort-Object -Unique
                Write-Error -Message "Multiple credentials found for '$Name' with usernames: $($usernames -join ', '). Please specify -Username parameter to identify which credential to update." -ErrorAction Stop
            }
        }
        
        # If credential doesn't exist and -Force is not specified, error
        if (-not $existingCred -and -not $Force) {
            Write-Error -Message "Credential '$Name' does not exist. Use New-StoredCredential to create it." -ErrorAction Stop
        }

        try {
            
            # If updating existing credential and no username provided, use existing username
            if ($existingCred -and -not $UserName) {
                $UserName = $existingCred.UserName
            }
            
            # If updating existing credential and no password provided, keep existing password
            if ($existingCred -and -not $Password) {
                $Password = $existingCred.Password
            }
            
            Write-Verbose "Setting credential '$Name' for user '$UserName'"
            
            # Store using macOS keychain
            $result = $null
                    
            if ($existingCred) {
                $result = Set-MacOSKeychainItem -Name $Name -Username $UserName -Password $Password -Comment $Comment
            } else {
                $result = New-MacOSKeychainItem -Name $Name -Username $UserName -Password $Password -Comment $Comment
            }

            if ($result) {
                Write-Verbose "Credential '$Name' updated successfully"
                if ($PassThru) {
                    Write-Output $result
                }
            } else {
                Write-Error -Message "Failed to update credential '$Name'" -ErrorAction Continue
            }
        }
        catch {
            Write-Error -Message "Failed to set credential '$Name': $($_.Exception.Message)" -ErrorAction Continue
        }
    }
}
