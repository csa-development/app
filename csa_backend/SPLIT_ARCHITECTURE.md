# CSA backend: mobile/admin process separation

This document covers the two-process split introduced to isolate the
citizen-facing API from the staff-facing API: what exists, how to run it
in dev, the migration-ownership rule (Part 6), and what production
deployment should look like once this is actually deployed (Part 7,
documentation only — nothing below this point has been implemented as
infrastructure).

## What changed

One combined Django project (`csa_project/`, left on disk untouched —
see "What happened to csa_project" below) became three things:

```
csa_backend/
  csa_shared_models/   # installable package: models, migrations, signals
  csa_mobile_api/      # citizen-facing Django project — port 8000
  csa_admin_api/        # staff-facing Django project — port 8001
  shared_media/          # one media folder, both processes read/write it
  db_setup/
    01_roles_and_grants.sql
  csa_project/           # original combined project — untouched, not run
```

`csa_mobile_api` and `csa_admin_api` are independently runnable Django
projects with their own `manage.py`, `venv/`, `.env`, and `SECRET_KEY`.
Both connect to the **same** `csa_db` Postgres database, using **different**
database users with different table-level privileges (see
`db_setup/01_roles_and_grants.sql`). This is a process split, not a
database split.

### Why csa_shared_models exists

Both processes need the exact same model definitions — same tables,
same fields — because they're reading and writing the same database.
Rather than maintaining two independent copies of `models.py` (real
drift risk: a field added on one side and forgotten on the other, silently
breaking the other process at the next deploy), the model classes,
their migrations, and the `incidents` app's `pre_save` signal (which
fires an FCM push notification when `Incident.status` changes, no
matter which process performs the update) live in one place:
`csa_shared_models/`. Both projects install it as an editable local
package:

```
pip install -e ../csa_shared_models
```

A change to a model or the signal is made once, in `csa_shared_models/`,
and both processes pick it up immediately (editable install — no
publishing/reinstalling step).

## Part 6 — Migration ownership

**`csa_mobile_api` is the only project that ever runs `makemigrations` or
`migrate`.** Never run either from `csa_admin_api`.

This is enforced two ways, not just documented:

1. `csa_admin_api/csa_admin_api/settings.py` sets:
   ```python
   MIGRATION_MODULES = {'accounts': None, 'content': None, 'incidents': None}
   ```
   This makes `migrate` a safe no-op for these three apps from
   `csa_admin_api`, and makes `makemigrations` for them raise a hard
   Django error instead of silently generating migration files that
   would drift from `csa_mobile_api`'s copy.
2. `admin_api_user` (the Postgres role `csa_admin_api` connects as) has
   no `CREATE`/`ALTER` grants at all — even a `--run-syncdb` mistake
   would fail at the database level, not just the Django level.

To change the schema in the future:

```powershell
cd csa_backend\csa_mobile_api
.\venv\Scripts\Activate.ps1
# confirm (venv) shows in the prompt before continuing
python manage.py makemigrations
# review the generated file in csa_shared_models\csa_shared_models\<app>\migrations\
python manage.py migrate
```

`migrate` must be run using the `csa_migrator` role's credentials (see
below), not `mobile_api_user`'s — `mobile_api_user` also has no
`CREATE`/`ALTER` grants, on purpose, for the same defense-in-depth
reason as `admin_api_user`.

```powershell
$env:DB_USER = "csa_migrator"
$env:DB_PASSWORD = "<csa_migrator's password>"
python manage.py migrate
Remove-Item Env:\DB_USER, Env:\DB_PASSWORD
```

`csa_migrator`'s credentials are **never** written into either
project's `.env` file — they exist only for this manual step, run by a
human, never used to serve a request.

## Dev quickstart

Each project needs its own venv activated before running any `pip` or
`manage.py` command — confirm `(venv)` shows in your prompt first.

```powershell
# One-time setup, each project:
cd csa_backend\csa_mobile_api
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt   # includes `-e ../csa_shared_models`

cd ..\csa_admin_api
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt

# Every time you run either service:
cd csa_backend\csa_mobile_api
.\venv\Scripts\Activate.ps1
python manage.py runserver 8000

# in a separate terminal:
cd csa_backend\csa_admin_api
.\venv\Scripts\Activate.ps1
python manage.py runserver 8001
```

Each is independently startable and stoppable — stopping one has no
effect on the other (separate processes, separate ports, separate
`SECRET_KEY`s, separate DB credentials).

### Flutter and admin-web

- `flutter_projects/my_first_flutter/lib/services/api_service.dart`
  `baseUrl` points at `csa_mobile_api` (port 8000). If you change it,
  run a full `flutter clean && flutter pub get && flutter run` — hot
  reload doesn't reliably pick up structural changes in this project.
- `admin-web/vite.config.js`'s dev proxy points `/api` and `/media` at
  `csa_admin_api` (port 8001).

## What happened to csa_project

Left on disk, untouched. It's no longer the thing you should run day to
day — `csa_mobile_api` and `csa_admin_api` are — but nothing was deleted
or modified there, and its original `csa_user` database role keeps
whatever access it already had. Retiring it fully (removing the
directory, dropping `csa_user`) is a separate decision for later, not
part of this task.

## Known limitations (documented, not solved by this split)

- **Postgres `GRANT` is table-level, not row-level.** It cannot express
  "a citizen can only read their own `accounts_userprofile` row" —
  `mobile_api_user` can `SELECT` the whole table. That restriction is,
  and remains, enforced in Django's queryset filtering
  (`.filter(user=request.user)`), exactly as it was before this split.
  The database grants in `db_setup/01_roles_and_grants.sql` only stop
  `mobile_api_user` from reaching tables it has no legitimate reason to
  touch at all (certificates, staff role tables) — not from over-fetching
  within a table it's allowed to query.
- **Citizen and staff accounts share one `auth_user` table.** Citizen
  registration uses `User.objects.create_user`; staff login also
  queries `auth_user` filtered by `is_staff=True`. `mobile_api_user`
  therefore needs read/write access to `auth_user` for citizen
  login/OTP/profile edits, and `admin_api_user` needs broader access for
  staff login and citizen-user management. This table isn't cleanly
  splittable to one side only within this task's scope.

## Part 7 — Deployment (documentation only, not implemented)

No Gunicorn/Nginx setup exists yet — `DEBUG=True` in both `.env` files
today, and this app hasn't been deployed to production. This section
describes what deployment *should* look like once that happens; nothing
here has been built.

### Two independent services

Each project becomes its own systemd service running its own Gunicorn
process, bound to its own local port:

```ini
# /etc/systemd/system/csa-mobile-api.service
[Unit]
Description=CSA Mobile API (citizen-facing)
After=network.target postgresql.service

[Service]
User=csa
WorkingDirectory=/opt/csa/csa_backend/csa_mobile_api
Environment="DJANGO_SETTINGS_MODULE=csa_mobile_api.settings"
ExecStart=/opt/csa/csa_backend/csa_mobile_api/venv/bin/gunicorn \
    csa_mobile_api.wsgi:application --bind 127.0.0.1:8000 --workers 3
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```ini
# /etc/systemd/system/csa-admin-api.service
[Unit]
Description=CSA Admin API (staff-facing)
After=network.target postgresql.service

[Service]
User=csa
WorkingDirectory=/opt/csa/csa_backend/csa_admin_api
Environment="DJANGO_SETTINGS_MODULE=csa_admin_api.settings"
ExecStart=/opt/csa/csa_backend/csa_admin_api/venv/bin/gunicorn \
    csa_admin_api.wsgi:application --bind 127.0.0.1:8001 --workers 2
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Two separate `systemctl` units means `systemctl restart csa-mobile-api`
never touches `csa-admin-api`, and a crash in one (`Restart=on-failure`
brings it back on its own) never takes the other down — they don't
share a process, a worker pool, or a supervisor.

### Routing

Nginx (or equivalent) terminates TLS and routes by hostname to the two
local ports:

```nginx
server {
    server_name api.csa.gov.gh;
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    server_name admin-api.csa.gov.gh;
    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

`ALLOWED_HOSTS` in each project's production `.env` should then be set
to exactly its own hostname (`api.csa.gov.gh` / `admin-api.csa.gov.gh`),
not both.

### Monitoring / restart independence

Both services should be monitored separately (separate health checks,
separate alerting) — the whole point of the split is that
`admin-api.csa.gov.gh` being down (bad deploy, resource exhaustion,
compromise) is an *admin* incident, not something that also takes the
public-facing citizen API offline, and vice versa.

### Before any of this is implemented for real

- Set a real `SECRET_KEY` in both `.env` files (not the insecure
  fallback in `settings.py`) — both already hard-fail at startup with
  `DEBUG=False` if this isn't done.
- Flip `DEBUG=False` in both.
- Run `collectstatic` for `csa_admin_api` (it serves the Django admin
  site's static assets via WhiteNoise).
- Point `MEDIA_ROOT` at persistent, backed-up storage — `shared_media/`
  as a plain directory is fine for dev, but production media should
  live somewhere with real backups (and ideally survives a server
  being rebuilt, e.g. object storage or a mounted volume).
