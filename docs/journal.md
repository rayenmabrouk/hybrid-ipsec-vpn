# Journal de réalisation

## 2026-10-01 — P0 : socle du laboratoire
- Hôte : Windows 11 Pro, Hyper-V. Commutateurs LAB-WAN (interne, 192.168.100.0/24, WinNAT) et LAB-LAN-A (privé).
- VM Ubuntu Server 26.04.1 LTS (ISO vérifiée SHA-256) : gw-onprem, gw-lab-b, client-onprem ; MAC statiques ; mémoire statique 2 Go ; checkpoints « base-installed ».
- strongSwan 6.0.4 installé sur les deux passerelles.
- Gate 1 validé : ML-KEM-512/768/1024 et ECP-384 disponibles (plugin openssl) → échange de clés hybride post-quantique possible.
- gw-onprem : ip_forward activé, NAT nftables (LAN → Internet, sauf 10.20.0.0/16 réservé au tunnel).
- Vérifié : client-onprem → gw-onprem → Internet (ping 1.1.1.1, HTTPS 200).

### Problèmes et solutions
- Une seule instance WinNAT par hôte : NAT du lab k3s supprimé.
- Installeur Ubuntu figé avec la mémoire dynamique Hyper-V : passage en mémoire statique.
- Commandes réseau refusées hors session administrateur.
