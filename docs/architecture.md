# Architektura

Repozytorium opisuje jeden homelab i jedno środowisko. Terraform tworzy VM-y,
cloud-init zapewnia pierwszy dostęp przez SSH, a Ansible konfiguruje systemy i
usługi. Granice są celowo proste.

```text
MikroTik (poza repo)
        │
        ▼
Proxmox VE + tank-zfs
        ├── jelly-01    Jellyfin
        ├── dns-01      Pi-hole
        ├── proxy-01    Traefik
        ├── app-01      Homepage, Portainer, Actual Budget, Paperless
        └── monitor-01  Nagios
```

## Odpowiedzialności

- Terraform zarządza VMID, CPU, RAM, dyskami, NIC i małym cloud-init.
- Ansible zarządza Rocky Linux, Dockerem, firewallami i Compose.
- MikroTik zarządza routingiem i DHCP poza repozytorium.
- Proxmox, fizyczne dyski i pula ZFS są przygotowywane ręcznie.
- Terraform zachowuje faktyczne położenie dysków VM, ale nie zarządza samymi
  storage'ami. Dysk danych Jellyfina jest już na `tank-zfs`; pozostałe migracje
  odbędą się później, po jednej VM.

Każda usługa ma osobną rolę oraz osobny plik Compose w `/opt/<usługa>`.
Duże dane aplikacji na `app-01` trafiają na osobny dysk pod `/srv/data`.
Jellyfin ma zwykły dodatkowy dysk VM. Nie ma NFS, virtiofs ani osobnej VM
storage.

Podczas przejęcia istniejącego homelabu flagi `deploy_*` chronią działające
stosy przed przypadkowym zastąpieniem. Usługę włącza się w nowym repo dopiero
po przeniesieniu jej Compose, wolumenów i konfiguracji. Pi-hole, Traefik,
Homepage, Portainer, Actual Budget, Paperless i Nagios zostały już przejęte; pozostałe
flagi usług pozostają wyłączone.

## Świadomie odłożone

Nie ma SOPS, S3 state, drugiego środowiska, automatycznego CI, automatyzacji
MikroTika ani przebudowy Proxmoxa. Dodajemy je wyłącznie po pojawieniu się
konkretnej potrzeby.
