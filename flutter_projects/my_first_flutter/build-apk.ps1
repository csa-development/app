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
# --obfuscate scrambles the app's Dart symbol names so the shipped APK is much
# harder to read; the matching symbol files in build\symbols are what turn a
# crash report back into readable code, so keep them for each release you ship.
flutter build apk --release --obfuscate --split-debug-info=build\symbols @args
