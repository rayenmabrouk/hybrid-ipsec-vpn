#!/usr/bin/env bash
# Generates the gateway private key (kept on the gateway) and a CSR for the lab CA.
# Usage: sudo ./gen-csr.sh <hostname>   -> writes /tmp/<hostname>.csr
set -euo pipefail
name="${1:?usage: gen-csr.sh <hostname>}"
key="/etc/swanctl/private/${name}.key"
umask 077
[ -f "$key" ] || pki --gen --type ecdsa --size 384 --outform pem > "$key"
pki --req --type priv --in "$key" \
    --dn "C=TN, O=Hybrid IPsec VPN, CN=${name}.vpn.internal" \
    --san "${name}.vpn.internal" --digest sha384 --outform pem > "/tmp/${name}.csr"
chmod 644 "/tmp/${name}.csr"
echo "OK: key ${key}, CSR /tmp/${name}.csr"
