[CmdletBinding()]
param(
    [ValidateSet('debug', 'release')]
    [string]$BuildMode = $(
        if ($env:TAMASHII_NETWORK_POLICY_BUILD_MODE) {
            $env:TAMASHII_NETWORK_POLICY_BUILD_MODE
        } else {
            'debug'
        }
    ),

    [string]$DeviceId = $env:TAMASHII_DEVICE_ID,

    [string]$TimeoutMinutes = $(
        if ($env:TAMASHII_NETWORK_POLICY_TEST_TIMEOUT_MINUTES) {
            $env:TAMASHII_NETWORK_POLICY_TEST_TIMEOUT_MINUTES
        } else {
            '5'
        }
    ),

    [switch]$KeepOnFailure
)

$ErrorActionPreference = 'Stop'
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')
$diagnosticsRoot = Join-Path $repoRoot "build\test-network-policy\$timestamp"
New-Item -ItemType Directory -Force -Path $diagnosticsRoot | Out-Null
$logPath = Join-Path $diagnosticsRoot 'flutter-test.log'
$resultPath = Join-Path $diagnosticsRoot 'result.json'
New-Item -ItemType File -Force -Path $logPath | Out-Null

$script:lastFlutterExitCode = $null
$script:selectedTargetPlatform = $null
$script:resolvedTimeoutMinutes = $null
$script:releaseArtifactBuilt = $false
$script:testExecutionMode = if ($BuildMode -eq 'release') { 'profile' } else { 'debug' }
$script:handlingFailure = $false
$script:temporaryKeyProperties = $false
$keyPropertiesPath = Join-Path $repoRoot 'android\key.properties'
$keep = $KeepOnFailure.IsPresent -or
    $env:TAMASHII_KEEP_NETWORK_POLICY_TEST_DATA -match '^(1|true|yes)$'

function Write-TestResult {
    param(
        [Parameter(Mandatory = $true)][bool]$Passed,
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [string]$ErrorMessage
    )

    $result = [ordered]@{
        passed = $Passed
        device = $DeviceId
        targetPlatform = $script:selectedTargetPlatform
        buildMode = $BuildMode
        testExecutionMode = $script:testExecutionMode
        releaseArtifactBuilt = $script:releaseArtifactBuilt
        timeoutMinutes = $script:resolvedTimeoutMinutes
        keepOnFailure = $keep
        testFile = 'integration_test/network_policy_integration_test.dart'
        exitCode = $ExitCode
        log = $logPath
        result = $resultPath
        completedAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    if ($ErrorMessage) {
        $result.error = $ErrorMessage
    }

    $json = $result | ConvertTo-Json -Compress
    $json | Set-Content -LiteralPath $resultPath -Encoding utf8
    Write-Output "TAMASHII_NETWORK_POLICY_TEST_RESULT=$json"
}

trap {
    if ($script:handlingFailure) {
        exit 1
    }
    $script:handlingFailure = $true
    $message = $_.Exception.Message
    if ($script:temporaryKeyProperties -and
        (Test-Path -LiteralPath $keyPropertiesPath)) {
        Remove-Item -LiteralPath $keyPropertiesPath -Force
    }
    "ERROR: $message" | Add-Content -LiteralPath $logPath -Encoding utf8
    Write-TestResult -Passed $false -ExitCode 1 -ErrorMessage $message
    exit 1
}

$parsedTimeout = 0
if (-not [int]::TryParse($TimeoutMinutes, [ref]$parsedTimeout) -or
    $parsedTimeout -lt 1 -or $parsedTimeout -gt 60) {
    throw 'TimeoutMinutes must be an integer from 1 to 60.'
}
$script:resolvedTimeoutMinutes = $parsedTimeout

$flutterExecutable = $null
$useFvm = $false
if ($env:TAMASHII_FLUTTER) {
    $flutterExecutable = (Resolve-Path -LiteralPath $env:TAMASHII_FLUTTER).Path
} elseif (Get-Command fvm -ErrorAction SilentlyContinue) {
    $flutterExecutable = (Get-Command fvm).Source
    $useFvm = $true
} else {
    $fvmFlutter = Join-Path $repoRoot '.fvm\flutter_sdk\bin\flutter.bat'
    $defaultFvmFlutter = Join-Path $env:USERPROFILE 'fvm\default\bin\flutter.bat'
    if (Test-Path -LiteralPath $fvmFlutter) {
        $flutterExecutable = $fvmFlutter
    } elseif (Test-Path -LiteralPath $defaultFvmFlutter) {
        $flutterExecutable = $defaultFvmFlutter
    }
}
if (-not $flutterExecutable) {
    throw 'FVM Flutter was not found. Install FVM or set TAMASHII_FLUTTER.'
}

function Invoke-Flutter {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    if ($useFvm) {
        & $flutterExecutable flutter @Arguments
    } else {
        & $flutterExecutable @Arguments
    }
    $script:lastFlutterExitCode = $LASTEXITCODE
}

function New-SmokeSigningConfigIfNeeded {
    if (Test-Path -LiteralPath $keyPropertiesPath) {
        return
    }

    $keytool = Get-Command keytool -ErrorAction SilentlyContinue
    if (-not $keytool) {
        throw 'keytool is required to create the temporary Release smoke-test key.'
    }
    $keystorePath = Join-Path $diagnosticsRoot 'smoke-upload-keystore.jks'
    & $keytool.Source `
        -genkeypair `
        -keystore $keystorePath `
        -storepass tamashii-smoke `
        -keypass tamashii-smoke `
        -alias smoke `
        -keyalg RSA `
        -keysize 2048 `
        -validity 1 `
        -dname 'CN=Tamashii CI' 2>&1 |
        Add-Content -LiteralPath $logPath -Encoding utf8
    if ($LASTEXITCODE -ne 0) {
        throw "keytool failed with exit code $LASTEXITCODE."
    }

    $propertiesKeystorePath = $keystorePath.Replace('\', '/')
    @(
        'storePassword=tamashii-smoke',
        'keyPassword=tamashii-smoke',
        'keyAlias=smoke',
        "storeFile=$propertiesKeystorePath"
    ) | Set-Content -LiteralPath $keyPropertiesPath -Encoding utf8
    $script:temporaryKeyProperties = $true
}

function Remove-SmokeSigningConfig {
    if ($script:temporaryKeyProperties -and
        (Test-Path -LiteralPath $keyPropertiesPath)) {
        Remove-Item -LiteralPath $keyPropertiesPath -Force
    }
    $script:temporaryKeyProperties = $false
}

$deviceJson = (Invoke-Flutter devices --machine 2>&1 | Out-String)
$deviceExitCode = $script:lastFlutterExitCode
'Flutter devices:' | Add-Content -LiteralPath $logPath -Encoding utf8
$deviceJson | Add-Content -LiteralPath $logPath -Encoding utf8
if ($deviceExitCode -ne 0) {
    throw 'flutter devices failed.'
}
try {
    $devices = @($deviceJson | ConvertFrom-Json)
} catch {
    throw "flutter devices returned invalid JSON: $($_.Exception.Message)"
}

$device = if ($DeviceId) {
    $devices | Where-Object { $_.id -eq $DeviceId } | Select-Object -First 1
} else {
    $devices |
        Where-Object {
            $_.isSupported -and $_.targetPlatform -like 'android-*'
        } |
        Sort-Object `
            @{ Expression = { if ($_.targetPlatform -eq 'android-x64') { 0 } else { 1 } } },
            @{ Expression = { if ($_.emulator) { 0 } else { 1 } } },
            id |
        Select-Object -First 1
}
if (-not $device) {
    throw 'No matching Android device is available. Start/connect one or pass -DeviceId.'
}
if (-not $device.isSupported -or $device.targetPlatform -notlike 'android-*') {
    throw "Flutter device '$($device.id)' is not a supported Android device."
}
$DeviceId = [string]$device.id
$script:selectedTargetPlatform = [string]$device.targetPlatform
"Selected device: $DeviceId ($($device.targetPlatform))" |
    Add-Content -LiteralPath $logPath -Encoding utf8

$defineArguments = @(
    '--dart-define=TAMASHII_USE_TEST_TORRENT=true',
    '--dart-define=TAMASHII_ENABLE_NETWORK_POLICY_TEST_HOOK=true',
    "--dart-define=TAMASHII_NETWORK_POLICY_TEST_TIMEOUT_MINUTES=$parsedTimeout",
    "--dart-define=TAMASHII_KEEP_NETWORK_POLICY_TEST_DATA=$($keep.ToString().ToLowerInvariant())"
)

Push-Location $repoRoot
try {
    $ErrorActionPreference = 'Continue'
    if ($BuildMode -eq 'release') {
        New-SmokeSigningConfigIfNeeded
        'Building the actual Android Release artifact before the Profile integration run.' |
            Tee-Object -FilePath $logPath -Append
        $script:lastFlutterExitCode = $null
        Invoke-Flutter build apk --release @defineArguments 2>&1 |
            Tee-Object -FilePath $logPath -Append
        $releaseExitCode = if ($null -eq $script:lastFlutterExitCode) {
            1
        } else {
            $script:lastFlutterExitCode
        }
        if ($releaseExitCode -ne 0) {
            throw "Flutter Release build failed with exit code $releaseExitCode."
        }
        $script:releaseArtifactBuilt = $true
        Remove-SmokeSigningConfig
    }

    $testArguments = if ($BuildMode -eq 'release') {
        @(
            'drive',
            '--driver=test_driver/integration_test.dart',
            '--target=integration_test/network_policy_integration_test.dart',
            '-d',
            $DeviceId,
            '--profile'
        ) + $defineArguments
    } else {
        @(
            'test',
            'integration_test/network_policy_integration_test.dart',
            '-d',
            $DeviceId
        ) + $defineArguments
    }

    $script:lastFlutterExitCode = $null
    Invoke-Flutter @testArguments 2>&1 | Tee-Object -FilePath $logPath -Append
    $testExitCode = if ($null -eq $script:lastFlutterExitCode) {
        1
    } else {
        $script:lastFlutterExitCode
    }
} finally {
    $ErrorActionPreference = 'Stop'
    Remove-SmokeSigningConfig
    Pop-Location
}

$errorMessage = if ($testExitCode -eq 0) {
    $null
} else {
    "Flutter integration test failed with exit code $testExitCode."
}
Write-TestResult `
    -Passed ($testExitCode -eq 0) `
    -ExitCode $testExitCode `
    -ErrorMessage $errorMessage
exit $testExitCode
