BeforeAll {
    # Import the module for testing
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$ModulePath/PSCredentialStore.psd1" -Force
}

Describe "MacOS Keychain Implementation" -Tag "MacOS", "Unit" {
    BeforeAll {
        # This module is macOS-only, but we'll still check to be safe
        if (-not $IsMacOS) {
            Set-ItResult -Skipped -Because "Not running on macOS"
        }
        
        # Create test credential
        $script:testUser = "macostestuser"
        $script:testPassword = ConvertTo-SecureString "MacOSTest123!" -AsPlainText -Force
        $script:testCred = New-Object System.Management.Automation.PSCredential($script:testUser, $script:testPassword)
    }
    
    It "Should store a credential directly with Invoke-MacOSKeychain" {
        # Generate a unique target name for testing - must be inside the test to avoid scope issues
        $targetName = "PSCredentialStoreMacOSTest_$(Get-Random)"
        $testCredential = $script:testCred
        
        # This is the clean way to inject variables into InModuleScope
        InModuleScope -ModuleName PSCredentialStore {
            # Inject variables from parent scope
            param($targetName, [PSCredential]$testCredential)
            
            $result = Invoke-MacOSKeychain -Operation New -Name $targetName -Credential $testCredential
            $result | Should -BeTrue
            
            # Clean up
            Invoke-MacOSKeychain -Operation Remove -Name $targetName | Out-Null
        } -Parameters @{ targetName = $targetName; testCredential = $testCredential }
    }
    
    It "Should retrieve a credential directly with Invoke-MacOSKeychain" {
        # Generate a unique target name for testing
        $targetName = "PSCredentialStoreMacOSTest_$(Get-Random)"
        $testCredential = $script:testCred
        $testUserName = $script:testUser
        
        InModuleScope -ModuleName PSCredentialStore {
            param($targetName, [PSCredential]$testCredential, $testUserName)
            
            # First store the credential
            Invoke-MacOSKeychain -Operation New -Name $targetName -Credential $testCredential | Should -BeTrue
            
            # Then retrieve it
            $cred = Invoke-MacOSKeychain -Operation Get -Name $targetName
            $cred | Should -Not -BeNullOrEmpty
            
            # The macOS implementation now returns a PSCustomObject with credential information
            # Check if it's a PSCustomObject with Credential property or just a credential
            if ($cred -is [PSCustomObject] -and $cred.PSObject.Properties.Name -contains 'Credential') {
                # New object format with metadata
                $cred.UserName | Should -Be $testUserName
                $cred.Credential.GetNetworkCredential().Password | Should -Be "MacOSTest123!"
            } else {
                # Legacy format - just a credential object
                $cred.UserName | Should -Be $testUserName  
                $cred.GetNetworkCredential().Password | Should -Be "MacOSTest123!"
            }
            
            # Clean up
            Invoke-MacOSKeychain -Operation Remove -Name $targetName | Out-Null
        } -Parameters @{ targetName = $targetName; testCredential = $testCredential; testUserName = $testUserName }
    }
    
    It "Should remove a credential directly with Invoke-MacOSKeychain" {
        # Generate a unique target name for testing
        $targetName = "PSCredentialStoreMacOSTest_$(Get-Random)"
        $testCredential = $script:testCred
        
        InModuleScope -ModuleName PSCredentialStore {
            param($targetName, [PSCredential]$testCredential)
            
            # First store the credential
            Invoke-MacOSKeychain -Operation New -Name $targetName -Credential $testCredential | Should -BeTrue
            
            # Then remove it
            $result = Invoke-MacOSKeychain -Operation Remove -Name $targetName
            $result | Should -BeTrue
            
            # Verify it's gone
            $cred = Invoke-MacOSKeychain -Operation Get -Name $targetName
            $cred | Should -BeNullOrEmpty
        } -Parameters @{ targetName = $targetName; testCredential = $testCredential }
    }
}