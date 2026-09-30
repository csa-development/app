# HTTPS server + token revocation — setup

Replaces `manage.py runserver` (development only) with uvicorn + TLS, and
turns on JWT refresh-token revocation. Nothing here changes until you run
these steps, so the current dev servers keep working meanwhile.

## 1. Certificates (once)

```
bash csa_backend/certs/make_certs.sh 192.168.31.58
```

Creates `certs/ca.crt` (public — already copied into the app as
`assets/certs/csa_ca.pem`) plus `ca.key` and `server.key` (**private,
gitignored — never share them**). The server cert is valid 397 days and is
tied to the IP given; if the PC's IP changes, re-run with the new IP (the
same CA is reused) and rebuild the APK, whose URL is fixed to that IP.

## 2. Token blacklist tables (once, needs the migrator password)

From `csa_backend/csa_mobile_api`:

```
$env:DB_USER='csa_migrator'; $env:DB_PASSWORD='<migrator password>'
$env:ENABLE_TOKEN_BLACKLIST='True'
..\csa_mobile_api\venv\Scripts\python.exe manage.py migrate token_blacklist
psql -U csa_migrator -d csa_db -f ..\db_setup\02_token_blacklist_grants.sql
```

Until this is done `run_server.ps1` starts with the blacklist OFF and says
so. Close the shell afterwards so the migrator password isn't left in it.

## 3. Run the servers (replaces runserver)

Stop the old `runserver` windows first, then:

```
.\csa_backend\run_server.ps1 -App mobile     # https://<lan-ip>:8000  (phones)
.\csa_backend\run_server.ps1 -App admin      # https://127.0.0.1:8001 (admin portal)
```

DEBUG is forced off, so each app's `.env` needs a real `SECRET_KEY`.
Open Windows Firewall for port 8000 on the local subnet only:

```
New-NetFirewallRule -DisplayName "CSA Mobile API 8000 (LAN only)" -Direction Inbound -Protocol TCP -LocalPort 8000 -RemoteAddress LocalSubnet -Action Allow -Profile Any
```

Admin web (`admin-web`): start Vite with the HTTPS target —

```
$env:ADMIN_API_TARGET='https://127.0.0.1:8001'; npm run dev
```

## 4. Phones

Install the APK built after these changes. It only talks HTTPS and trusts
the CA above. An APK built before this cannot reach the HTTPS server, and
the new APK cannot reach an old plain-HTTP `runserver` — switch together.

## Not covered

* Access tokens already issued stay valid up to 30 min after logout /
  password change (disabled accounts are refused immediately).
* `runserver`-free ≠ production-grade: put nginx/IIS (or a cloud host) with
  a real certificate in front before a public rollout.
* The Django `/admin/` login page exists on the admin API (loopback only).
