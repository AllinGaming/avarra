[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$SkipToolchainInstall
)

$ErrorActionPreference = 'Stop'

$expectedFlutterVersion = '3.44.4'
$expectedDartVersion = '3.12.2'
$minimumJavaMajorVersion = 17
$androidPackages = @(
    'platforms;android-36',
    'build-tools;36.0.0',
    'ndk;28.2.13676358',
    'cmake;3.22.1'
)

$repositoryRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$gameDirectory = [System.IO.Path]::GetFullPath(
    (Join-Path $repositoryRoot 'apps\avarra_game')
)
$apkPath = [System.IO.Path]::GetFullPath(
    (Join-Path $gameDirectory 'build\app\outputs\flutter-apk\app-debug.apk')
)
$repositoryPrefix = $repositoryRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar

if (-not $gameDirectory.StartsWith(
    $repositoryPrefix,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Resolved Game directory is outside the repository: $gameDirectory"
}

if (-not $apkPath.StartsWith(
    $repositoryPrefix,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Resolved APK path is outside the repository: $apkPath"
}

if (-not (Test-Path -LiteralPath $gameDirectory -PathType Container)) {
    throw "Avarra Game directory was not found at $gameDirectory"
}

if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot 'pubspec.lock') -PathType Leaf)) {
    throw "Workspace pubspec.lock was not found. Run this script from a complete AVARRA checkout."
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter was not found on PATH.'
}

$flutterVersionOutput = & flutter --version --machine
if ($LASTEXITCODE -ne 0) {
    throw "Flutter version detection failed with exit code $LASTEXITCODE"
}

try {
    $flutterInfo = ($flutterVersionOutput | Out-String) | ConvertFrom-Json
} catch {
    throw "Flutter returned invalid machine-readable version data: $($_.Exception.Message)"
}

$actualFlutterVersion = [string]$flutterInfo.frameworkVersion
$actualDartVersion = ([string]$flutterInfo.dartSdkVersion -split '\s+')[0]
if ($actualFlutterVersion -ne $expectedFlutterVersion) {
    throw "Flutter $expectedFlutterVersion is required, but $actualFlutterVersion is active."
}
if ($actualDartVersion -ne $expectedDartVersion) {
    throw "Dart $expectedDartVersion is required, but $actualDartVersion is active."
}

if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    throw 'Java was not found on PATH.'
}

$javaVersionOutput = & java --version
if ($LASTEXITCODE -ne 0) {
    throw "Java version detection failed with exit code $LASTEXITCODE"
}
$javaVersionText = $javaVersionOutput | Out-String
if ($javaVersionText -notmatch '(?m)^(?:openjdk|java)\s+(?<major>\d+)') {
    throw "Could not parse the active Java version:`n$javaVersionText"
}
$javaMajorVersion = [int]$Matches.major
if ($javaMajorVersion -lt $minimumJavaMajorVersion) {
    throw "Java $minimumJavaMajorVersion or newer is required, but Java $javaMajorVersion is active."
}

$androidSdkRoot = if ($env:ANDROID_HOME) {
    $env:ANDROID_HOME
} elseif ($env:ANDROID_SDK_ROOT) {
    $env:ANDROID_SDK_ROOT
} else {
    $null
}
if (-not $androidSdkRoot) {
    throw 'ANDROID_HOME or ANDROID_SDK_ROOT must identify the Android SDK.'
}
$androidSdkRoot = [System.IO.Path]::GetFullPath($androidSdkRoot)
$sdkManager = Join-Path $androidSdkRoot 'cmdline-tools\latest\bin\sdkmanager.bat'
if (-not (Test-Path -LiteralPath $sdkManager -PathType Leaf)) {
    throw "Android sdkmanager was not found at $sdkManager"
}

Write-Host "Flutter $actualFlutterVersion / Dart $actualDartVersion"
Write-Host "Java $javaMajorVersion"
Write-Host "Android SDK $androidSdkRoot"

if (-not $SkipToolchainInstall) {
    Write-Host 'Installing pinned Android SDK components...'
    & $sdkManager $androidPackages
    if ($LASTEXITCODE -ne 0) {
        throw "Android SDK component installation failed with exit code $LASTEXITCODE"
    }
}

$requiredAndroidPaths = @(
    (Join-Path $androidSdkRoot 'platforms\android-36'),
    (Join-Path $androidSdkRoot 'build-tools\36.0.0'),
    (Join-Path $androidSdkRoot 'ndk\28.2.13676358'),
    (Join-Path $androidSdkRoot 'cmake\3.22.1')
)
foreach ($requiredPath in $requiredAndroidPaths) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Container)) {
        throw "Required Android SDK component was not found at $requiredPath"
    }
}

if ($Clean) {
    Write-Host 'Cleaning the Avarra Game Flutter build...'
    Push-Location $gameDirectory
    try {
        & flutter clean
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter clean failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
}

Write-Host 'Resolving workspace dependencies...'
Push-Location $repositoryRoot
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter dependency resolution failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

Write-Host 'Building the Avarra Game debug APK...'
Push-Location $gameDirectory
try {
    $buildOutput = [System.Collections.Generic.List[string]]::new()
    & flutter build apk --debug --no-pub 2>&1 | ForEach-Object {
        $line = $_.ToString()
        $buildOutput.Add($line)
        Write-Host $line
    }
    $buildExitCode = $LASTEXITCODE
    if ($buildExitCode -ne 0) {
        throw "Android APK build failed with exit code $buildExitCode"
    }
    if (($buildOutput -join "`n") -match 'apply Kotlin Gradle Plugin \(KGP\)') {
        throw 'Android APK build used a Flutter plugin that still applies the legacy Kotlin Gradle Plugin.'
    }
} finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
    throw "Expected Android APK was not produced at $apkPath"
}

$apk = Get-Item -LiteralPath $apkPath
if ($apk.Length -le 0) {
    throw "Android APK is empty at $apkPath"
}
$apkHash = Get-FileHash -Algorithm SHA256 -LiteralPath $apkPath

Write-Host 'Android CI build passed.'
Write-Host "APK=$($apk.FullName)"
Write-Host "BYTES=$($apk.Length)"
Write-Host "SHA256=$($apkHash.Hash)"
