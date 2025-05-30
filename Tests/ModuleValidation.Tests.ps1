# Module Validation Tests - Consolidated from Tools/
using module Pester

BeforeAll {
    # Set strict mode for better error detection
    Set-StrictMode -Version Latest
    
    # Import module with force to ensure clean state
    $ModuleRoot = Split-Path $PSScriptRoot -Parent
    $ModulePath = Join-Path $ModuleRoot "PoShCredentialStore.psd1"
    
    # Remove any existing module instance
    Remove-Module PoShCredentialStore -Force -ErrorAction SilentlyContinue
    
    # Import fresh module
    Import-Module $ModulePath -Force -ErrorAction Stop
    
    # Test timeout function for hanging operations
    function Test-WithTimeout {
        param(
            [scriptblock]$ScriptBlock,
            [int]$TimeoutSeconds = 30
        )
        
        $job = Start-Job -ScriptBlock $ScriptBlock
        $completed = Wait-Job $job -Timeout $TimeoutSeconds
        
        if ($completed) {
            $result = Receive-Job $job
            Remove-Job $job
            return $result
        } else {
            Remove-Job $job -Force
            throw "Operation timed out after $TimeoutSeconds seconds"
        }
    }
}

Describe "Module Import and Structure Validation" {
    Context "Module Import Tests" {
        It "should import module without errors" {
            { Import-Module $ModulePath -Force } | Should -Not -Throw
        }
        
        It "should have correct module name" {
            $module = Get-Module PoShCredentialStore
            $module.Name | Should -Be "PoShCredentialStore"
        }
        
        It "should export expected public functions" {
            $exportedFunctions = (Get-Module PoShCredentialStore).ExportedFunctions.Keys
            $expectedFunctions = @('Get-PoShCredential', 'Set-PoShCredential', 'Remove-PoShCredential', 'Get-CredentialStoreInfo')
            
            foreach ($expectedFunction in $expectedFunctions) {
                $exportedFunctions | Should -Contain $expectedFunction
            }
        }
        
        It "should have valid module manifest" {
            { Test-ModuleManifest $ModulePath } | Should -Not -Throw
        }
    }
    
    Context "Individual Function Validation with Timeout Protection" {
        It "Get-CredentialStoreInfo should work without parameters" {
            $result = Test-WithTimeout -TimeoutSeconds 10 -ScriptBlock {
                Import-Module $using:ModulePath -Force
                Get-CredentialStoreInfo
            }
            
            $result | Should -Not -BeNullOrEmpty
            $result.ModuleName | Should -Be "PoShCredentialStore"
            $result.Platform | Should -Not -BeNullOrEmpty
        }
        
        It "Get-PoShCredential should handle non-existent credentials gracefully" {
            $result = Test-WithTimeout -TimeoutSeconds 10 -ScriptBlock {
                Import-Module $using:ModulePath -Force
                Get-PoShCredential -Name "NonExistentCredential$(Get-Random)"
            }
            
            $result | Should -BeNull
        }
        
        It "Set-PoShCredential should validate credential parameter" {
            $testResult = Test-WithTimeout -TimeoutSeconds 10 -ScriptBlock {
                Import-Module $using:ModulePath -Force
                try {
                    Set-PoShCredential -Name "Test" -Credential $null
                    return "Should have thrown"
                }
                catch {
                    return "Correctly threw error"
                }
            }
            
            $testResult | Should -Be "Correctly threw error"
        }
        
        It "Remove-PoShCredential should handle non-existent credentials" {
            $result = Test-WithTimeout -TimeoutSeconds 10 -ScriptBlock {
                Import-Module $using:ModulePath -Force
                Remove-PoShCredential -Name "NonExistent$(Get-Random)" -Force
            }
            
            # Should complete without throwing
            $result | Should -Be $false
        }
    }
}

Describe "Complete User Workflow Validation" {
    Context "CRUD Operations" {
        BeforeEach {
            $testCredentialName = "ModuleValidationTest$(Get-Random -Minimum 1000 -Maximum 9999)"
            $testPassword = ConvertTo-SecureString "TestPassword123!" -AsPlainText -Force
            $testCredential = New-Object PSCredential("TestUser", $testPassword)
        }
        
        AfterEach {
            # Cleanup test credential
            if ($testCredentialName) {
                Remove-PoShCredential -Name $testCredentialName -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "should complete full CRUD workflow successfully" {
            $workflowResult = Test-WithTimeout -TimeoutSeconds 30 -ScriptBlock {
                Import-Module $using:ModulePath -Force
                
                $testName = $using:testCredentialName
                $testCred = $using:testCredential
                
                # CREATE
                $setResult = Set-PoShCredential -Name $testName -Credential $testCred
                if (-not $setResult) { throw "Set operation failed" }
                
                # READ
                $getResult = Get-PoShCredential -Name $testName
                if (-not $getResult -or $getResult.UserName -ne "TestUser") { 
                    throw "Get operation failed or returned wrong credential" 
                }
                
                # UPDATE (set again with same name)
                $updateResult = Set-PoShCredential -Name $testName -Credential $testCred
                if (-not $updateResult) { throw "Update operation failed" }
                
                # DELETE
                $removeResult = Remove-PoShCredential -Name $testName -Force
                if (-not $removeResult) { throw "Remove operation failed" }
                
                # VERIFY DELETION
                $verifyResult = Get-PoShCredential -Name $testName
                if ($verifyResult) { throw "Credential still exists after removal" }
                
                return @{
                    Set = $setResult
                    Get = ($getResult -ne $null)
                    Update = $updateResult
                    Remove = $removeResult
                    VerifyRemoval = ($verifyResult -eq $null)
                }
            }
            
            $workflowResult.Set | Should -Be $true
            $workflowResult.Get | Should -Be $true
            $workflowResult.Update | Should -Be $true
            $workflowResult.Remove | Should -Be $true
            $workflowResult.VerifyRemoval | Should -Be $true
        }
        
        It "should handle pipeline operations correctly" {
            $pipelineResult = Test-WithTimeout -TimeoutSeconds 20 -ScriptBlock {
                Import-Module $using:ModulePath -Force
                
                $testNames = @("PipeTest1$(Get-Random)", "PipeTest2$(Get-Random)")
                $testCred = $using:testCredential
                
                try {
                    # Set up test credentials
                    foreach ($name in $testNames) {
                        Set-PoShCredential -Name $name -Credential $testCred | Out-Null
                    }
                    
                    # Test pipeline get
                    $pipelineResults = $testNames | Get-PoShCredential
                    
                    return @{
                        ResultCount = $pipelineResults.Count
                        AllFound = ($pipelineResults.Count -eq 2)
                        FirstUser = $pipelineResults[0].UserName
                    }
                }
                finally {
                    # Cleanup
                    foreach ($name in $testNames) {
                        Remove-PoShCredential -Name $name -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            
            $pipelineResult.AllFound | Should -Be $true
            $pipelineResult.FirstUser | Should -Be "TestUser"
        }
    }
}

Describe "Cross-Platform Compatibility" {
    Context "Platform Detection" {
        It "should detect platform correctly" {
            $info = Get-CredentialStoreInfo
            $info.Platform | Should -BeIn @('Windows', 'macOS', 'Linux', 'Unix')
        }
        
        It "should have appropriate storage method for platform" {
            $info = Get-CredentialStoreInfo
            
            switch ($info.Platform) {
                'Windows' { $info.StorageMethod | Should -Match 'CredMan|Memory' }
                'macOS' { $info.StorageMethod | Should -Match 'Keychain|Memory' }
                default { $info.StorageMethod | Should -Be 'Memory' }
            }
        }
        
        It "should provide valid user store path" {
            $info = Get-CredentialStoreInfo
            $info.UserStorePath | Should -Not -BeNullOrEmpty
            
            # Path should be platform-appropriate
            if ($info.IsWindows) {
                $info.UserStorePath | Should -Match 'Users.*AppData|ProgramData'
            } else {
                $info.UserStorePath | Should -Match 'home|usr'
            }
        }
    }
}

Describe "Error Handling and Edge Cases" {
    Context "Expected Error Scenarios - Errors Below Are Intentional" {
        It "should handle empty credential names gracefully" {
            { Set-PoShCredential -Name "" -Credential (New-Object PSCredential("user", (ConvertTo-SecureString "pass" -AsPlainText -Force))) } | Should -Throw
        }
        
        It "should handle null credential object" {
            { Set-PoShCredential -Name "Test" -Credential $null } | Should -Throw
        }
        
        It "should handle very long credential names" {
            $longName = "a" * 300
            { Set-PoShCredential -Name $longName -Credential (New-Object PSCredential("user", (ConvertTo-SecureString "pass" -AsPlainText -Force))) } | Should -Throw
        }
    }
    
    Context "Normal Operation Scenarios - No Errors Expected" {
        It "should handle special characters in credential names" {
            $specialName = "Test-Service_2024.Domain.com"
            $testCred = New-Object PSCredential("user", (ConvertTo-SecureString "pass" -AsPlainText -Force))
            
            try {
                { Set-PoShCredential -Name $specialName -Credential $testCred } | Should -Not -Throw
                $retrieved = Get-PoShCredential -Name $specialName
                $retrieved | Should -Not -BeNull
            }
            finally {
                Remove-PoShCredential -Name $specialName -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

AfterAll {
    # Final cleanup
    Remove-Module PoShCredentialStore -Force -ErrorAction SilentlyContinue
}
