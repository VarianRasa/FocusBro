param(
    [ValidateSet('launch', 'wait', 'reset-app', 'grant-basic', 'screenshot', 'logcat', 'status')]
    [string]$Action = 'status',
    [string]$DeviceId = 'emulator-5554',
    [string]$EmulatorId = 'Pixel_8_Pro_API_33',
    [string]$PackageName = 'com.example.focusbro'
)

$ErrorActionPreference = 'Stop'

function Resolve-Adb {
    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    if ($null -ne $adbCommand) {
        return $adbCommand.Source
    }

    $candidates = @()
    if ($env:ANDROID_SDK_ROOT) {
        $candidates += Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe'
    }
    if ($env:ANDROID_HOME) {
        $candidates += Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
    }
    if ($env:LOCALAPPDATA) {
        $candidates += Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'
    }

    $candidates = @($candidates | Where-Object { Test-Path $_ })

    if ($candidates.Count -eq 0) {
        throw 'adb was not found. Install Android platform-tools or set ANDROID_SDK_ROOT.'
    }

    return $candidates[0]
}

$Adb = Resolve-Adb

function Invoke-Adb {
    param([string[]]$Arguments)

    & $Adb -s $DeviceId @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "adb failed: $($Arguments -join ' ')"
    }
}

switch ($Action) {
    'launch' {
        flutter emulators --launch $EmulatorId
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to launch emulator: $EmulatorId"
        }
    }
    'wait' {
        & $Adb -s $DeviceId wait-for-device
        if ($LASTEXITCODE -ne 0) {
            throw "Failed waiting for device: $DeviceId"
        }

        do {
            Start-Sleep -Seconds 2
            $booted = (& $Adb -s $DeviceId shell getprop sys.boot_completed).Trim()
        } until ($booted -eq '1')
        Write-Output "$DeviceId booted"
    }
    'reset-app' {
        Invoke-Adb @('shell', 'pm', 'clear', $PackageName)
    }
    'grant-basic' {
        Invoke-Adb @('shell', 'pm', 'grant', $PackageName, 'android.permission.POST_NOTIFICATIONS')
        Invoke-Adb @('shell', 'pm', 'grant', $PackageName, 'android.permission.RECORD_AUDIO')
    }
    'screenshot' {
        New-Item -ItemType Directory -Force -Path 'build\android-qa' | Out-Null
        Invoke-Adb @('shell', 'screencap', '-p', '/sdcard/focusbro-qa.png')
        Invoke-Adb @('pull', '/sdcard/focusbro-qa.png', 'build\android-qa\screenshot.png')
        Invoke-Adb @('shell', 'rm', '/sdcard/focusbro-qa.png')
    }
    'logcat' {
        New-Item -ItemType Directory -Force -Path 'build\android-qa' | Out-Null
        & $Adb -s $DeviceId logcat -d |
            Set-Content -Encoding UTF8 'build\android-qa\logcat.txt'
        if ($LASTEXITCODE -ne 0) {
            throw 'Failed to capture logcat'
        }
    }
    'status' {
        flutter devices
        if ($LASTEXITCODE -ne 0) {
            throw 'Failed to list Flutter devices'
        }

        Invoke-Adb @('shell', 'getprop', 'ro.build.version.sdk')
        Invoke-Adb @('shell', 'settings', 'get', 'secure', 'enabled_accessibility_services')
        Invoke-Adb @('shell', 'settings', 'get', 'global', 'zen_mode')
    }
}
