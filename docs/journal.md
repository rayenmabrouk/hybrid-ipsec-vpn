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

## 2026-10-01 — P1 : PKI et tunnel IKEv2 post-quantique (laboratoire local)
- Poste d'administration : WSL Ubuntu 24.04 (accès direct au réseau Hyper-V), clé SSH dédiée, ProxyJump vers client-onprem.
- PKI : CA racine ECDSA P-384 hors ligne sur le poste d'admin ; chaque passerelle génère sa clé privée (jamais exportée) et une CSR ; certificats 1 an (serverAuth, ikeIntermediate), identités *.vpn.internal.
- gw-lab-b simule le site distant : interface dummy0 10.20.2.10/32 + nginx.
- swanctl : IKE aes256gcm16-prfsha384-ecp384-ke1_mlkem768 ; ESP aes256gcm16-ecp384-ke1_mlkem768 ; DPD 30 s ; gw-onprem initiateur (start/restart).
- Résultat : IKE_SA ESTABLISHED (ECP_384 + KE1_ML_KEM_768), CHILD_SA INSTALLED 10.10.0.0/24 ↔ 10.20.0.0/16 ; client-onprem → 10.20.2.10 : ping 0 % perte, HTTP OK ; compteurs ESP non nuls.

### Observations
- IKE bascule sur UDP 4500 sans NAT : effet de MOBIKE (RFC 4555).
- La première CHILD_SA n'effectue pas d'échange de clés propre ; PFS hybride à chaque rekey (à démontrer en T11).
- Avertissements « agent plugin » et « TPM 2.0 » sans impact (pas d'agent SSH ni de vTPM utilisés).
