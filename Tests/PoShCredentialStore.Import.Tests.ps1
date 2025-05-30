BeforeAll {
    # Mock interactive commands to prevent hanging
    Mock Read-Host { return "mocked-input" }
    Mock Write-Progress { }
    $global:ConfirmPreference = 'None'
}

Describe "PoShCredentialStore Module Import Validation" {
    
    Context "Normal Operation Scenarios - No Errors Expected" {
        It "should import module without errors using timeout protection" {
            $job = Start-Job { 
                Import-Module '/Users/dgeddes/Code/PoShCredentialStore/PoShCredentialStore.psd1' -Force -ErrorAction Stop
                Get-Module PoShCredentialStore | Select-Object Name, Version
            }
            $completed = Wait-Job $job -Timeout 10
            if ($completed) {
                $result = Receive-Job $job
                Remove-Job $job
                $result.Name | Should -Be 'PoShCredentialStore'
                $result.Version | Should -Be '1.0.0'
            } else {
                Remove-Job $job -Force
                throw "Module import timed out after 10 seconds - investigate manifest issues"
            }
        }

        It "should export Get-CredentialStoreInfo function" {
            $job = Start-Job {
                Import-Module '/Users/dgeddes/Code/PoShCredentialStore/PoShCredentialStore.psd1' -Force
                Get-Command -Module PoShCredentialStore -Name Get-CredentialStoreInfo -ErrorAction Stop
            }
            $completed = Wait-Job $job -Timeout 10
            if ($completed) {
                $result = Receive-Job $job
                Remove-Job $job
                $result.Name | Should -Be 'Get-CredentialStoreInfo'
            } else {
                Remove-Job $job -Force
                throw "Function export validation timed out"
            }
        }

        It "should execute Get-CredentialStoreInfo successfully" {
            $job = Start-Job {
                Import-Module '/Users/dgeddes/Code/PoShCredentialStore/PoShCredentialStore.psd1' -Force
                Get-CredentialStoreInfo
            }
            $completed = Wait-Job $job -Timeout 10
            if ($completed) {
                $result = Receive-Job $job
                Remove-Job $job
                $result.ModuleName | Should -Be 'PoShCredentialStore'
                $result.Version | Should -Be '1.0.0'
                $result.Status | Should -Be 'Ready'
                $result.Platform | Should -Not -BeNullOrEmpty
            } else {
                Remove-Job $job -Force
                throw "Function execution timed out"
            }
        }
    }

    Context "Expected Error Scenarios - Errors Below Are Intentional" {
        It "should handle import from wrong path gracefully" {
            $job = Start-Job {
                Import-Module '/nonexistent/path/PoShCredentialStore.psd1' -ErrorAction Stop
            }
            $completed = Wait-Job $job -Timeout 5
            if ($completed) {
                $result = Receive-Job $job -ErrorVariable importError
                Remove-Job $job
                $importError | Should -Not -BeNullOrEmpty
            } else {
                Remove-Job $job -Force
                # This is expected - import should fail for invalid path
            }
        }
    }
}
