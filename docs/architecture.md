# Architektura

Repozytorium opisuje jeden homelab i jedno środowisko. Terraform tworzy VM-y,
cloud-init zapewnia pierwszy dostęp przez SSH, a Ansible konfiguruje systemy i
usługi. Granice są celowo proste.

```text
MikroTik (poza repo)
        │
        ▼
Proxmox VE + tank-zfs
        ├── dns-01      Pi-hole
        ├── proxy-01    Traefik
        ├── app-01      Homepage, Portainer, Paperless
        ├── jelly-01    Jellyfin i automatyzacja mediów
        ├── monitor-01  Nagios, Prometheus, Grafana, eksportery centralne
        ├── homeassistant-01  Home Assistant OS + ZHA → SMLIGHT po LAN
        └── k8s-cp1, k8s-w1, k8s-w2  Klaster Kubernetes do nauki
```

To jest pełny bieżący zestaw VM. `public-01`, poprzedni
`homeassistant-01` i `puppet-01` zostały usunięte wraz z dyskami. Home Assistant
został następnie odtworzony od zera z oficjalnego obrazu HAOS.
VMID `9000` pozostaje szablonem Rocky Linux do tworzenia nowych hostów.

## Odpowiedzialności

- Terraform zarządza VMID, CPU, RAM, dyskami, NIC i małym cloud-init.
- Ansible zarządza Rocky Linux, Dockerem, firewallami i Compose.
- MikroTik zarządza routingiem i DHCP poza repozytorium.
- Proxmox, fizyczne dyski i pula ZFS są przygotowywane ręcznie.
- Terraform umieszcza dyski VM na przygotowanym ręcznie `tank-zfs`, ale nie
  tworzy ani nie przebudowuje samej puli.

Każda usługa ma osobną rolę oraz osobny plik Compose w `/opt/<usługa>`.
Duże dane aplikacji na `app-01` trafiają na osobny dysk pod `/srv/data`.
Rola `app_storage` formatuje wyłącznie jawnie wskazany, całkowicie pusty dysk
`scsi1`; istniejący nieznany filesystem zatrzymuje wdrożenie. Montowanie odbywa
się po UUID. Nie ma NFS, virtiofs ani osobnej VM storage.

Świeże VM odtwarzają wyłącznie usługi jawnie opisane w rolach: Pi-hole,
Traefik, Homepage, Portainer, Paperless, media, Nagios i monitoring.
Stare, niezarządzane stosy
nie są kopiowane ani uruchamiane ponownie.

## Świadomie odłożone

Nie ma SOPS, S3 state, drugiego środowiska, automatycznego CI, automatyzacji
MikroTika ani przebudowy Proxmoxa. Dodajemy je wyłącznie po pojawieniu się
konkretnej potrzeby.
