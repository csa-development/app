# Builds the release APK, working around the "Unable to establish loopback
# connection" Gradle failure on this machine (space in the Windows username
# "CSA HP 70" breaks Java's AF_UNIX socket path under the default temp dir).
# See android/gradle.properties for the full explanation.
$ErrorActionPreference = 'Stop'

$tmp = 'C:\gradletmp'
if (-not (Test-Path $tmp)) { New-Item -ItemType Directory -Path $tmp | Out-Null }

$env:TMP  = $tmp
$env:TEMP = $tmp

Set-Location -Path $PSScriptRoot
flutter build apk --release @args
