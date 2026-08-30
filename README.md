# homelab-iac

Proste Infrastructure as Code dla pojedynczego hosta Proxmox. Terraform tworzy
VM-y, mały cloud-init zapewnia pierwszy dostęp, a Ansible konfiguruje Rocky Linux
i wdraża każdą usługę z osobnego Docker Compose.

## Zakres MVP

| Host | IP | Rola |
|---|---|---|
| `jelly-01` | `192.168.60.131` | Jellyfin |
| `dns-01` | `192.168.60.141` | Pi-hole |
| `proxy-01` | `192.168.60.142` | Traefik |
| `app-01` | `192.168.60.143` | aplikacje; na start Portainer |
| `monitor-01` | `192.168.60.144` | Nagios |

Na etapie przejęcia repo opisuje faktyczne położenie dysków: systemowe na
`local-lvm`, część danych nadal na `datav1`, a dysk danych Jellyfina już na
`tank-zfs`. Dalsza migracja będzie wykonywana po jednej VM i po sprawdzeniu
backupu. MikroTik i konfiguracja hosta Proxmox pozostają poza automatyzacją.

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
make check      # waliduje Terraform i składnię Ansible
```

Pi-hole, Traefik, Homepage i Nagios są zarządzane przez nowe repo. Istniejące
stosy Jellyfin oraz pozostałe aplikacje nie są jeszcze automatycznie
przejmowane. Odpowiadające im flagi `deploy_*` w
`ansible/inventory/group_vars/all/main.yml` pozostają wyłączone do czasu
sprawdzenia i przeniesienia ich obecnych plików Compose oraz danych.

Po każdym udanym `make apply` wykonaj zaszyfrowaną kopię lokalnego
`terraform/prod/terraform.tfstate` poza tym hostem i poza Git.

## Dokumentacja

- [Architektura](docs/architecture.md)
- [Sieć](docs/network.md)
- [Backup](docs/backup.md)
- [Rebuild](docs/rebuild.md)

## Zasady bezpieczeństwa

- `terraform apply` może usunąć VM-y; zawsze sprawdzaj plan.
- Ansible nigdy nie formatuje istniejącego, nieznanego filesystemu.
- Terraform nie tworzy ani nie przebudowuje storage'u `datav1`; tylko zachowuje
  istniejące dyski VM do czasu ich osobnej migracji.
- Pierwszy test rebuilda wykonaj na niekrytycznej VM.
- Pi-hole nie jest wymagany do bootstrapu nowych hostów.
