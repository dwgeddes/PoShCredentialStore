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
            @('Get-StoredCredential', 'Set-StoredCredential', 'Remove-StoredCredential', 'Test-StoredCredential', 'New-StoredCredential') | 
                ForEach-Object {
                    Get-Command -Module PSCredentialStore -Name $_ | Should -Not -BeNullOrEmpty
                }
        }
    }

    Context "Platform Detection" {
        It "Should detect the current platform correctly using automatic variables" {
            InModuleScope PSCredentialStore {
                $platform = Get-OSPlatform
                $expectedPlatform = $IsWindows ? "Windows" : ($IsMacOS ? "MacOS" : ($IsLinux ? "Linux" : "Unknown"))
                $platform | Should -Be $expectedPlatform
            }
        }
    }

    Context "Credential Management" -Tag "Integration" {
        BeforeEach {
            $script:credentialName = "PSCredentialStoreTest_$(Get-Random)_$(Get-Date -Format 'yyyyMMddHHmmssfff')"
            $script:testUser = "testuser"
            $script:testPassword = ConvertTo-SecureString "TestP@ssword123" -AsPlainText -Force
            $script:testCred = [System.Management.Automation.PSCredential]::new($script:testUser, $script:testPassword)
            # Extra cleanup to ensure no leftover credential
            Remove-StoredCredential -Name $script:credentialName -Force -ErrorAction SilentlyContinue | Out-Null
        }
        
        AfterEach {
            Remove-StoredCredential -Name $script:credentialName -Force -ErrorAction SilentlyContinue
        }
        
        It "Should create a new credential with New-StoredCredential" -Skip:([bool]$env:CI) {
            Remove-StoredCredential -Name $script:credentialName -Force -ErrorAction SilentlyContinue | Out-Null
            $result = New-StoredCredential -Name $script:credentialName -Credential $script:testCred
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $script:credentialName
            $result.Result | Should -Be "Created"
            $result.Credential.UserName | Should -Be $script:testUser
            $result.Credential.GetNetworkCredential().Password | Should -Be "TestP@ssword123"
            # Should not create again (should return $false)
            $result2 = New-StoredCredential -Name $script:credentialName -Credential $script:testCred
            $result2 | Should -BeFalse
            Remove-StoredCredential -Name $script:credentialName -Force -ErrorAction SilentlyContinue | Out-Null
        }

        It "Should store a credential with Set-StoredCredential" -Skip:([bool]$env:CI) {
            # First create
            $createResult = New-StoredCredential -Name $script:credentialName -Credential $script:testCred
            Write-Host "DEBUG: New-StoredCredential result: $($createResult | Out-String)"
            $createResult | Should -Not -BeNullOrEmpty
            # Now update
            $newPassword = ConvertTo-SecureString "TestP@ssword456" -AsPlainText -Force
            $newCred = [System.Management.Automation.PSCredential]::new($script:testUser, $newPassword)
            $result = Set-StoredCredential -Name $script:credentialName -Credential $newCred
            Write-Host "DEBUG: Set-StoredCredential result: $($result | Out-String)"
            $result | Should -BeTrue
            # Confirm update
            $retrieved = Get-StoredCredential -Name $script:credentialName
            Write-Host "DEBUG: Get-StoredCredential after update: $($retrieved | Out-String)"
            $retrieved.Credential.GetNetworkCredential().Password | Should -Be "TestP@ssword456"
        }
        
        It "Should not update a non-existent credential with Set-StoredCredential" -Skip:([bool]$env:CI) {
            Remove-StoredCredential -Name $script:credentialName -Force -ErrorAction SilentlyContinue | Out-Null
            $result = Set-StoredCredential -Name $script:credentialName -Credential $script:testCred
            $result.Result | Should -Be "Failed"
            $result.Message | Should -Be "Credential does not exist"
        }

        It "Should retrieve a credential" -Skip:([bool]$env:CI) {
            $createResult = New-StoredCredential -Name $script:credentialName -Credential $script:testCred
            Write-Host "DEBUG: New-StoredCredential result: $($createResult | Out-String)"
            $createResult | Should -Not -BeNullOrEmpty
            $retrievedCred = Get-StoredCredential -Name $script:credentialName
            Write-Host "DEBUG: Get-StoredCredential result: $($retrievedCred | Out-String)"
            $retrievedCred | Should -Not -BeNullOrEmpty
            $retrievedCred.Name | Should -Be $script:credentialName
            $retrievedCred.UserName | Should -Be $script:testUser
            $retrievedCred.Credential.GetNetworkCredential().Password | Should -Be "TestP@ssword123"
        }
        
        It "Should remove a credential" -Skip:([bool]$env:CI) {
            $createResult = New-StoredCredential -Name $script:credentialName -Credential $script:testCred
            Write-Host "DEBUG: New-StoredCredential result: $($createResult | Out-String)"
            $createResult | Should -Not -BeNullOrEmpty
            Test-StoredCredential -Name $script:credentialName | Should -BeTrue
            $result = Remove-StoredCredential -Name $script:credentialName -Force
            Write-Host "DEBUG: Remove-StoredCredential result: $($result | Out-String)"
            $result | Should -Not -BeNullOrEmpty
            $result.Result | Should -Be "Removed"
            Test-StoredCredential -Name $script:credentialName | Should -BeFalse
        }
    }

    Context "Function Mocking" {
        BeforeAll {
            Mock -ModuleName PSCredentialStore Get-OSPlatform { return "Windows" }
            $script:testUser = "mockuser"
            $script:testPassword = ConvertTo-SecureString "MockP@ssword123" -AsPlainText -Force
            $script:testCred = New-Object System.Management.Automation.PSCredential($script:testUser, $script:testPassword)
        }

        It "Should call provider.New for New-StoredCredential" {
            Mock -ModuleName PSCredentialStore Get-CredentialProvider {
                @{
                    New = { 
                            param([string]$Name, [System.Management.Automation.PSCredential]$Credential) 
                            if ($Name -eq "MockTest") { return $true } else { return $false } 
                          }
                    Test = { param([string]$Name) if ($Name -eq "MockTest") { return $false } else { return $true } } 
                }
            }
            $result = New-StoredCredential -Name "MockTest" -Credential $script:testCred
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be "MockTest"
            $result.Result | Should -Be "Created"
        }

        It "Should return false if credential already exists (provider.New returns false)" {
            Mock -ModuleName PSCredentialStore Get-CredentialProvider {
                @{
                    New = { param([string]$Name, [System.Management.Automation.PSCredential]$Credential) $false } 
                    Test = { param([string]$Name) $true } 
                }
            }
            $result = New-StoredCredential -Name "MockTestExists" -Credential $script:testCred
            $result | Should -BeFalse
        }

        It "Should use MacOS keychain when on MacOS" {
            InModuleScope 'PSCredentialStore' {
                Mock Get-OSPlatform { return "MacOS" }

                # Explicitly create the test credential within this scope
                $mockUser = "mockuser_set_test"
                $mockPassword = ConvertTo-SecureString "MockP@ssword_Set123" -AsPlainText -Force
                $localTestCred = New-Object System.Management.Automation.PSCredential($mockUser, $mockPassword)
                
                Write-Host "DEBUG Test: localTestCred UserName is '$($localTestCred.UserName)'"
                if (-not $localTestCred) { Write-Host "DEBUG Test: localTestCred IS NULL OR EMPTY at start of test" }

                $script:invokeMacOSKeychainCalled_Test_Op = $false
                $script:invokeMacOSKeychainCalled_Set_Op = $false
                $script:invokeMacOSKeychain_Set_Returned = $null
                $script:invokeMacOSKeychain_Test_Returned = $null

                Mock Invoke-MacOSKeychain {
                    param(
                        [string]$Operation,
                        [string]$Name,
                        [System.Management.Automation.PSCredential]$Credential_Param
                    )
                    Write-Host "Invoke-MacOSKeychain Mocked: Op='$Operation', Name='$Name', Credential supplied: $([bool]$Credential_Param), Credential User: $($Credential_Param.UserName)"
                    if ($Operation -eq 'Test' -and $Name -eq "MockTest") {
                        Write-Host "Invoke-MacOSKeychain Mocked: Matched Test for MockTest, returning true"
                        $script:invokeMacOSKeychainCalled_Test_Op = $true
                        $script:invokeMacOSKeychain_Test_Returned = $true
                        return $true
                    }
                    if ($Operation -eq 'Set' -and $Name -eq "MockTest") {
                        Write-Host "Invoke-MacOSKeychain Mocked: Matched Set for MockTest (Credential User: $($Credential_Param.UserName)), returning true"
                        $script:invokeMacOSKeychainCalled_Set_Op = $true
                        $script:invokeMacOSKeychain_Set_Returned = $true
                        return $true
                    }
                    Write-Host "Invoke-MacOSKeychain Mocked: No match for Op='$Operation', Name='$Name', returning false"
                    if ($Operation -eq 'Test') { $script:invokeMacOSKeychain_Test_Returned = $false }
                    if ($Operation -eq 'Set') { $script:invokeMacOSKeychain_Set_Returned = $false }
                    return $false
                } -Verifiable

                Write-Host "DEBUG Test: About to call Set-StoredCredential with Name='MockTest' and Credential User: $($localTestCred.UserName)"
                $setResult = Set-StoredCredential -Name "MockTest" -Credential $localTestCred
                Write-Host "DEBUG Test: Set-StoredCredential returned: $setResult"
                Write-Host "DEBUG Test: invokeMacOSKeychainCalled_Test_Op flag: $($script:invokeMacOSKeychainCalled_Test_Op), Returned: $($script:invokeMacOSKeychain_Test_Returned)"
                Write-Host "DEBUG Test: invokeMacOSKeychainCalled_Set_Op flag: $($script:invokeMacOSKeychainCalled_Set_Op), Returned: $($script:invokeMacOSKeychain_Set_Returned)"

                $script:invokeMacOSKeychainCalled_Test_Op | Should -BeTrue -Because "Invoke-MacOSKeychain 'Test' operation should have been called by Set-StoredCredential's pre-check."
                $script:invokeMacOSKeychain_Test_Returned | Should -BeTrue -Because "Invoke-MacOSKeychain 'Test' operation should have returned true."

                # This is the primary failing assertion
                $setResult | Should -BeTrue -Because "Set-StoredCredential should return true when provider operations succeed."

                # These assertions help confirm the 'Set' operation mock was effective
                $script:invokeMacOSKeychainCalled_Set_Op | Should -BeTrue -Because "Invoke-MacOSKeychain 'Set' operation should have been called."
                $script:invokeMacOSKeychain_Set_Returned | Should -BeTrue -Because "Invoke-MacOSKeychain 'Set' operation should have returned true."

                Should -Invoke -CommandName Invoke-MacOSKeychain -Times 1 -Exactly -Scope 'It' -ParameterFilter {
                    $Operation -eq 'Set' -and $Name -eq "MockTest"
                } -Because "The mock for Invoke-MacOSKeychain with Set operation should be invoked exactly once."
            }
        }

        Context "Credential Listing" {
            It "Should list credentials on MacOS" {
                InModuleScope PSCredentialStore {
                    Mock -ModuleName PSCredentialStore Get-OSPlatform { "MacOS" }
                    Mock -CommandName Test-Path { return $true }
                    Mock -CommandName Get-Content { return '{"foo":"user_foo","bar":"user_bar"}' }
                    Mock -ModuleName PSCredentialStore Invoke-MacOSKeychain {
                        param($Operation, $Name)
                        switch ($Operation) {
                            'List' {
                                @(
                                    [PSCustomObject]@{
                                        Name = 'foo'
                                        UserName = 'user_foo'
                                        Credential = [PSCredential]::new("user_foo", (ConvertTo-SecureString "pass_foo" -AsPlainText -Force))
                                    },
                                    [PSCustomObject]@{
                                        Name = 'bar'
                                        UserName = 'user_bar'
                                        Credential = [PSCredential]::new("user_bar", (ConvertTo-SecureString "pass_bar" -AsPlainText -Force))
                                    }
                                )
                            }
                            'Get' {
                                [PSCredential]::new("user_$Name", (ConvertTo-SecureString "pass_$Name" -AsPlainText -Force))
                            }
                        }
                    }
                    $result = Get-StoredCredential
                    $result.Name | Should -Be "foo","bar"
                    $result.Credential.GetNetworkCredential().Password | Should -Be "pass_foo","pass_bar"
                }
            }
        }
    }
}