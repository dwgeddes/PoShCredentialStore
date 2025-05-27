# PSCredentialStore - PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function New-CredentialOperationTemplate {
    <#
    .SYNOPSIS
        Creates standardized operation templates for credential functions
    .DESCRIPTION
        Provides reusable templates for common credential operation patterns,
        ensuring consistency across all public functions while reducing code duplication.
    .PARAMETER OperationType
        The type of credential operation (CRUD, Validation, Query)
    .PARAMETER RequiresCredential
        Whether the operation requires a credential parameter
    .PARAMETER SupportsMetadata
        Whether the operation supports metadata
    .PARAMETER SupportsPlatformSpecific
        Whether the operation has platform-specific parameters
    .OUTPUTS
        [hashtable] Template configuration for the operation
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Create', 'Read', 'Update', 'Delete', 'Test', 'List')]
        [string]$OperationType,
        
        [Parameter()]
        [switch]$RequiresCredential,
        
        [Parameter()]
        [switch]$SupportsMetadata,
        
        [Parameter()]
        [switch]$SupportsPlatformSpecific
    )
    
    $template = @{
        OperationType = $OperationType
        RequiresCredential = $RequiresCredential.IsPresent
        SupportsMetadata = $SupportsMetadata.IsPresent
        SupportsPlatformSpecific = $SupportsPlatformSpecific.IsPresent
    }
    
    # Add common validation patterns
    $template.ValidationSteps = @()
    $template.ValidationSteps += @{
        Name = 'CredentialIdValidation'
        Required = $true
        Description = 'Validate credential identifier format and security'
    }
    
    if ($RequiresCredential) {
        $template.ValidationSteps += @{
            Name = 'CredentialValidation'
            Required = $true
            Description = 'Validate PSCredential object'
        }
    }
    
    # Add common error handling patterns
    $template.ErrorHandling = @{
        RetryableOperations = @('Get', 'Set', 'Remove')
        PlatformSpecificErrors = $true
        SecurityContextRequired = $true
    }
    
    # Add operation-specific configurations
    switch ($OperationType) {
        'Create' {
            $template.PreConditions = @('CredentialNotExists')
            $template.PostConditions = @('CredentialExists', 'MetadataStored')
            $template.ShouldProcessMessage = 'Create new credential'
        }
        'Update' {
            $template.PreConditions = @('CredentialExists')
            $template.PostConditions = @('CredentialUpdated', 'MetadataUpdated')
            $template.ShouldProcessMessage = 'Update existing credential'
        }
        'Delete' {
            $template.PreConditions = @('CredentialExists')
            $template.PostConditions = @('CredentialRemoved', 'MetadataRemoved')
            $template.ShouldProcessMessage = 'Remove credential'
        }
        'Read' {
            $template.PreConditions = @()
            $template.PostConditions = @()
            $template.ShouldProcessMessage = $null  # Read operations don't modify
        }
        'Test' {
            $template.PreConditions = @()
            $template.PostConditions = @()
            $template.ShouldProcessMessage = $null  # Test operations don't modify
        }
        'List' {
            $template.PreConditions = @()
            $template.PostConditions = @()
            $template.ShouldProcessMessage = $null  # List operations don't modify
        }
    }
    
    return $template
}

function Get-OperationWorkflow {
    <#
    .SYNOPSIS
        Returns the standard workflow steps for credential operations
    .DESCRIPTION
        Provides the common workflow pattern that all credential operations follow,
        ensuring consistent behavior and error handling across the module.
    .OUTPUTS
        [string[]] Array of workflow step names in execution order
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    
    return @(
        'InitializeProvider',
        'ValidateAccess',
        'ValidateInputs',
        'ExecuteOperation',
        'HandleResults',
        'CleanupResources'
    )
}
