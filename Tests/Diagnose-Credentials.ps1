# PSCredentialStore - Diagnostic Script for OpenAI Credential Issue
# This script helps diagnose the specific issue with the "OpenAI" credential retrieval

param(
    [switch]$Verbose
)

if ($Verbose) { $VerbosePreference = 'Continue' }

Write-Host "=== PSCredentialStore Diagnostic Script ===" -ForegroundColor Cyan
Write-Host "Diagnosing 'OpenAI' credential retrieval issue..." -ForegroundColor Yellow

# Import the module
try {
    Import-Module ./PSCredentialStore.psd1 -Force
    Write-Host "✓ Module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import module: $_" -ForegroundColor Red
    exit 1
}

# Test 1: Basic module functions
Write-Host "`n--- Test 1: Module Function Availability ---" -ForegroundColor Cyan
$functions = @('Get-StoredCredential', 'Get-StoredCredentialPlainText', 'Test-StoredCredential')
foreach ($func in $functions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "✓ $func is available" -ForegroundColor Green
    } else {
        Write-Host "✗ $func is not available" -ForegroundColor Red
    }
}

# Test 2: Platform detection
Write-Host "`n--- Test 2: Platform Detection ---" -ForegroundColor Cyan
try {
    $platform = Get-OSPlatform
    Write-Host "✓ Platform detected: $platform" -ForegroundColor Green
    Write-Host "✓ IsMacOS: $IsMacOS" -ForegroundColor Green
} catch {
    Write-Host "✗ Platform detection failed: $_" -ForegroundColor Red
}

# Test 3: Security command availability (macOS specific)
if ($IsMacOS) {
    Write-Host "`n--- Test 3: macOS Security Command ---" -ForegroundColor Cyan
    try {
        $securityVersion = security -V 2>&1
        Write-Host "✓ Security command available: $securityVersion" -ForegroundColor Green
    } catch {
        Write-Host "✗ Security command not available: $_" -ForegroundColor Red
    }
}

# Test 4: Check if OpenAI credential exists
Write-Host "`n--- Test 4: OpenAI Credential Existence ---" -ForegroundColor Cyan
try {
    $exists = Test-StoredCredential -Name "OpenAI" -Force
    if ($exists) {
        Write-Host "✓ OpenAI credential exists in store" -ForegroundColor Green
    } else {
        Write-Host "✗ OpenAI credential does not exist" -ForegroundColor Red
        Write-Host "Available credentials:" -ForegroundColor Yellow
        Get-StoredCredential | ForEach-Object { Write-Host "  - $($_.Name)" }
        exit 0
    }
} catch {
    Write-Host "✗ Error checking OpenAI credential existence: $_" -ForegroundColor Red
}

# Test 5: Direct keychain access (macOS)
if ($IsMacOS) {
    Write-Host "`n--- Test 5: Direct Keychain Access ---" -ForegroundColor Cyan
    try {
        Write-Host "Attempting direct keychain access..." -ForegroundColor Yellow
        $serviceName = "PSCredentialStore:OpenAI"
        
        # Try to find the password directly
        $keychainResult = security find-generic-password -s $serviceName -a "OpenAI" -w 2>&1
        $exitCode = $LASTEXITCODE
        
        Write-Host "Security command exit code: $exitCode" -ForegroundColor Yellow
        if ($exitCode -eq 0) {
            if ([string]::IsNullOrEmpty($keychainResult)) {
                Write-Host "✗ Password retrieved but is empty/null" -ForegroundColor Red
            } else {
                Write-Host "✓ Password retrieved from keychain (length: $($keychainResult.Length))" -ForegroundColor Green
                Write-Host "Password starts with: $($keychainResult.Substring(0, [Math]::Min(3, $keychainResult.Length)))..." -ForegroundColor Yellow
            }
        } else {
            Write-Host "✗ Failed to retrieve from keychain: $keychainResult" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Direct keychain access failed: $_" -ForegroundColor Red
    }
}

# Test 6: Metadata check
Write-Host "`n--- Test 6: Metadata Check ---" -ForegroundColor Cyan
try {
    $config = Get-ModuleConfiguration
    $metadataPath = Join-Path $config.MetadataPath "OpenAI.json"
    
    if (Test-Path $metadataPath) {
        Write-Host "✓ Metadata file exists: $metadataPath" -ForegroundColor Green
        $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json -AsHashtable
        Write-Host "Metadata UserName: $($metadata.UserName)" -ForegroundColor Yellow
        Write-Host "Metadata keys: $($metadata.Keys -join ', ')" -ForegroundColor Yellow
    } else {
        Write-Host "✗ Metadata file does not exist: $metadataPath" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Metadata check failed: $_" -ForegroundColor Red
}

# Test 7: Provider initialization
Write-Host "`n--- Test 7: Provider Initialization ---" -ForegroundColor Cyan
try {
    $provider = Get-CredentialProvider
    Write-Host "✓ Provider initialized" -ForegroundColor Green
    Write-Host "Provider type: $($provider.GetType().Name)" -ForegroundColor Yellow
    Write-Host "Provider methods: $($provider.PSObject.Properties.Name -join ', ')" -ForegroundColor Yellow
} catch {
    Write-Host "✗ Provider initialization failed: $_" -ForegroundColor Red
}

# Test 8: Step-by-step credential retrieval
Write-Host "`n--- Test 8: Step-by-Step Credential Retrieval ---" -ForegroundColor Cyan
try {
    Write-Host "Step 1: Getting provider..." -ForegroundColor Yellow
    $provider = Get-CredentialProvider
    
    Write-Host "Step 2: Calling provider.Get..." -ForegroundColor Yellow
    $storedCred = & $provider.Get "OpenAI"
    
    if ($null -eq $storedCred) {
        Write-Host "✗ Provider.Get returned null" -ForegroundColor Red
    } else {
        Write-Host "✓ Provider.Get returned object" -ForegroundColor Green
        Write-Host "Object type: $($storedCred.GetType().Name)" -ForegroundColor Yellow
        Write-Host "Object properties: $($storedCred.PSObject.Properties.Name -join ', ')" -ForegroundColor Yellow
        
        Write-Host "Step 3: Checking credential property..." -ForegroundColor Yellow
        if ($null -eq $storedCred.Credential) {
            Write-Host "✗ storedCred.Credential is null" -ForegroundColor Red
        } else {
            Write-Host "✓ storedCred.Credential exists" -ForegroundColor Green
            Write-Host "Credential type: $($storedCred.Credential.GetType().Name)" -ForegroundColor Yellow
            Write-Host "Username: $($storedCred.Credential.UserName)" -ForegroundColor Yellow
            
            Write-Host "Step 4: Checking password property..." -ForegroundColor Yellow
            if ($null -eq $storedCred.Credential.Password) {
                Write-Host "✗ storedCred.Credential.Password is null" -ForegroundColor Red
            } else {
                Write-Host "✓ storedCred.Credential.Password exists" -ForegroundColor Green
                Write-Host "Password type: $($storedCred.Credential.Password.GetType().Name)" -ForegroundColor Yellow
                Write-Host "Password length: $($storedCred.Credential.Password.Length)" -ForegroundColor Yellow
                
                Write-Host "Step 5: Testing SecureString to BSTR conversion..." -ForegroundColor Yellow
                try {
                    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($storedCred.Credential.Password)
                    if ($bstr -eq [System.IntPtr]::Zero) {
                        Write-Host "✗ SecureStringToBSTR returned null pointer" -ForegroundColor Red
                    } else {
                        Write-Host "✓ SecureStringToBSTR succeeded" -ForegroundColor Green
                        
                        Write-Host "Step 6: Testing BSTR to string conversion..." -ForegroundColor Yellow
                        try {
                            $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($bstr)
                            if ([string]::IsNullOrEmpty($plainText)) {
                                Write-Host "✗ PtrToStringUni returned empty/null string" -ForegroundColor Red
                            } else {
                                Write-Host "✓ Successfully converted to plain text (length: $($plainText.Length))" -ForegroundColor Green
                            }
                        } finally {
                            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
                        }
                    }
                } catch {
                    Write-Host "✗ SecureString conversion failed: $_" -ForegroundColor Red
                    Write-Host "Exception type: $($_.Exception.GetType().Name)" -ForegroundColor Yellow
                    Write-Host "Exception message: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        }
    }
} catch {
    Write-Host "✗ Step-by-step retrieval failed: $_" -ForegroundColor Red
    Write-Host "Exception type: $($_.Exception.GetType().Name)" -ForegroundColor Yellow
    Write-Host "Exception message: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Test 9: Try the actual function that's failing
Write-Host "`n--- Test 9: Testing Get-StoredCredentialPlainText ---" -ForegroundColor Cyan
try {
    Write-Host "Attempting Get-StoredCredentialPlainText -Name 'OpenAI'..." -ForegroundColor Yellow
    $result = Get-StoredCredentialPlainText -Name "OpenAI"
    if ($result) {
        Write-Host "✓ Successfully retrieved plain text credentials" -ForegroundColor Green
        Write-Host "Result count: $($result.Count)" -ForegroundColor Yellow
        $result | ForEach-Object { 
            Write-Host "  Name: $($_.Name), Username: $($_.Username), Password Length: $($_.Password.Length)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✗ Function returned null/empty result" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Get-StoredCredentialPlainText failed: $_" -ForegroundColor Red
    Write-Host "Exception type: $($_.Exception.GetType().Name)" -ForegroundColor Yellow
    Write-Host "Exception message: $($_.Exception.Message)" -ForegroundColor Yellow
    if ($_.Exception.InnerException) {
        Write-Host "Inner exception: $($_.Exception.InnerException.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Diagnostic Complete ===" -ForegroundColor Cyan
Write-Host "Please share the output above to help identify the specific issue." -ForegroundColor Yellow
