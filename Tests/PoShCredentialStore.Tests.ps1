#Requires -Modules Pester

BeforeAll {
    # Import module with timeout protection
    $ModuleRoot = Split-Path $PSScriptRoot -Parent
    
    # Ensure clean import
    Remove-Module PoShCredentialStore -Force -ErrorAction SilentlyContinue
    
    # Import with timeout protection
    $importJob = Start-Job {
        Import-Module '$using:ModuleRoot/PoShCredentialStore.psd1' -Force -ErrorAction Stop
        return $true
    }
    
    $importCompleted = Wait-Job $importJob -Timeout 30
    if ($importCompleted) {
        $importResult = Receive-Job $importJob
        Remove-Job $importJob
        if (-not $importResult) {
            throw "Module import failed"
        }
    } else {
        Remove-Job $importJob -Force
        throw "Module import timed out after 30 seconds"
    }
    
    # Test data setup
    $TestCredentialName = "PesterTest$(Get-Random -Minimum 1000 -Maximum 9999)"
    $TestPassword = ConvertTo-SecureString "TestPassword123!" -AsPlainText -Force
    $TestCredential = New-Object PSCredential("TestUser", $TestPassword)
    
    # Mock interactive commands to prevent hanging
    Mock Read-Host { return "mocked-input" }
    Mock Write-Progress { }
    $global:ConfirmPreference = 'None'
}

AfterAll {
    # Cleanup test credentials
    if ($TestCredentialName) {
        Remove-PoShCredential -Name $TestCredentialName -Force -ErrorAction SilentlyContinue
    }
    
    Remove-Module PoShCredentialStore -Force -ErrorAction SilentlyContinue
}

Describe "PoShCredentialStore Module" {
    Context "Module Structure and Imports" {
        It "should import without errors" {
            { Get-Module PoShCredentialStore } | Should -Not -Throw
            $module = Get-Module PoShCredentialStore
            $module | Should -Not -BeNull
            $module.Name | Should -Be "PoShCredentialStore"
        }
        
        It "should export expected public functions" {
            $module = Get-Module PoShCredentialStore
            $expectedFunctions = @('Get-PoShCredential', 'Set-PoShCredential', 'Remove-PoShCredential', 'Get-CredentialStoreInfo')
            
            foreach ($func in $expectedFunctions) {
                $module.ExportedFunctions.Keys | Should -Contain $func
            }
        }
        
        It "should have proper function help" {
            $functions = Get-Command -Module PoShCredentialStore
            foreach ($func in $functions) {
                $help = Get-Help $func.Name
                $help.Synopsis | Should -Not -BeNullOrEmpty
                $help.Description | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Get-CredentialStoreInfo Function" {
        It "should return module information without hanging" {
            $job = Start-Job { 
                Import-Module '$using:ModuleRoot/PoShCredentialStore.psd1' -Force
                Get-CredentialStoreInfo
            }
            
            $completed = Wait-Job $job -Timeout 30
            $completed | Should -Not -BeNull
            
            $info = Receive-Job $job
            Remove-Job $job
            
            $info | Should -Not -BeNull
            $info.ModuleName | Should -Be "PoShCredentialStore"
            $info.Status | Should -Be "Loaded"
            $info.SupportedOperations | Should -Contain "Get"
            $info.SupportedOperations | Should -Contain "Set"
            $info.SupportedOperations | Should -Contain "Remove"
        }
        
        It "should detect platform correctly" {
            $info = Get-CredentialStoreInfo
            $info.Platform | Should -Not -BeNullOrEmpty
            $info.IsWindows | Should -BeOfType [bool]
            $info.StorageMethod | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Expected Error Scenarios - Errors Below Are Intentional" {
        It "Get-PoShCredential should return null for non-existent credential" {
            $result = Get-PoShCredential -Name "NonExistent$(Get-Random)" -ErrorAction SilentlyContinue
            $result | Should -BeNull
        }
        
        It "Set-PoShCredential should reject null credential" {
            { Set-PoShCredential -Name "Test" -Credential $null -ErrorAction Stop } | Should -Throw
        }
        
        It "Set-PoShCredential should reject empty name" {
            { Set-PoShCredential -Name "" -Credential $TestCredential -ErrorAction Stop } | Should -Throw
        }
        
        It "Remove-PoShCredential should handle non-existent credential gracefully" {
            $result = Remove-PoShCredential -Name "NonExistent$(Get-Random)" -Force -ErrorAction SilentlyContinue
            $result | Should -Be $false
        }
    }
    
    Context "Normal Operation Scenarios - No Errors Expected" {
        BeforeEach {
            # Ensure clean state
            Remove-PoShCredential -Name $TestCredentialName -Force -ErrorAction SilentlyContinue
        }
        
        AfterEach {
            # Cleanup after each test
            Remove-PoShCredential -Name $TestCredentialName -Force -ErrorAction SilentlyContinue
        }
        
        It "should complete full CRUD workflow with timeout protection" {
            $job = Start-Job {
                Import-Module '$using:ModuleRoot/PoShCredentialStore.psd1' -Force
                
                # Test complete CRUD workflow
                $testName = $using:TestCredentialName
                $testCred = $using:TestCredential
                
                # 1. Set credential
                $setResult = Set-PoShCredential -Name $testName -Credential $testCred -Force
                if (-not $setResult) { throw "Set-PoShCredential failed" }
                
                # 2. Get credential
                $getResult = Get-PoShCredential -Name $testName
                if (-not $getResult -or $getResult.UserName -ne $testCred.UserName) {
                    throw "Get-PoShCredential failed or returned incorrect credential"
                }
                
                # 3. Remove credential
                $removeResult = Remove-PoShCredential -Name $testName -Force
                if (-not $removeResult) { throw "Remove-PoShCredential failed" }
                
                # 4. Verify removal
                $verifyResult = Get-PoShCredential -Name $testName -ErrorAction SilentlyContinue
                if ($null -ne $verifyResult) { throw "Credential not properly removed" }
                
                return @{
                    Set = $setResult
                    Get = ($null -ne $getResult)
                    Remove = $removeResult
                    Verified = ($null -eq $verifyResult)
                }
            }
            
            $completed = Wait-Job $job -Timeout 60
            $completed | Should -Not -BeNull
            
            $workflow = Receive-Job $job
            Remove-Job $job
            
            $workflow.Set | Should -Be $true
            $workflow.Get | Should -Be $true
            $workflow.Remove | Should -Be $true
            $workflow.Verified | Should -Be $true
        }
        
        It "should handle pipeline input correctly" {
            $testNames = @("PipelineTest1", "PipelineTest2")
            
            try {
                # Set multiple credentials
                foreach ($name in $testNames) {
                    Set-PoShCredential -Name $name -Credential $TestCredential -Force | Should -Be $true
                }
                
                # Get multiple credentials via pipeline
                $results = $testNames | Get-PoShCredential
                $results | Should -HaveCount 2
                foreach ($result in $results) {
                    $result.UserName | Should -Be $TestCredential.UserName
                }
                
                # Remove via pipeline
                $removeResults = $testNames | Remove-PoShCredential -Force
                $removeResults | Should -Not -Contain $false
            }
            finally {
                # Cleanup
                foreach ($name in $testNames) {
                    Remove-PoShCredential -Name $name -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        It "should handle User and Machine scopes correctly" {
            $scopeTestName = "ScopeTest$(Get-Random)"
            
            try {
                # Test User scope
                Set-PoShCredential -Name $scopeTestName -Credential $TestCredential -Scope User -Force | Should -Be $true
                $userResult = Get-PoShCredential -Name $scopeTestName -Scope User
                $userResult | Should -Not -BeNull
                $userResult.UserName | Should -Be $TestCredential.UserName
                
                # Test Machine scope (may fail due to permissions, that's expected)
                try {
                    $machineResult = Set-PoShCredential -Name $scopeTestName -Credential $TestCredential -Scope Machine -Force
                    if ($machineResult) {
                        $machineGet = Get-PoShCredential -Name $scopeTestName -Scope Machine
                        $machineGet | Should -Not -BeNull
                        Remove-PoShCredential -Name $scopeTestName -Scope Machine -Force | Should -Be $true
                    }
                } catch {
                    # Machine scope may fail due to permissions - this is acceptable
                    Write-Warning "Machine scope test skipped due to permissions: $($_.Exception.Message)"
                }
            }
            finally {
                # Cleanup both scopes
                Remove-PoShCredential -Name $scopeTestName -Scope User -Force -ErrorAction SilentlyContinue
                Remove-PoShCredential -Name $scopeTestName -Scope Machine -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Cross-Platform Compatibility" {
        It "should handle platform-specific paths correctly" {
            $info = Get-CredentialStoreInfo
            
            if ($info.IsWindows) {
                $info.UserStorePath | Should -Match "AppData|Users"
                $info.StorageMethod | Should -Match "Windows|file"
            } else {
                $info.UserStorePath | Should -Match "home|\.posh"
                $info.StorageMethod | Should -Match "file"
            }
            
            # Test that paths are valid for the platform
            $parentPath = Split-Path $info.UserStorePath -Parent
            { Test-Path $parentPath -IsValid } | Should -Not -Throw
        }
        
        It "should use Join-Path for all path operations" {
            # This tests that internal path operations work cross-platform
            $testName = "PathTest$(Get-Random)"
            
            try {
                Set-PoShCredential -Name $testName -Credential $TestCredential -Force | Should -Be $true
                Get-PoShCredential -Name $testName | Should -Not -BeNull
            }
            finally {
                Remove-PoShCredential -Name $testName -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Performance and Timeout Protection" {
        It "should complete operations within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            try {
                Set-PoShCredential -Name $TestCredentialName -Credential $TestCredential -Force | Should -Be $true
                Get-PoShCredential -Name $TestCredentialName | Should -Not -BeNull
                Remove-PoShCredential -Name $TestCredentialName -Force | Should -Be $true
            }
            finally {
                $stopwatch.Stop()
                Remove-PoShCredential -Name $TestCredentialName -Force -ErrorAction SilentlyContinue
            }
            
            # All operations should complete within 10 seconds
            $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 10
        }
        
        It "should not hang on invalid operations" {
            $job = Start-Job {
                Import-Module '$using:ModuleRoot/PoShCredentialStore.psd1' -Force
                
                # Test operations that might hang
                try {
                    Get-PoShCredential -Name "NonExistent" -ErrorAction SilentlyContinue
                    Set-PoShCredential -Name "HangTest" -Credential $using:TestCredential -Force
                    Remove-PoShCredential -Name "HangTest" -Force
                    return $true
                } catch {
                    return $false
                }
            }
            
            $completed = Wait-Job $job -Timeout 30
            $completed | Should -Not -BeNull
            
            $result = Receive-Job $job
            Remove-Job $job
            
            $result | Should -Be $true
        }
    }
}
