# Runs a CSA API the "real" way: uvicorn + TLS, DEBUG off, static files
# collected, and (when its tables exist) the JWT refresh-token blacklist on.
# Replaces `manage.py runserver`, which is a development server.
#
#   .\run_server.ps1 -App mobile          # phones -> https://<lan-ip>:8000
#   .\run_server.ps1 -App admin           # admin portal -> https://127.0.0.1:8001
#
# One-time setup: bash certs/make_certs.sh <lan-ip>
#
# DEBUG is forced OFF here regardless of .env, so this behaves like a
# deployed server (JSON-only errors, no debug pages, secure cookies, HTTPS
# redirect). It therefore needs a real SECRET_KEY in that app's .env.
param(
    [Parameter(Mandatory)][ValidateSet('mobile', 'admin')][string]$App,
    [int]$Port = 0
)
$ErrorActionPreference = 'Stop'

$appDir = Join-Path $PSScriptRoot "csa_${App}_api"
$py     = Join-Path $appDir 'venv\Scripts\python.exe'
$cert   = Join-Path $PSScriptRoot 'certs\server.crt'
$key    = Join-Path $PSScriptRoot 'certs\server.key'

foreach ($f in @($py, $cert, $key)) {
    if (-not (Test-Path $f)) {
        throw "Missing $f  (certificates: run  bash certs/make_certs.sh <lan-ip>)"
    }
}

# Phones must reach the mobile API over the network; the admin API is only
# ever used from this PC, so it stays on loopback.
if ($App -eq 'mobile') { $bind = '0.0.0.0';   if ($Port -eq 0) { $Port = 8000 } }
else                   { $bind = '127.0.0.1'; if ($Port -eq 0) { $Port = 8001 } }

Set-Location $appDir
$env:DEBUG = 'False'

# Blacklist only if its tables exist — otherwise every login would 500.
$env:ENABLE_TOKEN_BLACKLIST = 'True'
$probe = "from django.db import connection; print('TB_OK' if 'token_blacklist_outstandingtoken' in connection.introspection.table_names() else 'TB_MISSING')"
$result = (& $py manage.py shell -c $probe 2>&1 | Out-String)
if ($result -notmatch 'TB_OK') {
    $env:ENABLE_TOKEN_BLACKLIST = 'False'
    Write-Warning ("Token blacklist is OFF: its tables don't exist yet. Apply them " +
        "(see db_setup/02_token_blacklist_grants.sql), then restart this script.")
    if ($result -match 'SECRET_KEY|ImproperlyConfigured|RuntimeError') { Write-Host $result; throw 'Server settings failed to load (see above).' }
} else {
    Write-Host 'Token blacklist: ON' -ForegroundColor Green
}

& $py manage.py collectstatic --noinput | Out-Null

Write-Host "Serving csa_${App}_api on https://${bind}:${Port}  (DEBUG off)" -ForegroundColor Cyan
& $py -m uvicorn "csa_${App}_api.asgi:application" `
    --host $bind --port $Port `
    --ssl-keyfile $key --ssl-certfile $cert `
    --lifespan off --no-server-header
