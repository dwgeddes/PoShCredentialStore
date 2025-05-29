#Requires -Version 7.0

# PSCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# Get module root path
$ModuleRoot = $PSScriptRoot

# Import private functions first
$PrivateFunctions = Get-ChildItem -Path "$ModuleRoot/Private" -Filter "*.ps1" -Recurse
foreach ($Function in $PrivateFunctions) {
    try {
        . $Function.FullName
    }
    catch {
        Write-Error "Failed to import private function '$($Function.Name)': $_"
    }
}

# Import public functions
$PublicFunctions = Get-ChildItem -Path "$ModuleRoot/Public" -Filter "*.ps1"
foreach ($Function in $PublicFunctions) {
    try {
        . $Function.FullName
    }
    catch {
        Write-Error "Failed to import public function '$($Function.Name)': $_"
    }
}

# Export only public functions
$FunctionsToExport = $PublicFunctions | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }
Export-ModuleMember -Function $FunctionsToExport

# Note: Private functions are available within the module scope but not exported globally

# Module cleanup
$ExecutionContext.SessionState.Module.OnRemove = {
    # Clean up any module-level resources
    Remove-Variable -Name ModuleRoot -Scope Script -ErrorAction SilentlyContinue
    
    # Force garbage collection for security
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
}