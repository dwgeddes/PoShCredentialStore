# PSCredentialStore - PowerShell credential management module for macOS
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Invoke-MacOSKeychain {
    <#
    .SYNOPSIS
        Main dispatcher for macOS Keychain operations
    .DESCRIPTION
        Routes keychain operations to specialized functions for better maintainability
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Get', 'Set', 'Remove', 'List', 'Test', 'New')]
        [string]$Operation,
        
        [Parameter()]
        [string]$Name,
        
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter()]
        [hashtable]$Metadata = @{}
    )
    
    # Validate platform
    if (-not $IsMacOS) {
        throw "Invoke-MacOSKeychain can only be used on macOS"
    }
    
    # Route to specialized function
    switch ($Operation) {
        'Get' { return Get-MacOSKeychainItem -Name $Name }
        'Set' { return Set-MacOSKeychainItem -Name $Name -Credential $Credential -Metadata $Metadata }
        'New' { return New-MacOSKeychainItem -Name $Name -Credential $Credential -Metadata $Metadata }
        'Remove' { return Remove-MacOSKeychainItem -Name $Name }
        'List' { return Get-MacOSKeychainList }
        'Test' { return Test-MacOSKeychainItem -Name $Name }
    }
}

function Get-MacOSKeychainItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    $serviceName = "PSCredentialStore:$Name"
    
    try {
        $passwordOutput = security find-generic-password -s $serviceName -a $Name -w 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($passwordOutput)) {
            return $null
        }
        
        $storedMetadata = Invoke-MetadataOperation -Operation Get -Name $Name
        $username = $storedMetadata.UserName ?? $Name
        
        $securePassword = ConvertTo-SecureString $passwordOutput -AsPlainText -Force
        $credential = [System.Management.Automation.PSCredential]::new($username, $securePassword)
        
        return New-StoredCredentialObject -Name $Name -Credential $credential -Metadata $storedMetadata
    }
    catch {
        Write-Verbose "Failed to retrieve credential: $_"
        return $null
    }
}

function Set-MacOSKeychainItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter()]
        [hashtable]$Metadata = @{}
    )
    
    $serviceName = "PSCredentialStore:$Name"
    
    # Check existence first
    security find-generic-password -s $serviceName -a $Name -w 2>$null 1>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Credential with name '$Name' does not exist. Use New-StoredCredential to create it first."
    }

    try {
        $password = $Credential.GetNetworkCredential().Password
        
        # Remove and recreate for update
        security delete-generic-password -s $serviceName -a $Name 2>&1 >$null
        
        # Add with standard flags
        $addArgs = @('-s', $serviceName, '-a', $Name, '-w', $password, '-U')
        
        $addResult = security add-generic-password @addArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to update credential in Keychain. Output: $addResult"
        }

        # Update metadata - get existing metadata first, then merge with new
        $existingMetadata = Invoke-MetadataOperation -Operation Get -Name $Name
        $combinedMetadata = $existingMetadata.Clone()
        
        # Merge in the new metadata
        foreach ($key in $Metadata.Keys) {
            $combinedMetadata[$key] = $Metadata[$key]
        }
        
        # Always update UserName to match credential
        $combinedMetadata['UserName'] = $Credential.UserName
        
        Invoke-MetadataOperation -Operation Set -Name $Name -Metadata $combinedMetadata

        return $true
    }
    catch {
        Write-Error "Failed to set credential '$Name': $_" -ErrorAction Continue
        return $false
    }
}

function New-MacOSKeychainItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter()]
        [hashtable]$Metadata = @{}
    )
    
    $serviceName = "PSCredentialStore:$Name"
    
    # Check if already exists
    security find-generic-password -s $serviceName -a $Name -w 2>$null 1>$null
    if ($LASTEXITCODE -eq 0) {
        throw "Credential with name '$Name' already exists. Use Set-StoredCredential to update existing credentials."
    }

    try {
        $password = $Credential.GetNetworkCredential().Password
        
        # Create with standard flags
        $addArgs = @('-s', $serviceName, '-a', $Name, '-w', $password, '-U')
        
        $addResult = security add-generic-password @addArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create credential in Keychain. Output: $addResult"
        }

        # Store metadata
        $combinedMetadata = $Metadata.Clone()
        $combinedMetadata.UserName = $Credential.UserName
        Invoke-MetadataOperation -Operation Set -Name $Name -Metadata $combinedMetadata

        return $true
    }
    catch {
        Write-Error "Failed to create credential '$Name': $_" -ErrorAction Continue
        return $false
    }
}

function Remove-MacOSKeychainItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    $serviceName = "PSCredentialStore:$Name"
    
    try {
        # Remove from keychain (ignore exit code 44 = not found)
        security delete-generic-password -s $serviceName -a $Name 2>$null 1>$null
        $keychainSuccess = ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 44)
        
        # Remove metadata
        $metadataSuccess = Invoke-MetadataOperation -Operation Remove -Name $Name
        
        return $keychainSuccess -and $metadataSuccess
    }
    catch {
        Write-Error "Failed to remove credential '$Name': $_" -ErrorAction Continue
        return $false
    }
}

function Get-MacOSKeychainList {
    [CmdletBinding()]
    param()
    
    try {
        $results = @()
        $config = Get-ModuleConfiguration
        
        if (-not (Test-Path $config.MetadataPath)) {
            return $results
        }
        
        # Get all metadata files and process efficiently
        Get-ChildItem -Path $config.MetadataPath -Filter "*.json" | ForEach-Object {
            $credName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            $currentServiceName = "PSCredentialStore:$credName"
            
            try {
                # Check keychain and get password
                $password = security find-generic-password -s $currentServiceName -a $credName -w 2>$null
                if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($password)) {
                    $metadata = Invoke-MetadataOperation -Operation Get -Name $credName
                    $username = $metadata.UserName ?? $credName
                    
                    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
                    $credential = [System.Management.Automation.PSCredential]::new($username, $securePassword)
                    
                    $results += New-StoredCredentialObject -Name $credName -Credential $credential -Metadata $metadata
                }
            }
            catch {
                Write-Verbose "Could not retrieve credential for '$credName': $_"
            }
        }
        
        return $results
    }
    catch {
        Write-Warning "Failed to list credentials: $_"
        return @()
    }
}

function Test-MacOSKeychainItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    $serviceName = "PSCredentialStore:$Name"
    
    try {
        security find-generic-password -s $serviceName -a $Name -w 2>$null 1>$null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}