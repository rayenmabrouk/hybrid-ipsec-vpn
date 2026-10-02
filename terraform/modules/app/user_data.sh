#!/bin/bash
# app-aws bootstrap: nginx test application. Internet access goes through gw-aws (NAT instance),
# which may still be booting: retry until it is ready.
set -uxo pipefail
hostnamectl set-hostname app-aws
export DEBIAN_FRONTEND=noninteractive
for i in $(seq 1 30); do apt-get update && break; sleep 10; done
apt-get install -y nginx
cat > /var/www/html/index.html <<'HTML'
<h1>AWS - application app-aws (10.20.2.10)</h1>
<p>Sous-réseau privé sans IP publique, joignable uniquement à travers le tunnel IPsec.</p>
HTML
systemctl enable --now nginx
