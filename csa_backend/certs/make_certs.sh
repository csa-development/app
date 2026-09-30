#!/usr/bin/env bash
# Creates the internal CA + the HTTPS server certificate used by
# run_mobile_https.ps1 / run_admin_https.ps1.
#
#   bash make_certs.sh 192.168.31.58
#
# Why a private CA instead of one self-signed server cert: the phone app
# is built to trust THIS CA (ca.crt is bundled in the app). If the server
# cert has to change (new IP, expiry), re-running this reuses the same CA,
# so already-installed apps keep working — no new APK just for the cert.
#
# NEVER commit or share: ca.key (can mint certs the app will trust) and
# server.key. They are gitignored. ca.crt is public and is what gets
# copied into the Flutter app.
set -euo pipefail
export MSYS_NO_PATHCONV=1          # stop Git Bash mangling the "/O=..." subjects
cd "$(dirname "$0")"

# Use our own minimal config: some machines have OPENSSL_CONF pointing at a
# file that doesn't exist (e.g. a stale PostgreSQL ODBC install), which
# makes `openssl req` fail before doing anything.
OPENSSL_CONF="$(pwd -W 2>/dev/null || pwd)/openssl-minimal.cnf"   # native path: this openssl is a Windows build
export OPENSSL_CONF
printf '[req]
distinguished_name=dn
prompt=no
[dn]
CN=placeholder
' > "$OPENSSL_CONF"
trap 'rm -f "$OPENSSL_CONF"' EXIT

LAN_IP="${1:?usage: bash make_certs.sh <lan-ip>   e.g. 192.168.31.58}"

if [ ! -f ca.key ] || [ ! -f ca.crt ]; then
  echo "Creating new CA (10 years)..."
  openssl genrsa -out ca.key 4096
  openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
    -subj "/O=CSA Ghana (internal)/CN=CSA Internal Dev CA" \
    -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -out ca.crt
else
  echo "Reusing existing CA."
fi

echo "Issuing server certificate for $LAN_IP (397 days)..."
openssl genrsa -out server.key 2048
openssl req -new -key server.key -subj "/O=CSA Ghana (internal)/CN=$LAN_IP" -out server.csr
cat > server.ext <<EXT
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=IP:$LAN_IP,IP:127.0.0.1,IP:10.0.2.2,DNS:localhost
EXT
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 397 -sha256 -extfile server.ext
rm -f server.csr server.ext

echo
openssl x509 -in server.crt -noout -subject -enddate -ext subjectAltName
