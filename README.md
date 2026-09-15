# homelab-iac

Proste Infrastructure as Code dla pojedynczego hosta Proxmox. Terraform tworzy
VM-y, mały cloud-init zapewnia pierwszy dostęp, a Ansible konfiguruje Rocky Linux
i wdraża każdą usługę z osobnego Docker Compose.

## Zakres MVP

| VMID | Host | IP | Rola |
|---:|---|---|---|
| 141 | `dns-01` | `192.168.60.141` | Pi-hole |
| 142 | `proxy-01` | `192.168.60.142` | Traefik |
| 143 | `app-01` | `192.168.60.143` | Homepage, Portainer, Paperless |
| 131 | `jelly-01` | `192.168.60.131` | Media stack (Jellyfin, Seerr, Servarr) |
| 144 | `monitor-01` (`monitoring-01` w Proxmox) | `192.168.60.144` | Nagios, Prometheus, Grafana |
| 147 | `homeassistant-01` | `192.168.60.147` | Home Assistant OS, ZHA |
| 151 | `k8s-cp1` | `192.168.60.151` | Kubernetes control plane |
| 152 | `k8s-w1` | `192.168.60.152` | Kubernetes worker |
| 153 | `k8s-w2` | `192.168.60.153` | Kubernetes worker |

To jest cały aktywny zestaw VM zarządzany przez repo. Szablon Rocky Linux ma
VMID `9000`. Stare VM-y `public-01` (145), poprzedni `homeassistant-01` (147)
i `puppet-01` (148) zostały świadomie usunięte 31 sierpnia 2026 wraz z dyskami.
Home Assistant wrócił jako świeża, deklaratywna instalacja HAOS.

Klaster Kubernetes do nauki to trzy Rocky Linux VM-y na `tank-zfs`: `k8s-cp1`,
`k8s-w1` i `k8s-w2`. Każda ma 2 vCPU, 4 GiB RAM bez ballooningu oraz dysk
systemowy 32 GiB. Repo tworzy infrastrukturę; instalacja Kubernetes pozostaje
osobnym krokiem.

Wszystkie dyski świeżych VM znajdują się na `tank-zfs`. MikroTik i konfiguracja
hosta Proxmox pozostają poza automatyzacją.

## Struktura

```text
homelab-iac/
├── README.md
├── Makefile
├── docs/
│   ├── architecture.md
│   ├── network.md
│   ├── backup.md
│   └── rebuild.md
├── terraform/
│   ├── modules/vm/
│   └── prod/
└── ansible/
    ├── ansible.cfg
    ├── inventory/hosts.yml
    ├── inventory/group_vars/all/
    ├── playbooks/
    │   ├── bootstrap.yml
    │   └── site.yml
    └── roles/
```

## Wymagania

- Terraform 1.6 lub nowszy,
- Ansible,
- kolekcje z `ansible/requirements.yml`,
- Proxmox z `tank-zfs`, bridge `vmbr0` i template Rocky Linux VMID `9000`,
- token API Proxmox,
- klucz SSH operatora.

## Pierwsze uruchomienie

Przygotuj lokalne dane Terraform:

```bash
cp terraform/prod/terraform.tfvars.example terraform/prod/terraform.tfvars
$EDITOR terraform/prod/terraform.tfvars
make init
make plan
```

Przeczytaj cały plan. Dopiero potem:

```bash
make apply
```

Przygotuj Ansible Vault. Plik `.vault_pass` i hasło nigdy nie trafiają do Git:

```bash
install -m 600 /dev/null ansible/.vault_pass
$EDITOR ansible/.vault_pass
make vault-init
```

W nowym `vault.yml` dodaj klucze z
`ansible/inventory/group_vars/all/vault.yml.example`, następnie:

```bash
make deps
make ping
make users
make bootstrap
make site
```

Zaszyfrowany `ansible/inventory/group_vars/all/vault.yml` powinien być zapisany w Git. Jego
hasło powinno mieć co najmniej dwie niezależne kopie, na przykład w menedżerze
haseł i offline.

## Codzienna obsługa

```bash
make plan       # zawsze przed zmianami VM
make apply      # używa planu zapisanego przez poprzednie polecenie
make site       # doprowadza systemy i usługi do oczekiwanego stanu
make users      # utwórz lub zaktualizuj konta administracyjne na wszystkich hostach
make check      # waliduje Terraform i składnię Ansible
```

Pi-hole, Traefik, Homepage, Portainer, Paperless, Nagios oraz modułowy
stack Prometheus + Grafana i media stack na
`jelly-01` (Jellyfin, Seerr, Sonarr, Radarr, Prowlarr, Bazarr, FlareSolverr,
Gluetun + qBittorrent przez VPN WireGuard) są zarządzane przez nowe repo.
Passthrough GPU `legacy-IGD` jest skonfigurowany jednorazowo przez `qm`
na hoście Proxmox, poza Terraformem.
Stary Seafile również został usunięty i wróci jako świeże wdrożenie na
`tank-zfs`. Stare, niezarządzane kontenery nie są odtwarzane na świeżych VM.

Po każdym udanym `make apply` wykonaj zaszyfrowaną kopię lokalnego
`terraform/prod/terraform.tfstate` poza tym hostem i poza Git.

## Dokumentacja

- [Plan rozwoju i lista zadań](docs/roadmap.md)
- [Architektura](docs/architecture.md)
- [Sieć](docs/network.md)
- [Monitoring: Grafana, Prometheus i eksportery](docs/monitoring.md)
- [Home Assistant OS i SMLIGHT](docs/home-assistant.md)
- [Backup](docs/backup.md)
- [Rebuild](docs/rebuild.md)
- [Notatki do świeżego media stacku](docs/jellyfin-rebuild-notes.md)
- [Media stack — pozostałe kroki](docs/media-stack-todo.md)
- [Notatki do świeżego Seafile](docs/seafile-rebuild-notes.md)

## Zasady bezpieczeństwa

- `terraform apply` może usunąć VM-y; zawsze sprawdzaj plan.
- Ansible nigdy nie formatuje istniejącego, nieznanego filesystemu.
- `dataV1` pozostaje poza aktywną konfiguracją Terraform.
- Pierwszy test rebuilda wykonaj na niekrytycznej VM.
- Pi-hole nie jest wymagany do bootstrapu nowych hostów.
