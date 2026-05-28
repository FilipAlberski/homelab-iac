# homelab-iac

Repozytorium do zarządzania homelabem na Proxmoxie. Terraform tworzy VMki z cloud-init template'u, Ansible je konfiguruje. Wszystko przez `make`.

## Co tu jest

- **Terraform** — definicje VMek na Proxmoxie (`bpg/proxmox`, cloud-init)
- **Ansible** — konfiguracja systemów i deploy aplikacji (17 ról)
- **Makefile** — jeden entrypoint do wszystkiego

## Struktura

```
terraform/
  modules/vm/                 moduł VM (bpg/proxmox, cloud-init)
  environments/prod/          produkcyjne VMki (DNS, proxy, apps, monitoring, storage, CI/CD)
  environments/lab/           labowe VMki (CKA, kubernetes, testy)
ansible/
  inventories/prod/           inventory generowane z Terraforma
  inventories/lab/
  playbooks/                  playbooki do deployu usług
  roles/                      17 ról (docker, pihole, traefik, monitoring, itp.)
Makefile                      wrapper na terraform + ansible
```

## Schemat numeracji VMID

| Zakres    | Przeznaczenie              |
|-----------|----------------------------|
| 100-119   | AI / asystenci             |
| 120-139   | Media                      |
| 140-159   | Sieć / infrastruktura      |
| 160-179   | Storage / backup           |
| 180-199   | Dev / sandbox              |
| 200-219   | Kubernetes                 |
| 9000+     | Templatey                  |

IP = `192.168.40.{VMID}` (VMID ≤ 219).

## Storage

| Datastore   | Po co                                      |
|-------------|--------------------------------------------|
| `local`     | ISO + cloud-init snippets                  |
| `local-lvm` | Dyski systemowe / boot                     |
| `datav1`    | Duże wolumeny (media, modele, dane usług)  |
| `storage-01`| (nieskonfigurowany — nieużywany)           |
| `vm-backups`| Backup PBS / vzdump                        |

## Szybki start

```bash
# 1. Wypełnij secrets (plik jest gitignored)
cp terraform/environments/prod/terraform.tfvars.example \
   terraform/environments/prod/terraform.tfvars
$EDITOR terraform/environments/prod/terraform.tfvars

# 2. Stwórz VMki
make init
make plan
make apply

# 3. Wygeneruj inventory i sprawdź czy działa
make inventory
make ping

# 4. Aktualizacje
make update              # normalna aktualizacja
make update-check        # dry-run
```

`make up` robi apply → inventory → ping w jednym.

## Dwa środowiska

Domyślnie wszystko działa na `prod`. Żeby przełączyć na lab:

```bash
make ENV=lab plan
make ENV=lab apply
make ENV=lab inventory
make ENV=lab ping
```

- **prod** — infrastruktura: DNS, proxy, aplikacje, monitoring, storage, CI/CD. Nie ruszać.
- **lab** — jednorazowe VMki, kubernetes, CKA, testy. Można niszczyć i odtwarzać.

Oba środowiska siedzą na tym samym Proxmoxie, ale mają **oddzielny stan Terraforma**.

## Dodawanie nowej VMki

Edytuj odpowiedni `locals.tf`:
- Prod: `terraform/environments/prod/locals.tf`
- Lab: `terraform/environments/lab/locals.tf`

Dodaj entry do `local.vms`:

```hcl
jellyfin-01 = {
  vm_id              = 121
  cpu_cores          = 4
  memory_mb          = 8192
  memory_floating_mb = 2048
  disks = [
    { datastore_id = "local-lvm", size = 30, interface = "scsi0" },
    { datastore_id = "datav1",    size = 500, interface = "scsi1" },
  ]
  tags = ["terraform", "media"]
}
```

Potem: `make plan && make apply && make inventory`.

## Aktualne VMki

### Prod

| Nazwa        | VMID | IP             | CPU | RAM   | Dysk OS   | Dysk danych | Tagi                                |
|--------------|------|----------------|-----|-------|-----------|-------------|-------------------------------------|
| assistant-01 | 101  | .40.101        | 4   | 16 GB | 50 GB     | —           | ai, assistant                       |
| dns-01       | 141  | .40.141        | 2   | 2 GB  | 30 GB     | —           | network, dns                        |
| proxy-01     | 142  | .40.142        | 2   | 2 GB  | 30 GB     | —           | network, proxy, docker              |
| app-01       | 143  | .40.143        | 2   | 12 GB | 30 GB     | datav1 200G | apps, docker, seafile               |
| monitor-01   | 145  | .40.145        | 4   | 8 GB  | 50 GB     | datav1 100G | infra, monitoring, docker           |
| storage-01   | 160  | .40.160        | 2   | 4 GB  | 30 GB     | datav1 200G | storage, docker                     |
| gitlab-01    | 181  | .40.181        | 4   | 12 GB | 50 GB     | datav1 100G | dev, gitlab, docker                 |
| db-01        | 184  | .40.184        | 2   | 4 GB  | 30 GB     | datav1 50G  | database, docker                    |

### Lab

_(brak zdefiniowanych VMek)_

## Makefile targets

```
make help              pokaż wszystkie targety
make init              terraform init
make plan              terraform plan
make apply             terraform apply
make destroy           terraform destroy (UWAGA — niszczy VMki)
make fmt               terraform fmt -recursive
make validate          terraform validate
make output            terraform output
make inventory         generuj inventory z terraform output
make ping              ansible ping wszystkich hostów
make update            aktualizacja OS + reboot jeśli potrzeba
make update-check      dry-run aktualizacji
make resize            LVM growpart na wszystkich VMkach
make dns               deploy Pi-hole na dns group
make proxy             deploy Traefik na proxy group
make apps              deploy aplikacji homelab (Uptime Kuma, Portainer, Homepage)
make monitor           deploy monitoringu (Prometheus, Grafana, Alertmanager, Loki)
make monitor-agents    deploy node_exporter, cadvisor
make paperless         deploy Paperless-ngx
make gitlab            deploy GitLab CE + Runner
make minio             deploy MinIO S3
make seafile           deploy Seafile
make update-apps       pull + recreate Uptime Kuma i Portainer
make lint              terraform fmt -check + validate + ansible-lint
make up                apply → inventory → ping (jednym razem)
make datastore         stwórz datav1 storage na Proxmoxie
```

## Dodawanie domeny do Pi-hole i Traefika

Jeśli nowa usługa potrzebuje domeny `*.lab`:

1. `ansible/roles/pihole/templates/docker-compose.yml.j2` — dodaj do `FTLCONF_dns_hosts`
2. `ansible/roles/pihole/templates/custom.list.j2` — dodaj dla kompletności
3. `ansible/roles/traefik/templates/dynamic.yml.j2` — dodaj router i service
4. `make dns && make proxy`

## Self-hosted CI/CD (GitLab + DB)

| Serwer    | IP             | Rola                          |
|-----------|----------------|-------------------------------|
| gitlab-01 | 192.168.40.181 | GitLab CE + Runner + Registry |
| db-01     | 192.168.40.184 | PostgreSQL 16 + Redis 7       |

### Flow deployu

1. Push na GitHub (prywatne repo)
2. GitLab Pull Mirror synchronizuje zmiany z GitHuba
3. GitLab Runner buduje obrazy Docker, pushuje do lokalnego registry (`gitlab.lab:5050`)
4. Pipeline przez SSH deployuje na docelową VMkę

### Pierwsze kroki po deployu GitLaba

```bash
make gitlab   # deploy GitLab CE
# Poczekaj ~2-3 min aż się postawi
# Zaloguj się (admin/changeme123! — zmień w vault lub defaults)
# GitLab: Admin → Runners → utwórz token
# Ustaw token w ansible/roles/gitlab-server/defaults/main.yml (gitlab_runner_token)
# Ponownie: make gitlab
```

## Secret management

- `terraform.tfvars` — secrets Proxmoxa (gitignored)
- `ansible/.vault_pass` — hasło do Ansible Vault (gitignored)
- `vault.yml` — zaszyfrowane secrets aplikacyjne (Ansible Vault AES256)
- `roles/*/defaults/main.yml` — domyślne hasła (fallback, nadpisywane przez vault)

Nie commitować secretów. `.gitignore` to pilnuje, ale warto sprawdzać przed pushem.
