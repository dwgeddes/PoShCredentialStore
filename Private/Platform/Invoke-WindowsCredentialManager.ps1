# PSCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Invoke-WindowsCredentialManager {
    <#
    .SYNOPSIS
        Main dispatcher for Windows Credential Manager operations
    .DESCRIPTION
        Routes credential manager operations to specialized functions for better maintainability
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
    if (-not $IsWindows) {
        throw "Invoke-WindowsCredentialManager can only be used on Windows"
    }
    
    # Route to specialized function
    switch ($Operation) {
        'Get' { return Get-WindowsCredentialItem -Name $Name }
        'Set' { return Set-WindowsCredentialItem -Name $Name -Credential $Credential -Metadata $Metadata }
        'New' { return New-WindowsCredentialItem -Name $Name -Credential $Credential -Metadata $Metadata }
        'Remove' { return Remove-WindowsCredentialItem -Name $Name }
        'List' { return Get-WindowsCredentialList }
        'Test' { return Test-WindowsCredentialItem -Name $Name }
    }
}

function Get-WindowsCredentialItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    $targetName = "PSCredentialStore:$Name"
    
    try {
        $winCred = Microsoft.PowerShell.Security\Get-StoredCredential -Target $targetName -ErrorAction SilentlyContinue
        if ($winCred) {
            $storedMetadata = Get-WindowsCredentialMetadata -Name $Name
            return New-StoredCredentialObject -Name $Name -Credential $winCred -Metadata $storedMetadata
        }
        return $null
    }
    catch {
        Write-Verbose "Failed to retrieve credential from Windows Credential Manager: $_"
        return $null
    }
}

function Set-WindowsCredentialItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter()]
        [hashtable]$Metadata = @{}
    )
    
    $targetName = "PSCredentialStore:$Name"
    
    try {
        # Check if credential exists
        $existing = Microsoft.PowerShell.Security\Get-StoredCredential -Target $targetName -ErrorAction SilentlyContinue
        if (-not $existing) {
            throw "Credential with name '$Name' does not exist. Use New-StoredCredential to create it first."
        }
        
        # Update the credential
        Microsoft.PowerShell.Security\Set-StoredCredential -Target $targetName -Credential $Credential -Comment ($Metadata.Description -or "PSCredentialStore credential")
        
        # Store metadata
        Set-WindowsCredentialMetadata -Name $Name -Metadata $Metadata
        
        return $true
    }
    catch {
        Write-Error "Failed to set credential '$Name' in Windows Credential Manager. Error: $_" -ErrorAction Continue
        return $false
    }
}

function New-WindowsCredentialItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter()]
        [hashtable]$Metadata = @{}
    )
    
    $targetName = "PSCredentialStore:$Name"
    
    try {
        # Check if credential already exists
        $existing = Microsoft.PowerShell.Security\Get-StoredCredential -Target $targetName -ErrorAction SilentlyContinue
        if ($existing) {
            throw "Credential with name '$Name' already exists. Use Set-StoredCredential to update existing credentials."
        }
        
        # Create new credential
        Microsoft.PowerShell.Security\New-StoredCredential -Target $targetName -Credential $Credential -Comment ($Metadata.Description -or "PSCredentialStore credential") -Persist LocalMachine
        
        # Store metadata
        Set-WindowsCredentialMetadata -Name $Name -Metadata $Metadata
        
        return $true
    }
    catch {
        Write-Error "Failed to create credential '$Name' in Windows Credential Manager. Error: $_" -ErrorAction Continue
        return $false
    }
}

function Remove-WindowsCredentialItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    $targetName = "PSCredentialStore:$Name"
    
    try {
        # Remove credential from Windows Credential Manager
        $removed = $false
        try {
            Microsoft.PowerShell.Security\Remove-StoredCredential -Target $targetName -ErrorAction Stop
            $removed = $true
        }
        catch {
            # If not found, consider it removed
            if ($_.Exception.Message -match "not found") {
                $removed = $true
            } else {
                throw
            }
        }
        
        # Remove metadata
        $metadataRemoved = Remove-WindowsCredentialMetadata -Name $Name
        
        return $removed -and $metadataRemoved
    }
    catch {
        Write-Error "Failed to remove credential '$Name' from Windows Credential Manager. Error: $_" -ErrorAction Continue
        return $false
    }
}

function Get-WindowsCredentialList {
    [CmdletBinding()]
    param()
    
    try {
        $results = @()
        $credentials = Microsoft.PowerShell.Security\Get-StoredCredential | Where-Object { $_.Target -like "PSCredentialStore:*" }
        
        foreach ($cred in $credentials) {
            $credName = $cred.Target -replace "^PSCredentialStore:", ""
            $metadata = Get-WindowsCredentialMetadata -Name $credName
            $results += New-StoredCredentialObject -Name $credName -Credential $cred -Metadata $metadata
        }
        
        return $results
    }
    catch {
        Write-Warning "Failed to list credentials from Windows Credential Manager. Error: $_"
        return @()
    }
}

function Test-WindowsCredentialItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    $targetName = "PSCredentialStore:$Name"
    
    try {
        $existing = Microsoft.PowerShell.Security\Get-StoredCredential -Target $targetName -ErrorAction SilentlyContinue
        return $null -ne $existing
    }
    catch {
        return $false
    }
}

function Get-WindowsCredentialMetadata {
    <#
    .SYNOPSIS
        Retrieves metadata for a Windows credential
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    $metadataPath = Join-Path $env:LOCALAPPDATA "PSCredentialStore\metadata\$Name.json"
    
    if (Test-Path $metadataPath) {
        try {
            $content = Get-Content $metadataPath -Raw | ConvertFrom-Json -AsHashtable
            return $content
        }
        catch {
            Write-Verbose "Failed to read metadata for credential '$Name': $_"
        }
    }
    
    return @{}
}

function Set-WindowsCredentialMetadata {
    <#
    .SYNOPSIS
        Stores metadata for a Windows credential
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Metadata
    )
    
    $metadataDir = Join-Path $env:LOCALAPPDATA "PSCredentialStore\metadata"
    if (-not (Test-Path $metadataDir)) {
        New-Item -Path $metadataDir -ItemType Directory -Force | Out-Null
    }
    
    $metadataPath = Join-Path $metadataDir "$Name.json"
    
    try {
        $Metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataPath -Force
        return $true
    }
    catch {
        Write-Warning "Failed to store metadata for credential '$Name': $_"
        return $false
    }
}

function Remove-WindowsCredentialMetadata {
    <#
    .SYNOPSIS
        Removes metadata for a Windows credential
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    $metadataPath = Join-Path $env:LOCALAPPDATA "PSCredentialStore\metadata\$Name.json"
    
    if (Test-Path $metadataPath) {
        try {
            Remove-Item -Path $metadataPath -Force
            return $true
        }
        catch {
            Write-Warning "Failed to remove metadata for credential '$Name': $_"
            return $false
        }
    }
    
    return $true  # Already removed
}