-- Token blacklist (rest_framework_simplejwt.token_blacklist) grants.
--
-- Run AFTER the migration below has created the tables, and as
-- csa_migrator (or any superuser) — never as a runtime role:
--
--   1) from csa_backend/csa_mobile_api, as csa_migrator:
--        $env:DB_USER='csa_migrator'; $env:DB_PASSWORD='<migrator password>'
--        $env:ENABLE_TOKEN_BLACKLIST='True'
--        python manage.py migrate token_blacklist
--   2) psql -U csa_migrator -d csa_db -f db_setup/02_token_blacklist_grants.sql
--
-- (Migrate from csa_mobile_api, not csa_admin_api: the admin process is
-- deliberately not allowed to run migrations.)
--
-- Least privilege: both processes only ever need to READ and INSERT.
--   * OutstandingToken row  -> written when a refresh token is issued
--   * BlacklistedToken row  -> written on logout / rotation / revocation
-- Nothing at runtime UPDATEs or DELETEs them. Clearing out expired
-- tokens is a maintenance job for csa_migrator:
--   python manage.py flushexpiredtokens

GRANT SELECT, INSERT ON token_blacklist_outstandingtoken TO mobile_api_user;
GRANT SELECT, INSERT ON token_blacklist_blacklistedtoken TO mobile_api_user;

GRANT SELECT, INSERT ON token_blacklist_outstandingtoken TO admin_api_user;
GRANT SELECT, INSERT ON token_blacklist_blacklistedtoken TO admin_api_user;

-- The id columns are GENERATED ... AS IDENTITY, whose counter Postgres
-- covers under the table's INSERT privilege, so these sequence grants
-- should be redundant. Kept as belt-and-braces (and for a future switch
-- to serial columns); harmless if the sequence names ever differ.
GRANT USAGE, SELECT ON SEQUENCE token_blacklist_outstandingtoken_id_seq TO mobile_api_user;
GRANT USAGE, SELECT ON SEQUENCE token_blacklist_blacklistedtoken_id_seq TO mobile_api_user;
GRANT USAGE, SELECT ON SEQUENCE token_blacklist_outstandingtoken_id_seq TO admin_api_user;
GRANT USAGE, SELECT ON SEQUENCE token_blacklist_blacklistedtoken_id_seq TO admin_api_user;
