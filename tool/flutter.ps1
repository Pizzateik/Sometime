param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArguments
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$localFlutter = Join-Path $projectRoot '.tools\flutter\bin\flutter.bat'

if (-not (Test-Path -LiteralPath $localFlutter)) {
    throw 'Install the Flutter SDK in .tools/flutter before you use this script.'
}

$env:PUB_CACHE = Join-Path $projectRoot '.tools\pub-cache'
$env:GRADLE_USER_HOME = Join-Path $projectRoot '.tools\gradle'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:CI = 'true'

$androidSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
if (Test-Path -LiteralPath $androidSdk) {
    $env:ANDROID_HOME = $androidSdk
}

$androidJava = 'C:\Program Files\Android\Android Studio\jbr'
if (Test-Path -LiteralPath $androidJava) {
    $env:JAVA_HOME = $androidJava
}

Push-Location -LiteralPath $projectRoot
try {
    & $localFlutter @FlutterArguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
