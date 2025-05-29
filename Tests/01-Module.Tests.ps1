# PSCredentialStore Module Tests
# Tests for basic module structure, import, and core functionality

BeforeAll {
    # Remove the module if already loaded to ensure latest code is used
    if (Get-Module PSCredentialStore) {
        Remove-Module PSCredentialStore -Force
    }
    # Import the module for testing
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$ModulePath/PSCredentialStore.psd1" -Force
    
    # Check PS7 requirement
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "These tests require PowerShell 7 or later. Current version: $($PSVersionTable.PSVersion)"
    }
}

Describe "PSCredentialStore Module" -Tag "Unit" {
    Context "Module Structure" {
        It "Module manifest should be valid and require PowerShell 7+" {
            $ModulePath = Split-Path -Parent $PSScriptRoot
            $manifest = Test-ModuleManifest -Path "$ModulePath/PSCredentialStore.psd1"
            $manifest | Should -Not -BeNullOrEmpty
            $manifest.PowerShellVersion.Major | Should -BeGreaterOrEqual 7
        }
        
        It "Should export the required functions" {
            @('Get-StoredCredential', 'Set-StoredCredential', 'Remove-StoredCredential', 'Test-StoredCredential', 'New-StoredCredential', 'Get-StoredCredentialPlainText') | 
                ForEach-Object {
                    Get-Command -Module PSCredentialStore -Name $_ | Should -Not -BeNullOrEmpty
                }
        }

        It "Should not export private functions" {
            # Private helper functions should not be accessible globally
            { Get-Command ConvertFrom-SecureStringToPlainText -ErrorAction Stop } | Should -Throw "*not recognized*"
        }

        It "Module should load without errors" {
            $ModulePath = Split-Path -Parent $PSScriptRoot
            { Import-Module "$ModulePath/PSCredentialStore.psd1" -Force } | Should -Not -Throw
        }
    }

    Context "Function Availability" {
        It "All public functions should be available" {
            $expectedFunctions = @(
                'Get-StoredCredential',
                'Set-StoredCredential', 
                'Remove-StoredCredential',
                'Test-StoredCredential',
                'New-StoredCredential',
                'Get-StoredCredentialPlainText'
            )
            
            foreach ($function in $expectedFunctions) {
                Get-Command -Module PSCredentialStore -Name $function | Should -Not -BeNullOrEmpty
            }
        }

        It "Functions should have proper help documentation" {
            $functions = Get-Command -Module PSCredentialStore
            foreach ($function in $functions) {
                $help = Get-Help $function.Name
                $help.Synopsis | Should -Not -BeNullOrEmpty
                $help.Description.Text | Should -Not -BeNullOrEmpty
            }
        }
    }
}
