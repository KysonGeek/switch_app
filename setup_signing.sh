#!/bin/bash
# Create a local self-signed code-signing certificate so rebuilds keep a stable
# Designated Requirement (and therefore keep the Accessibility permission).
#
# Safe & local-only: the cert never leaves this Mac and can be deleted anytime
# from Keychain Access (search for the name below) or with:
#   security delete-certificate -c "WindowSwitcher Local Signing"
set -euo pipefail
cd "$(dirname "$0")"

IDENTITY="WindowSwitcher Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$IDENTITY" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "✓ Signing identity already exists: \"$IDENTITY\""
  exit 0
fi

echo "▸ Generating self-signed code-signing certificate…"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions    = v3
prompt             = no
[dn]
CN = $IDENTITY
[v3]
basicConstraints   = critical, CA:false
keyUsage           = critical, digitalSignature
extendedKeyUsage   = critical, codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
  -config "$TMP/openssl.cnf" >/dev/null 2>&1

# A transient password + `-legacy` are required for Apple's `security` to read
# the PKCS#12 (OpenSSL 3 defaults to a MAC/cipher macOS can't import, and
# empty-password p12 files fail MAC verification on import).
PW="wslocal"
openssl pkcs12 -export -legacy \
  -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -name "$IDENTITY" -out "$TMP/identity.p12" -passout "pass:$PW" >/dev/null 2>&1

echo "▸ Importing into login keychain (pre-authorizing codesign)…"
# -T pre-authorizes codesign on the private key's ACL so builds don't prompt.
security import "$TMP/identity.p12" -k "$KEYCHAIN" -P "$PW" \
  -T /usr/bin/codesign >/dev/null

echo "✓ Created signing identity: \"$IDENTITY\""
echo "  Now run ./build_app.sh — it uses this identity automatically."
echo "  (No trust step needed: codesign signs by name, and the stable"
echo "   Designated Requirement keeps your Accessibility permission on rebuilds.)"
