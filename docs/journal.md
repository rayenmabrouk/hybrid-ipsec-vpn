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

## 2026-10-02 — Gate 2 : faisabilité AWS
- Sauvegardes : dépôt poussé sur GitHub (privé) ; CA chiffrée (AES-256, gpg) hors du poste.
- AWS Academy Learner Lab, us-east-1 : AMI officielle Ubuntu 26.04 disponible (paramètre SSM Canonical).
- Test UDP : instance éphémère (écho socat sur UDP 500/4500, groupe de sécurité limité à l'IP publique du site) ; depuis gw-onprem, à travers WinNAT et le NAT du FAI, les deux ports répondent → IKE et NAT-T possibles.
- Agent SSM « Online » sur Ubuntu 26.04 avec LabInstanceProfile → administration sans port SSH.
- Ressources de test supprimées immédiatement.

## 2026-10-02 — P2 : infrastructure AWS (Terraform) et tunnel hybride
- Bootstrap (scripts/bootstrap-aws.sh) : buckets S3 d'état Terraform (versionné, chiffré, privé, verrouillage natif use_lockfile) et des Flow Logs.
- Terraform (AWS provider 6.x) : 4 modules network / gateway / app / monitoring, 30 ressources ; aucune création de rôle IAM (LabInstanceProfile).
- gw-aws : EIP, source/dest check désactivé, IMDSv2, disque chiffré, aucun port SSH, administration via SSM ; instance NAT pour le sous-réseau privé (cloud-init).
- app-aws : sous-réseau privé sans IP publique ; HTTP/ICMP autorisés uniquement depuis 10.10.0.0/24 ; nginx installé via le NAT de gw-aws.
- PKI : clé de gw-aws générée sur l'instance ; CSR et certificat échangés par SSM Run Command.
- gw-onprem bascule de gw-lab-b vers gw-aws (config du labo conservée dans /etc/swanctl/lab pour le mode démo hors ligne).
- Résultat : IKE_SA ESTABLISHED ECP_384/KE1_ML_KEM_768, CHILD_SA TUNNEL-in-UDP (NAT-T à travers WinNAT + NAT FAI) ; client-onprem → app-aws : 0 % de perte, page servie, TTL 62 (2 passerelles).

### Problèmes et solutions
- aws_s3_bucket : refus SCP Learner Lab sur s3:GetBucketObjectLockConfiguration → bucket des Flow Logs créé hors Terraform (bootstrap).
- Ancienne instance d'un autre projet relancée automatiquement à chaque session (coût) → détruite proprement par son propre Terraform.
- .gitignore sans saut de ligne final → backend.hcl indexé ; corrigé avant commit.

## 2026-10-02 — P3 : automatisation Ansible
- Contrôleur : WSL, ansible-core 2.21 (pipx) + boto3, collection amazon.aws 11.4.
- Inventaire hybride : statique (VM on-prem, SSH) + dynamique aws_ec2 (instances découvertes par tags, connexion SSM via un bucket S3 de transfert, sans port SSH).
- Rôles : common (forwarding, NAT nftables validé par nft -c), strongswan (paquets, connexion swanctl générée par template), pki (clé générée sur la passerelle, CSR → CA hors ligne, signature seulement si certificat absent, expirant ou émis pour une autre clé), labsite (site distant simulé).
- Une variable choisit le site distant : vpn_remote_site=aws (défaut) ou lab (démonstration hors ligne).
- Vérification intégrée : SA établie + application atteinte depuis client-onprem.
- Idempotence prouvée : deuxième exécution changed=0 sur les 4 hôtes.

### Problèmes et solutions
- Ubuntu 26.04 utilise sudo-rs par défaut ; Ansible ne reconnaît pas son invite → ansible_become_exe: sudo.ws (sudo historique fourni par Ubuntu).
- Rechargement d'une configuration inchangée : start_action non relancé → le handler initie explicitement la CHILD_SA côté initiateur.
- CSR différente à chaque exécution (signature ECDSA aléatoire) → tâche marquée sans changement ; la clé reste identique.

## 2026-10-02 — Test T10 : reproductibilité
- scripts/destroy.sh (25 ressources supprimées) puis `time scripts/deploy.sh -K`.
- Reconstruction complète sans action manuelle : 5 min 26 s (Terraform 92 s ; SSM en ligne à 96 s ; Ansible ≈ 230 s).
- Nouvelle clé de gw-aws générée sur l'instance, certificat signé automatiquement (clé différente détectée), nouvelle EIP prise en compte par gw-onprem, tunnel ECP_384/KE1_ML_KEM_768 rétabli, application servie à client-onprem.
- Incident corrigé : la normalisation des droits (chmod 644 récursif) avait retiré le bit exécutable du provider dans terraform/.terraform → réinitialisation.

## 2026-10-02 — P4 : supervision
- gw-aws : script Python (boto3, rôle d'instance, IMDSv2) publiant VPN/TunnelUp chaque minute (timer systemd) → alarme CloudWatch (Terraform) : < 1 ou absence de donnée pendant 2 min → SNS e-mail.
- gw-onprem : node_exporter écoutant uniquement côté LAN (10.10.0.1:9100) + collecteur textfile (vpn_tunnel_up, vpn_pq_hybrid, vpn_child_sa_bytes_total) toutes les 15 s.
- client-onprem : Prometheus + Grafana (dépôt APT signé), source de données et tableau de bord « VPN IPsec hybride » provisionnés par Ansible ; accès par tunnel SSH (port 3000 non exposé).
- Vérifié : métrique CloudWatch = 1 chaque minute, alarme OK ; tableau de bord UP / ECP-384 + ML-KEM-768 / débit ESP.

### Problèmes et solutions
- ansible_managed n'est plus défini hors des templates (ansible-core 2.21) → commentaire statique.
- Mot de passe Grafana contenant des espaces découpé en plusieurs arguments → module command en argv.
- Handlers non exécutés après l'échec d'une tâche → Prometheus gardait sa configuration par défaut ; corrigé par force_handlers = True.

## T5 — Panne de la passerelle AWS et reprise automatique (02/10/2026)

**Protocole** : `tests/t5-failover.sh <durée>` lance un ping 1/s de client-onprem vers app-aws (10.20.2.10), arrête strongSwan sur gw-aws via SSM, attend la durée choisie, le redémarre, puis mesure l'interruption à partir des horodatages du ping (`tests/results/t5-ping.log`).

| | Essai 1 | Essai 2 |
|---|---|---|
| Durée de la panne | ~330 s | 180 s |
| Interruption totale du trafic | 331,8 s | 213,9 s (10:24:07 → 10:27:41) |
| Reprise après redémarrage | 65,7 s | ≈ 34 s |
| Courriel ALARM (SNS) | — | 10:27:33 |
| Courriel OK (SNS) | — | 10:29:33 |

**Constats**
- Le tunnel se rétablit sans intervention : gw-onprem (initiateur) relance la négociation IKE jusqu'au retour du pair.
- Le délai de reprise dépend de la durée de la panne, car les retransmissions IKE suivent un backoff exponentiel. Plus la panne est longue, plus le prochain essai est espacé.
- La chaîne d'alerte fonctionne de bout en bout : métrique `VPN/TunnelUp` → alarme CloudWatch → SNS → courriel, dans les deux sens (ALARM puis OK).

**Correctif apporté** : par défaut `keyingtries = 1`, si bien qu'après une panne longue l'initiateur abandonnait. Il passe à `keyingtries = 0` (essais illimités) côté initiateur dans le rôle `strongswan`.

**Seule étape manuelle restante** : après une reconstruction complète (T10), le topic SNS est recréé, donc l'abonnement courriel doit être reconfirmé (lien reçu par courriel). Ce comportement est imposé par AWS et ne peut pas être automatisé.

## Tests de sécurité T8, T6, T11, T9, T1 (02/10/2026)

### T8 — Tentative de négociation affaiblie (downgrade)
gw-onprem propose à gw-aws une suite classique et faible : `aes128-sha256-modp2048`, sans ML-KEM (`tests/configs/t8-downgrade.conf`).
**Résultat** : gw-aws répond dès IKE_SA_INIT par `N(NO_PROP)` (36 octets), puis `received NO_PROPOSAL_CHOSEN notify error`. Aucune authentification n'est tentée. Le tunnel de production reste ESTABLISHED.
**Conclusion** : un attaquant ne peut pas forcer un repli vers la cryptographie classique (ANSSI R4/R8).

### T6 — Usurpation avec un certificat d'une autre AC
Une AC « Rogue Root CA » (ECDSA P-384), créée hors de la PKI du projet, émet un certificat portant exactement l'identité `gw-onprem.vpn.internal`. gw-onprem s'authentifie avec ce certificat et les propositions hybrides légitimes (`tests/configs/t6-rogue-ca.conf`).
**Résultat** : l'échange hybride ECP-384 + ML-KEM-768 aboutit, mais gw-aws renvoie `N(AUTH_FAILED)`. Son journal indique `no issuer certificate found` / `issuer is "C=TN, O=Rogue CA, CN=Rogue Root CA"` : aucune chaîne de confiance vers « Hybrid IPsec VPN Root CA ».
**Conclusion** : l'échange de clés post-quantique protège la confidentialité, la PKI protège l'authentification. Les deux couches sont indépendantes. Les clés et l'AC de test ont été supprimées de gw-onprem.

### T11 — Échange hybride visible (RFC 9370 / RFC 9242)
Dans la trace de T6, on voit IKE_SA_INIT (ECP-384, 312 octets), puis `IKE_INTERMEDIATE request 1 [ KE ]` portant la clé ML-KEM-768 (1249 octets, fragmentés en `EF(1/2)` et `EF(2/2)` selon la RFC 7383), puis IKE_AUTH. La suite négociée est `AES_GCM_16_256/PRF_HMAC_SHA2_384/ECP_384/KE1_ML_KEM_768`.

### T9 — Surface d'exposition de l'EIP
- nmap TCP (1000 ports) : tous `filtered`. Aucun service exposé ; l'administration passe exclusivement par SSM.
- nmap UDP : `open|filtered` partout, donc non concluant (nmap ne distingue pas un rejet silencieux d'un service muet).
- Preuve par les VPC Flow Logs (S3), source = IP publique du site : `tcp/* REJECT` (1997 enregistrements) ; `udp/53`, `udp/123`, `udp/161` REJECT ; `udp/500` et `udp/4500` ACCEPT.
- Security Group : seuls UDP 500 et 4500 depuis l'IP publique du site en /32, plus tout le trafic du sous-réseau privé 10.20.2.0/24.

### T1 — Confidentialité sur le WAN
- tcpdump sur gw-onprem : en clair sur eth1 (LAN, ICMP et HTTP), uniquement `UDP-encap: ESP(spi=…)` en sortie sur eth0 (WAN).
- Piège identifié : tcpdump sur eth0 affiche aussi les paquets *entrants* déchiffrés. Ils ont le même horodatage que le paquet ESP qui les précède et le même numéro de séquence. C'est la réinjection du noyau après traitement XFRM, pas une fuite sur le fil.
- Preuve sur le fil : Wireshark sur l'hôte, interface `vEthernet (LAB-WAN)`, donc hors de la VM. Le filtre `icmp || http` ne renvoie rien. Tous les paquets sont `eth:ip:udp:udpencap:esp`, avec les SPI 0xcbabfee6 / 0xc4097dca, identiques à ceux journalisés par gw-aws pour `lan{3}`.

## Incident — Remappage NAT après redémarrage de l'hôte (02/10/2026, ~11:08)
- **Cause** : le PC hôte a redémarré. Hyper-V a sauvegardé puis restauré les VM, donc la session IKE a été conservée côté gw-onprem, mais WinNAT a été reconstruit. Le flux UDP 4500 est sorti par un nouveau port externe (50852 → 59174).
- **Déroulement** : gw-aws avait une requête DPD en cours (ID 29) et l'a retransmise vers l'ancien port. gw-onprem a détecté le changement de NAT et envoyé une mise à jour MOBIKE (`UPD_SA_ADDR`), que gw-aws a appliquée (« remote endpoint changed »). Mais strongSwan retransmet le paquet d'origine tel quel : la requête 29 est restée sans réponse, et à 11:10:20 gw-aws a supprimé l'IKE_SA (`dpd_action = clear`). gw-onprem a ensuite sondé une SA inexistante (retransmissions visibles dans Wireshark), puis a reconstruit le tunnel à 11:13:05 (`dpd_action = restart`), toujours en mode hybride.
- **Impact** : environ 3 min d'interruption, reprise sans intervention humaine.
- **Piste d'amélioration** : réduire le délai de détection (`charon.retransmit_timeout` et `charon.retransmit_tries`), au prix de plus de sensibilité aux pertes ponctuelles.
