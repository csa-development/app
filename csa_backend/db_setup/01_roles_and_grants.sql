-- =============================================================
-- CSA backend split: Postgres roles + scoped GRANT/REVOKE
-- =============================================================
--
-- WHO RUNS THIS: a Postgres SUPERUSER (e.g. the `postgres` role), once,
-- against the existing csa_db database. csa_user (the original app's
-- DB user) does NOT have CREATEROLE and cannot run this itself — that
-- was confirmed while writing this script: `csa_user` owns the
-- `public` schema (so it can grant on the tables it owns) but cannot
-- create new login roles.
--
-- Passwords are NOT hardcoded in this file — it is committed to git,
-- and a plaintext superuser password here would be a standing leak for
-- as long as the repo exists. Instead, pass them in at invocation time
-- as psql variables:
--
--   psql -U postgres -d csa_db \
--     -v mobile_pw="<new-mobile_api_user-password>" \
--     -v admin_pw="<new-admin_api_user-password>" \
--     -v migrator_pw="<new-csa_migrator-password>" \
--     -f 01_roles_and_grants.sql
--
-- (no quotes around the password values themselves — :'mobile_pw' below
-- has psql add them, correctly escaped, which plain :mobile_pw does not)
--
-- Generate strong random values for each (e.g. `openssl rand -base64 24`
-- per password) — never reuse a password across roles, and never reuse
-- a password that has ever been committed to this repo, including in
-- git history.
--
-- After it runs, put mobile_api_user's and admin_api_user's passwords
-- into csa_mobile_api/.env and csa_admin_api/.env respectively
-- (DB_PASSWORD=...) — both files are gitignored, that's where secrets
-- belong. Keep csa_migrator's password out of every .env file; it's
-- used by hand only, per the note at the bottom of this file.
--
-- To rotate an existing role's password later (this file only CREATEs
-- roles, it won't re-run cleanly): run
-- `ALTER ROLE <name> WITH PASSWORD '<new-password>';` directly against
-- the live database, then update the matching .env file to match — do
-- not edit only one side.
--
-- WHAT THIS DOES NOT DO: split csa_db into multiple databases. All
-- three roles below connect to the same csa_db — only their table-level
-- permissions differ.
--
-- KNOWN LIMITATION (documented, not solved here): Postgres GRANT is
-- table-level, not row-level. It cannot express "a citizen can only
-- read their own accounts_userprofile row" — mobile_api_user can SELECT
-- the whole table. That restriction is, and remains, enforced in
-- Django's queryset filtering (`.filter(user=request.user)`), exactly
-- as it is today. This script only prevents mobile_api_user from
-- reaching tables it has no business touching at all (certificates,
-- staff role tables, etc.) — not from over-fetching within a table it
-- legitimately needs.
--
-- KNOWN SHARED SURFACE (documented, not solved here): citizen and staff
-- accounts both live in auth_user. mobile_api_user therefore needs read
-- access to auth_user for citizen login/OTP, and admin_api_user needs
-- broader access for staff login and citizen-user management. This
-- table cannot be cleanly split to one side only within this task.
-- =============================================================


-- -------------------------------------------------------------
-- 1. CREATE ROLES
-- -------------------------------------------------------------

-- Runtime role for csa_mobile_api. Narrow, citizen-facing scope only.
CREATE ROLE mobile_api_user WITH LOGIN PASSWORD :'mobile_pw';

-- Runtime role for csa_admin_api. Broader, staff-facing scope.
CREATE ROLE admin_api_user WITH LOGIN PASSWORD :'admin_pw';

-- Migration-only role. SUPERUSER is used here deliberately and only for
-- this role: Postgres GRANT-based privileges (SELECT/INSERT/UPDATE/
-- DELETE) never include DDL (CREATE TABLE / ALTER TABLE) unless the
-- role owns the object (or is superuser) — there is no partial-DDL
-- grant in Postgres. Rather than transfer ownership of the `public`
-- schema away from csa_user (which would silently break the original,
-- still-present csa_project if it's ever run again), csa_migrator is
-- made a superuser so it can freely CREATE/ALTER/DROP without touching
-- who owns what. Its credentials are used manually, only when running
-- `python manage.py migrate` from csa_mobile_api — never stored in any
-- project's .env, never used to serve a single request.
CREATE ROLE csa_migrator WITH LOGIN SUPERUSER PASSWORD :'migrator_pw';


-- -------------------------------------------------------------
-- 2. CONNECT + SCHEMA USAGE
-- -------------------------------------------------------------
-- (csa_migrator needs none of this explicitly — SUPERUSER bypasses all
-- grant checks by definition.)

GRANT CONNECT ON DATABASE csa_db TO mobile_api_user;
GRANT CONNECT ON DATABASE csa_db TO admin_api_user;

GRANT USAGE ON SCHEMA public TO mobile_api_user;
GRANT USAGE ON SCHEMA public TO admin_api_user;

-- Both runtime roles read auto-increment values but never create
-- sequences themselves (Django/migrate does that) — USAGE is enough,
-- not full sequence ownership.
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO mobile_api_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO admin_api_user;


-- -------------------------------------------------------------
-- 3. mobile_api_user — narrow, citizen-facing scope
-- -------------------------------------------------------------
-- SELECT/INSERT/UPDATE only (no DELETE — nothing in the mobile app
-- deletes rows outright, and this is a deliberately tighter default;
-- widen explicitly later if a real feature needs it).

-- Public content the app displays: news/alerts/advisories/notices,
-- events + registrations, campaigns + related tables, press releases.
GRANT SELECT, INSERT, UPDATE ON content_newsarticle        TO mobile_api_user;
GRANT SELECT, INSERT, UPDATE ON content_event               TO mobile_api_user;
GRANT SELECT, INSERT, UPDATE ON content_campaign            TO mobile_api_user;
GRANT SELECT, INSERT, UPDATE ON content_campaigngallery     TO mobile_api_user;
GRANT SELECT, INSERT, UPDATE ON content_campaignschedule    TO mobile_api_user;
GRANT SELECT, INSERT, UPDATE ON content_campaignspeaker     TO mobile_api_user;
GRANT SELECT, INSERT, UPDATE ON content_campaignnews        TO mobile_api_user;
GRANT SELECT, INSERT, UPDATE ON content_pressrelease        TO mobile_api_user;
-- DELETE included: the mobile API's unregister_event_interest view
-- calls registration.delete() when a citizen removes their own
-- registration (was missing here, which made unregister silently
-- fail with a DB permission error).
GRANT SELECT, INSERT, UPDATE, DELETE ON content_eventregistration   TO mobile_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON content_campaignregistration TO mobile_api_user;

-- Incidents citizens submit and read back (their own, filtered in
-- Django).
GRANT SELECT, INSERT, UPDATE ON incidents_incident          TO mobile_api_user;

-- Certificate Verification is a deliberately public, read-only
-- lookup feature — any citizen can check any certificate's validity
-- by number + type, that's the point of the feature. SELECT only:
-- mobile_api_user must never create/edit/delete certificates, only
-- LECO staff (via admin_api_user) can do that.
GRANT SELECT ON incidents_certificate                       TO mobile_api_user;

-- The logged-in citizen's own account data: profile, OTP codes, device
-- tokens (push), feedback they submit, the public contact form,
-- notification prefs, and their own login history.
GRANT SELECT, INSERT, UPDATE ON accounts_userprofile            TO mobile_api_user;
GRANT SELECT, INSERT, UPDATE ON accounts_verificationcode        TO mobile_api_user;
GRANT SELECT, INSERT, UPDATE ON accounts_devicetoken              TO mobile_api_user;
GRANT SELECT, INSERT, UPDATE ON accounts_feedback                 TO mobile_api_user;
GRANT SELECT, INSERT, UPDATE ON accounts_contactmessage           TO mobile_api_user;
GRANT SELECT, INSERT, UPDATE ON accounts_notificationpreference   TO mobile_api_user;
GRANT SELECT, INSERT, UPDATE ON accounts_loginactivity            TO mobile_api_user;

-- Citizen registration/login/profile-edit touches auth_user directly
-- (User.objects.create_user / authenticate() / profile PUT).
GRANT SELECT, INSERT, UPDATE ON auth_user TO mobile_api_user;

-- Explicit REVOKE for anything mobile_api_user must never reach, even
-- if a future GRANT ALL-style command is run by mistake later. Belt
-- and suspenders — these were never granted above, this just makes the
-- boundary impossible to accidentally erode. (incidents_certificate is
-- NOT here — it's deliberately SELECT-granted above for the public
-- verification feature.)
REVOKE ALL ON auth_group                    FROM mobile_api_user;
REVOKE ALL ON auth_permission               FROM mobile_api_user;
REVOKE ALL ON auth_group_permissions        FROM mobile_api_user;
REVOKE ALL ON auth_user_groups              FROM mobile_api_user;
REVOKE ALL ON auth_user_user_permissions    FROM mobile_api_user;
REVOKE ALL ON django_content_type           FROM mobile_api_user;
REVOKE ALL ON django_session                FROM mobile_api_user;

-- SELECT-only (not INSERT/UPDATE/DELETE) on django_migrations: Django's
-- `runserver` reads this table unconditionally at startup just to show
-- its informational "you have N unapplied migrations" banner — it
-- fails to start at all without at least SELECT here. Read access to
-- migration *state* is not schema-altering power; the actual
-- protection (this role can never run `migrate`) comes from having no
-- CREATE/ALTER grants anywhere, which read-only access to this table
-- doesn't change.
REVOKE INSERT, UPDATE, DELETE ON django_migrations FROM mobile_api_user;
GRANT SELECT ON django_migrations TO mobile_api_user;


-- -------------------------------------------------------------
-- 4. admin_api_user — broader, staff-facing scope
-- -------------------------------------------------------------
-- Full CRUD on every domain table: certificates (LECO), incidents
-- (CERT), all content tables (COMMS), full user management (IT),
-- feedback/contact triage (COMMS).

GRANT SELECT, INSERT, UPDATE, DELETE ON content_newsarticle        TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON content_event               TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON content_campaign            TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON content_campaigngallery     TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON content_campaignschedule    TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON content_campaignspeaker     TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON content_campaignnews        TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON content_pressrelease        TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON content_eventregistration   TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON content_campaignregistration TO admin_api_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON incidents_incident          TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON incidents_certificate       TO admin_api_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON accounts_userprofile            TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON accounts_verificationcode        TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON accounts_devicetoken              TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON accounts_feedback                 TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON accounts_contactmessage           TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON accounts_notificationpreference   TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON accounts_loginactivity            TO admin_api_user;

-- Staff login + citizen user management. No DELETE: nothing in the app
-- hard-deletes a User today (only is_active/is_staff toggles) — widen
-- explicitly if a real delete-account feature is built later.
GRANT SELECT, INSERT, UPDATE ON auth_user TO admin_api_user;

-- Role assignment (SUPERADMIN/LECO/CERT/COMMS/IT group membership) is
-- an actively-used write path from the staff-management endpoints.
GRANT SELECT, INSERT, UPDATE, DELETE ON auth_group        TO admin_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON auth_user_groups  TO admin_api_user;

-- Read-only: Django's built-in /admin/ site (installed only in
-- csa_admin_api) references these internally for its own UI; nothing
-- in this app writes to them at runtime.
GRANT SELECT ON auth_permission          TO admin_api_user;
GRANT SELECT ON auth_group_permissions   TO admin_api_user;
GRANT SELECT ON django_content_type      TO admin_api_user;

-- Django's built-in /admin/ site login uses DB-backed sessions
-- (separate from our own JWT auth).
GRANT SELECT, INSERT, UPDATE, DELETE ON django_session TO admin_api_user;

-- Django's built-in /admin/ site writes one row here on every
-- add/change/delete performed through that CMS (not our own RBAC
-- endpoints) — its own "Recent actions" list on the index page reads
-- this too, and errors without at least SELECT.
GRANT SELECT, INSERT, UPDATE, DELETE ON django_admin_log TO admin_api_user;

-- SELECT-only, same reasoning as mobile_api_user above: `runserver`
-- needs to read this table to start at all; it must never be able to
-- write to it (that's what `migrate` does, and neither runtime role
-- can — no CREATE/ALTER grants anywhere for either of them).
REVOKE INSERT, UPDATE, DELETE ON django_migrations FROM admin_api_user;
GRANT SELECT ON django_migrations TO admin_api_user;


-- -------------------------------------------------------------
-- 5. Future tables: ALTER DEFAULT PRIVILEGES
-- -------------------------------------------------------------
-- Without this, a future migration (run by csa_migrator, per Part 6)
-- that adds a brand new table would leave it completely inaccessible
-- to both runtime roles until someone remembers to re-run manual
-- GRANTs. This makes new tables automatically readable/writable by
-- admin_api_user by default; mobile_api_user is deliberately NOT
-- included here — a new table should be an explicit, reviewed decision
-- to expose to the citizen-facing process, not an automatic one.
ALTER DEFAULT PRIVILEGES FOR ROLE csa_migrator IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO admin_api_user;

ALTER DEFAULT PRIVILEGES FOR ROLE csa_migrator IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO admin_api_user;


-- =============================================================
-- After this script runs successfully:
--   1. Put mobile_api_user's password into csa_mobile_api/.env
--      (DB_USER=mobile_api_user, DB_PASSWORD=...).
--   2. Put admin_api_user's password into csa_admin_api/.env
--      (DB_USER=admin_api_user, DB_PASSWORD=...).
--   3. Keep csa_migrator's password out of both .env files. Use it only
--      by hand when running, from csa_mobile_api:
--        DB_USER=csa_migrator DB_PASSWORD=... python manage.py migrate
--      (or temporarily export it in your shell, then unset it).
-- =============================================================
