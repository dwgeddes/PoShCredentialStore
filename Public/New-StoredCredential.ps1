# PoShCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PoShCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function New-StoredCredential {
    <#
    .SYNOPSIS
        Creates a new stored credential
    .DESCRIPTION
        Creates and stores a new credential in the platform-specific credential store
    .PARAMETER UserName
        Username for the credential
    .PARAMETER Password
        SecureString password for the credential  
    .PARAMETER Credential
        PSCredential object to store
    .PARAMETER Name
        Name to store the credential under
    .PARAMETER Comment
        Optional comment/description for the credential
    .PARAMETER Force
        Overwrite existing credential if it exists
    .EXAMPLE
        New-StoredCredential -UserName "TestUser" -Password (ConvertTo-SecureString "Password" -AsPlainText -Force) -Name "MyService" -Comment "Production service account"
        Creates and stores a credential with a comment
    .EXAMPLE
        $cred = Get-Credential; New-StoredCredential -Credential $cred -Name "MyService"
        Creates and stores a credential from existing PSCredential
    .OUTPUTS
        PSCredential object for the newly created credential
    #>
    [CmdletBinding(DefaultParameterSetName = 'CreateNew')]
    [OutputType([System.Management.Automation.PSCredential])]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'CreateNew')]
        [ValidateNotNullOrEmpty()]
        [string]$UserName,
        
        [Parameter(Mandatory, Position = 1, ParameterSetName = 'CreateNew')]
        [ValidateNotNull()]
        [SecureString]$Password,
        
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ParameterSetName = 'FromCredential')]
        [ValidateNotNull()]
        [PSCredential]$Credential,
        
        [Parameter(Mandatory, Position = 2, ParameterSetName = 'CreateNew')]
        [Parameter(Mandatory, Position = 1, ParameterSetName = 'FromCredential')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter()]
        [string]$Comment,
        
        [Parameter()]
        [switch]$Force
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
        
        try {
            # Check if credential already exists
            $existingCred = Get-StoredCredential -Name $Name -ErrorAction SilentlyContinue
            if ($existingCred -and -not $Force) {
                Write-Error -Message "Credential '$Name' already exists. Use -Force to overwrite." -ErrorAction Stop
            }

            # Determine final credential values
            if ($PSCmdlet.ParameterSetName -eq 'FromCredential') {
                $UserName = $Credential.UserName
                $Password = $Credential.Password
            }
            
            Write-Verbose "Creating credential '$Name' for user '$UserName'"
            
            # Store using macOS keychain
            $result = $null
                    
            if ($existingCred -and $Force) {
                $result = Set-MacOSKeychainItem -Name $Name -Username $UserName -Password $Password -Comment $Comment
            } else {
                $result = New-MacOSKeychainItem -Name $Name -Username $UserName -Password $Password -Comment $Comment
            }

            if ($result) {
                Write-Verbose "Credential '$Name' stored successfully"
                Write-Output $result
            } else {
                Write-Error -Message "Failed to store credential '$Name'" -ErrorAction Continue
                Write-Output $null
            }
        }
        catch {
            Write-Error -Message "Failed to create credential '$Name': $($_.Exception.Message)" -ErrorAction Continue
            Write-Output $null
        }
    }
}
