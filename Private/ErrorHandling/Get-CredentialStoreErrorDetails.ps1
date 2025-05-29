# PSCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Get-CredentialStoreErrorDetails {
    <#
    .SYNOPSIS
        Analyzes exceptions and provides standardized error information with platform-specific guidance
    .DESCRIPTION
        Examines credential store exceptions and returns standardized error details including
        platform-specific recommendations and categorization for consistent error handling.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Exception]$Exception,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('Get', 'Set', 'Remove', 'List', 'Test', 'New')]
        [string]$OperationType,
        
        [Parameter()]
        [object]$CredentialIdentifier
    )
    
    $platform = Get-OSPlatform
    
    # Create base error details
    $errorDetails = @{
        ErrorIdentifier = "Credential${OperationType}OperationFailed"
        ErrorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
        RecommendedUserAction = "Verify the credential identifier and try the operation again"
        AffectedObject = $CredentialIdentifier
        Platform = $platform
    }
    
    # Analyze by exception type
    $errorDetails = Add-ExceptionTypeAnalysis -ErrorDetails $errorDetails -Exception $Exception -OperationType $OperationType -CredentialIdentifier $CredentialIdentifier
    
    # Add platform-specific analysis
    $errorDetails = Add-PlatformSpecificAnalysis -ErrorDetails $errorDetails -Exception $Exception -Platform $platform
    
    return $errorDetails
}

function Add-ExceptionTypeAnalysis {
    [CmdletBinding()]
    param($ErrorDetails, $Exception, $OperationType, $CredentialIdentifier)
    
    switch ($Exception.GetType().Name) {
        'ArgumentException' {
            $ErrorDetails.ErrorIdentifier = "InvalidCredentialIdentifier"
            $ErrorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $ErrorDetails.RecommendedUserAction = "Provide a valid credential identifier that meets naming requirements. Use Test-CredentialId to validate identifier format."
        }
        'ArgumentNullException' {
            $ErrorDetails.ErrorIdentifier = "MissingRequiredParameter"
            $ErrorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $ErrorDetails.RecommendedUserAction = "Provide all required parameters for the $OperationType operation."
        }
        'UnauthorizedAccessException' {
            $ErrorDetails.ErrorIdentifier = "CredentialStoreAccessDenied"
            $ErrorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::PermissionDenied
            $ErrorDetails.RecommendedUserAction = Get-PlatformAccessRecommendation -Platform $ErrorDetails.Platform
        }
        'FileNotFoundException' {
            $ErrorDetails.ErrorIdentifier = "CredentialStoreServiceUnavailable"
            $ErrorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::ResourceUnavailable
            $ErrorDetails.RecommendedUserAction = Get-PlatformServiceRecommendation -Platform $ErrorDetails.Platform
        }
        'InvalidOperationException' {
            if ($Exception.Message -match "not found|does not exist") {
                $ErrorDetails.ErrorIdentifier = "CredentialNotFound"
                $ErrorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::ObjectNotFound
                $ErrorDetails.RecommendedUserAction = "The credential '$CredentialIdentifier' was not found. Use Get-StoredCredential to list available credentials."
            } elseif ($Exception.Message -match "already exists") {
                $ErrorDetails.ErrorIdentifier = "CredentialAlreadyExists"
                $ErrorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::ResourceExists
                $ErrorDetails.RecommendedUserAction = "A credential with identifier '$CredentialIdentifier' already exists. Use Set-StoredCredential to update existing credentials."
            }
        }
    }
    
    return $ErrorDetails
}

function Add-PlatformSpecificAnalysis {
    [CmdletBinding()]
    param($ErrorDetails, $Exception, $Platform)
    
    if ([string]::IsNullOrEmpty($Exception.Message)) {
        return $ErrorDetails
    }
    
    switch ($Platform) {
        'Windows' {
            if ($Exception.Message -match "0x80070490|ERROR_NOT_FOUND") {
                $ErrorDetails.ErrorIdentifier = "CredentialNotFoundInWindowsStore"
                $ErrorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::ObjectNotFound
                $ErrorDetails.RecommendedUserAction = "The credential was not found in Windows Credential Manager. Verify the credential name and check if it was previously stored."
            }
        }
        'MacOS' {
            if ($Exception.Message -match "errSecItemNotFound") {
                $ErrorDetails.ErrorIdentifier = "CredentialNotFoundInKeychain"
                $ErrorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::ObjectNotFound
                $ErrorDetails.RecommendedUserAction = "The credential was not found in macOS Keychain. Verify the credential name and check if it was previously stored."
            }
        }
        'Linux' {
            if ($Exception.Message -match "No such secret|secret not found") {
                $ErrorDetails.ErrorIdentifier = "CredentialNotFoundInSecretService"
                $ErrorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::ObjectNotFound
                $ErrorDetails.RecommendedUserAction = "The credential was not found in Linux Secret Service. Verify the credential name and check if it was previously stored."
            }
        }
    }
    
    return $ErrorDetails
}

function Get-PlatformAccessRecommendation {
    [CmdletBinding()]
    param([string]$Platform)
    
    switch ($Platform) {
        'Windows' { return "Run PowerShell as administrator or verify Windows Credential Manager permissions" }
        'MacOS' { return "Unlock your keychain or grant keychain access permissions to PowerShell" }
        'Linux' { return "Verify D-Bus session exists and secret service permissions are correct" }
        default { return "Check credential store access permissions for your platform" }
    }
}

function Get-PlatformServiceRecommendation {
    [CmdletBinding()]
    param([string]$Platform)
    
    switch ($Platform) {
        'Windows' { return "Ensure Windows Credential Manager service is running and accessible" }
        'MacOS' { return "Verify macOS Keychain Services are available and the 'security' command is accessible" }
        'Linux' { return "Install libsecret-tools package and ensure secret service daemon is running" }
        default { return "Verify credential store service is available on your platform" }
    }
}
