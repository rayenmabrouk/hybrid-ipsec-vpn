#!/usr/bin/env bash
# Writes IPsec tunnel metrics for the node_exporter textfile collector (atomic write).
set -euo pipefail
dir=/var/lib/prometheus/node-exporter
host=$(hostname)
sas=$(swanctl --list-sas --ike site-to-site 2>/dev/null || true)

up=0
if grep -q ESTABLISHED <<<"$sas" && grep -q INSTALLED <<<"$sas"; then up=1; fi
pq=0
if grep -q KE1_ML_KEM <<<"$sas"; then pq=1; fi
if [ "$up" -eq 0 ]; then pq=-1; fi
bytes_in=$(awk '$1=="in"  {gsub(",",""); print $3; exit}' <<<"$sas"); bytes_in=${bytes_in:-0}
bytes_out=$(awk '$1=="out" {gsub(",",""); print $3; exit}' <<<"$sas"); bytes_out=${bytes_out:-0}

cat > "$dir/vpn.prom.$$" <<PROM
# HELP vpn_tunnel_up 1 if the IKE_SA is established and the CHILD_SA installed.
# TYPE vpn_tunnel_up gauge
vpn_tunnel_up{gateway="$host"} $up
# HELP vpn_pq_hybrid 1 if the IKE_SA uses the hybrid ML-KEM key exchange, 0 if classical, -1 if no tunnel.
# TYPE vpn_pq_hybrid gauge
vpn_pq_hybrid{gateway="$host"} $pq
# HELP vpn_child_sa_bytes_total ESP bytes of the current CHILD_SA (resets on rekey).
# TYPE vpn_child_sa_bytes_total counter
vpn_child_sa_bytes_total{gateway="$host",direction="in"} $bytes_in
vpn_child_sa_bytes_total{gateway="$host",direction="out"} $bytes_out
PROM
mv "$dir/vpn.prom.$$" "$dir/vpn.prom"
