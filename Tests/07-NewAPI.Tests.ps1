# New API Comprehensive Tests
# Testing the modernized credential object structure and enhanced Get-StoredCredential functionality

BeforeAll {
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$ModulePath/PSCredentialStore.psd1" -Force
}

Describe "Enhanced Get-StoredCredential API" -Tag "Unit", "NewAPI" {
    BeforeEach {
        # Generate unique test credentials for each test
        $script:testId = "NewAPITest_$(Get-Random)"
        $script:testUser = "testuser"
        $script:testPassword = ConvertTo-SecureString "TestPassword123!" -AsPlainText -Force
        $script:testCred = [PSCredential]::new($script:testUser, $script:testPassword)
        
        # Ensure clean state
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    AfterEach {
        # Clean up test credentials
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    Context "New Object Structure" {
        It "Should return object with Name, Username, Password (SecureString), and Metadata" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $result = Get-StoredCredential -Name $script:testId
            $result | Should -Not -BeNullOrEmpty
            
            # Check object structure
            $result.Name | Should -Be $script:testId
            $result.Username | Should -Be $script:testUser
            $result.Password | Should -BeOfType [SecureString]
            $result.Metadata | Should -Not -BeNull
            
            # Verify no old "Credential" property exists
            $result.PSObject.Properties.Name | Should -Not -Contain "Credential"
        }
        
        It "Should store and retrieve SecureString password correctly" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $result = Get-StoredCredential -Name $script:testId
            
            # Convert back to plain text to verify it's the same
            $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringUni(
                [System.Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($result.Password)
            )
            $plainPassword | Should -Be "TestPassword123!"
        }
    }

    Context "AsPlainText Parameter" {
        It "Should return same object structure with plain text password" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $result = Get-StoredCredential -Name $script:testId -AsPlainText
            
            $result.Name | Should -Be $script:testId
            $result.Username | Should -Be $script:testUser
            $result.Password | Should -Be "TestPassword123!"
            $result.Password | Should -BeOfType [string]
            $result.Metadata | Should -Not -BeNull
        }
        
        It "Should display security warning for plain text retrieval" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $warningOutput = $null
            $result = Get-StoredCredential -Name $script:testId -AsPlainText -WarningVariable warningOutput 2>&1
            $warningOutput | Should -Not -BeNullOrEmpty
            $warningOutput -match "plain text" | Should -Be $true
        }
    }

    Context "AsCredential Parameter" {
        It "Should return PSCredential object directly" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $result = Get-StoredCredential -Name $script:testId -AsCredential
            
            $result | Should -BeOfType [PSCredential]
            $result.UserName | Should -Be $script:testUser
            $result.GetNetworkCredential().Password | Should -Be "TestPassword123!"
        }
    }

    Context "Parameter Mutual Exclusivity" {
        It "Should not allow AsPlainText and AsCredential together" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            { Get-StoredCredential -Name $script:testId -AsPlainText -AsCredential } | Should -Throw
        }
    }
}

Describe "Enhanced New-StoredCredential Parameter Sets" -Tag "Unit", "NewAPI" {
    BeforeEach {
        $script:testId = "NewAPITest_$(Get-Random)"
        $script:testUser = "testuser"
        $script:testPassword = ConvertTo-SecureString "TestPassword123!" -AsPlainText -Force
        $script:testCred = [PSCredential]::new($script:testUser, $script:testPassword)
        
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    AfterEach {
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    Context "PSCredential Parameter Set" {
        It "Should accept PSCredential and split into Username/Password" {
            $result = New-StoredCredential -Name $script:testId -Credential $script:testCred
            
            $result.Name | Should -Be $script:testId
            $result.Username | Should -Be $script:testUser
            $result.Password | Should -BeOfType [SecureString]
        }
    }

    Context "Username/SecureString Parameter Set" {
        It "Should accept Username and SecureString directly" {
            $result = New-StoredCredential -Name $script:testId -Username $script:testUser -Password $script:testPassword
            
            $result.Name | Should -Be $script:testId
            $result.Username | Should -Be $script:testUser
            $result.Password | Should -BeOfType [SecureString]
            
            # Verify stored correctly
            $retrieved = Get-StoredCredential -Name $script:testId -AsPlainText
            $retrieved.Password | Should -Be "TestPassword123!"
        }
    }
}

Describe "Enhanced Set-StoredCredential Parameter Sets" -Tag "Unit", "NewAPI" {
    BeforeEach {
        $script:testId = "NewAPITest_$(Get-Random)"
        $script:testUser = "testuser"
        $script:testPassword = ConvertTo-SecureString "TestPassword123!" -AsPlainText -Force
        $script:testCred = [PSCredential]::new($script:testUser, $script:testPassword)
        
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    AfterEach {
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    Context "Update with PSCredential" {
        It "Should update existing credential with new PSCredential" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $newPassword = ConvertTo-SecureString "NewPassword456!" -AsPlainText -Force
            $newCred = [PSCredential]::new("newuser", $newPassword)
            
            $result = Set-StoredCredential -Name $script:testId -Credential $newCred
            
            $result.Username | Should -Be "newuser"
            
            $retrieved = Get-StoredCredential -Name $script:testId -AsPlainText
            $retrieved.Password | Should -Be "NewPassword456!"
        }
    }

    Context "Update with Username/SecureString" {
        It "Should update existing credential with Username and SecureString" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $newPassword = ConvertTo-SecureString "NewPassword789!" -AsPlainText -Force
            
            $result = Set-StoredCredential -Name $script:testId -Username "updateduser" -Password $newPassword
            
            $result.Username | Should -Be "updateduser"
            
            $retrieved = Get-StoredCredential -Name $script:testId -AsPlainText
            $retrieved.Password | Should -Be "NewPassword789!"
        }
    }
}

Describe "Credential Conversion Helper Functions" -Tag "Unit", "Helpers" {
    Context "SecureString to PlainText Conversion" {
        It "Should safely convert SecureString to plain text via internal function" {
            $testPassword = "TestPassword123!"
            $secureString = ConvertTo-SecureString $testPassword -AsPlainText -Force
            
            # Test internal function via Get-StoredCredential -AsPlainText
            $script:testId = "HelperTest_$(Get-Random)"
            $script:testCred = [PSCredential]::new("testuser", $secureString)
            
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            $result = Get-StoredCredential -Name $script:testId -AsPlainText
            
            $result.Password | Should -Be $testPassword
            
            Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
        }
        
        It "Should handle SecureString conversion correctly" {
            # Test that conversion maintains data integrity
            $testPassword = "ComplexPassword!@#$%^&*()"
            $secureString = ConvertTo-SecureString $testPassword -AsPlainText -Force
            
            $script:testId = "HelperTest_$(Get-Random)"
            $script:testCred = [PSCredential]::new("testuser", $secureString)
            
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            $result = Get-StoredCredential -Name $script:testId -AsPlainText
            
            $result.Password | Should -Be $testPassword
            
            Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }

    Context "PlainText to SecureString Conversion" {
        It "Should convert plain text to SecureString via New-StoredCredential" {
            $testPassword = "TestPassword123!"
            $secureString = ConvertTo-SecureString $testPassword -AsPlainText -Force
            
            # Test that New-StoredCredential correctly handles SecureString input
            $script:testId = "HelperTest_$(Get-Random)"
            
            $result = New-StoredCredential -Name $script:testId -Username "testuser" -Password $secureString
            
            $result.Password | Should -BeOfType [SecureString]
            
            # Verify round trip
            $retrieved = Get-StoredCredential -Name $script:testId -AsPlainText
            $retrieved.Password | Should -Be $testPassword
            
            Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

Describe "Backward Compatibility Breaking Changes" -Tag "Unit", "BreakingChanges" {
    BeforeEach {
        $script:testId = "BreakingTest_$(Get-Random)"
        $script:testUser = "testuser"
        $script:testPassword = ConvertTo-SecureString "TestPassword123!" -AsPlainText -Force
        $script:testCred = [PSCredential]::new($script:testUser, $script:testPassword)
        
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    AfterEach {
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    Context "Old Object Structure No Longer Exists" {
        It "Should not have Credential property in returned object" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $result = Get-StoredCredential -Name $script:testId
            $result.PSObject.Properties.Name | Should -Not -Contain "Credential"
        }
    }

    Context "Get-StoredCredentialPlainText Function" {
        It "Should no longer exist as public function" {
            $commands = Get-Command -Module PSCredentialStore
            $commands.Name | Should -Not -Contain "Get-StoredCredentialPlainText"
        }
    }
}
