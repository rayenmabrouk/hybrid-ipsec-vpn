#!/usr/bin/env bash
# Signs <dir>/<name>.csr with the lab CA unless <dir>/<name>.crt already certifies the same public
# key and is valid for at least 30 more days. Prints "signed" or "unchanged".
set -euo pipefail
dir="$1"; name="$2"
csr="$dir/$name.csr"; crt="$dir/$name.crt"

if [[ -f "$crt" ]] \
   && [[ "$(openssl req -in "$csr" -pubkey -noout)" == "$(openssl x509 -in "$crt" -pubkey -noout)" ]] \
   && openssl x509 -checkend 2592000 -noout -in "$crt" >/dev/null; then
  echo unchanged
  exit 0
fi

pki --issue --cacert "$dir/ca.crt" --cakey "$dir/ca.key" --type pkcs10 --in "$csr" \
    --lifetime 365 --digest sha384 --flag serverAuth --flag ikeIntermediate --outform pem > "$crt.new"
mv "$crt.new" "$crt"
echo signed
