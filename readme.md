# homelab-iac

Repo zarzadzajace homelabem na Proxmoxie. Terraform tworzy VMki z cloud-init templateu, Ansible je konfiguruje. Wszystko przez `make`.

## Co tu jest

- **Terraform** - definicje VMek na Proxmoxie
- **Ansible** - konfiguracja systemow i deploy aplikacji
- **Makefile** - jeden entrypoint do wszystkiego

## Struktura

```
terraform/
  modules/vm/                 modul VM (bpg/proxmox, cloud-init)
  environments/prod/          produkcyjne VMki (DNS, proxy, apps, monitoring)
  environments/lab/           labowe VMki (CKA, kubernetes, testy)
ansible/
  inventories/prod/           inventory generowane z Terraforma
  inventories/lab/
  playbooks/                  playbooki do deployu uslug
  roles/                      role ansible (docker, pihole, traefik, itp.)
Makefile                      wrapper na terraform + ansible
```

## Schemat numeracji VMID

| Zakres    | Przeznaczenie              |
|-----------|---------------------------|
| 100-119   | AI / asystenci             |
| 120-139   | Media                      |
| 140-159   | Siec / infrastruktura      |
| 160-179   | Storage / backup           |
| 180-199   | Dev / sandbox              |
| 200-219   | Kubernetes                 |
| 220-239   | Gaming                     |
| 9000+     | Templatey                  |

IP = `192.168.40.{VMID}`. VMID 101 -> IP 192.168.40.101.

## Storage

| Datastore   | Po co                                      |
| ----------- | ------------------------------------------ |
| `local`     | ISO + cloud-init snippets                  |
| `local-lvm` | Dyski systemowe / boot                     |
| `datav1`    | Duze wolumeny (media, modele, itp.)        |
| `storage-01`| Storage wspoldzielony / cold                |
| `vm-backups`| Backup PBS / vzdump                        |

## Szybki start

```bash
# 1. Wypelnij secrets (plik jest gitignored)
cp terraform/environments/prod/terraform.tfvars.example \
   terraform/environments/prod/terraform.tfvars
$EDITOR terraform/environments/prod/terraform.tfvars

# 2. Stworz VMki
make init
make plan
make apply

# 3. Wygeneruj inventory i sprawdz czy dziala
make inventory
make ping

# 4. Aktualizacje
make update              # normalna aktualizacja
make update-check        # dry-run
```

`make up` robi apply -> inventory -> ping w jednym.

## Dwa srodowiska

Domyslnie wszystko dziala na `prod`. Zeby przelaczyc na lab:

```bash
make ENV=lab plan
make ENV=lab apply
make ENV=lab inventory
make ENV=lab ping
```

- **prod** - infrastruktura: DNS, proxy, aplikacje, monitoring, gry. Nie ruszac.
- **lab** - jednorazowe VMki, kubernetes, CKA, testy. Mozna niszczyc i odtwarzac.

Oba srodowiska siedza na tym samym Proxmoxie, ale maja **odzielny stan Terraforma**.

## Dodawanie nowej VMki

Edytuj odpowiedni `locals.tf`:
- Prod: `terraform/environments/prod/locals.tf`
- Lab: `terraform/environments/lab/locals.tf`

Dodaj entry do `local.vms`:

```hcl
jellyfin-01 = {
  vm_id     = 121
  cpu_cores = 4
  memory_mb = 8192
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

| Nazwa        | VMID | IP             | CPU | RAM   | Dysk      | Tagi                          |
| ------------ | ---- | -------------- | --- | ----- | --------- | ----------------------------- |
| assistant-01 | 101  | 192.168.40.101 | 4   | 16 GB | 50 GB     | ai, assistant                 |
| dns-01       | 141  | 192.168.40.141 | 2   | 2 GB  | 30 GB     | network, dns                  |
| proxy-01     | 142  | 192.168.40.142 | 2   | 2 GB  | 30 GB     | network, proxy, docker        |
| app-01       | 143  | 192.168.40.143 | 2   | 12 GB | 30+200 GB | apps, docker, seafile         |
| monitor-01   | 145  | 192.168.40.145 | 4   | 8 GB  | 50+100 GB | infra, monitoring, docker     |
| gitlab-01    | 181  | 192.168.40.181 | 4   | 12 GB | 50+100 GB | dev, gitlab, docker           |
| storage-01   | 160  | 192.168.40.160 | 2   | 4 GB  | 30+200 GB | storage, docker               |
| db-01        | 184  | 192.168.40.184 | 2   | 4 GB  | 30+50 GB  | database, docker              |
| games-01     | 221  | 192.168.40.221 | 4   | 24 GB | 100 GB    | gaming, valheim, docker       |

### Lab

| Nazwa             | VMID | IP             | CPU | RAM  | Dysk   | Tagi                          |
| ----------------- | ---- | -------------- | --- | ---- | ------ | ----------------------------- |
| cka-lab-master-01 | 201  | 192.168.40.201 | 2   | 4 GB | 40 GB  | kubernetes, cka, k8s-master   |
| cka-lab-master-02 | 202  | 192.168.40.202 | 2   | 4 GB | 40 GB  | kubernetes, cka, k8s-master   |
| cka-lab-worker-01 | 203  | 192.168.40.203 | 2   | 6 GB | 100 GB | kubernetes, cka, k8s-worker   |

## Makefile targets

```
make help              pokaz wszystkie targety
make init              terraform init
make plan              terraform plan
make apply             terraform apply
make destroy           terraform destroy (UWAGA - niszczy VMki)
make inventory         generuj inventory z terraform output
make ping              ansible ping wszystkich hostow
make update            aktualizacja OS + reboot jesli potrzeba
make update-check      dry-run aktualizacji
make dns               deploy Pi-hole
make proxy             deploy Traefik
make apps              deploy aplikacji homelab
make games             deploy Valheim
make monitor           deploy monitoringu
make paperless         deploy Paperless-ngx
make gitlab            deploy GitLab CE + Runner
make minio             deploy MinIO S3
make seafile           deploy Seafile
make lint              terraform fmt + validate + ansible-lint
make up                apply -> inventory -> ping (jednym razem)
make datastore         stworz datav1 storage na Proxmoxie
```

## Dodawanie domeny do Pi-hole i Traefika

Jesli nowa usluga potrzebuje domeny `*.lab`:

1. `ansible/roles/pihole/templates/custom.list.j2` - dodaj IP i domena
2. `ansible/roles/traefik/templates/dynamic.yml.j2` - dodaj router i service
3. `make dns && make proxy`

## Self-hosted CI/CD (GitLab + Front/Back/DB)

Nowa grupa VMek pod wlasne projekty webowe z CI/CD opartym na GitLab CE.

| Serwer  | IP             | Rola                            |
|---------|----------------|---------------------------------|
| gitlab-01 | 192.168.40.181 | GitLab CE + Runner + Registry   |
| db-01     | 192.168.40.184 | PostgreSQL 16 + Redis 7         |

### Flow deployu

1. Pushujesz kod na **GitHub** (prywatne repo)
2. GitLab (self-hosted) ma **Pull Mirror** — synchronizuje zmiany z GitHuba
3. GitLab Runner buduje obrazy Docker i pushuje je do **lokalnego registry** (`gitlab.lab:5050`)
4. Pipeline przez SSH deployuje na `front-01` / `back-01`

### Adresy

| Usluga     | URL                         |
|------------|----------------------------|
| GitLab     | `http://gitlab.lab`        |
| Registry   | `http://gitlab.lab:5050`  |

### Pierwsze kroki po deployu GitLaba

```bash
make gitlab   # deploy GitLab CE
# Poczekaj ~2-3 min az sie postawi
# Zaloguj sie jako root / changeme123! (zmien w defaults albo w vault)
# W GitLab: Admin -> Runners -> utworz token
# Ustaw token w ansible/roles/gitlab-server/defaults/main.yml (gitlab_runner_token)
# Ponownie: make gitlab
```

### Przyklad .gitlab-ci.yml (dla Twojego repo na GitHubie)

```yaml
stages:
  - build
  - deploy

variables:
  REGISTRY: "gitlab.lab:5050"
  APPS_HOST: "192.168.40.182"

build-front:
  stage: build
  script:
    - docker build -t $REGISTRY/front:latest ./front
    - docker push $REGISTRY/front:latest
  tags:
    - docker

build-back:
  stage: build
  script:
    - docker build -t $REGISTRY/back:latest ./back
    - docker push $REGISTRY/back:latest
  tags:
    - docker

deploy:
  stage: deploy
  script:
    - ssh homelab@$APPS_HOST "cd /opt/apps && docker compose pull && docker compose up -d"
  tags:
    - docker
```

### Konfiguracja mirroru z GitHuba

W projekcie GitLaba:
1. **Settings -> Repository -> Mirroring repositories**
2. Dodaj URL: `https://github.com/TWOJ_USER/TWOJE_REPO.git`
3. Authentication: **Personal Access Token** (GitHub -> Settings -> Developer settings -> PAT)
4. Mirror direction: **Pull**
5. Zaznacz `Trigger pipelines for mirror updates`

## Secret management

- `terraform.tfvars` - secrets Proxmoxa (gitignored)
- `ansible/.vault_pass` - haslo do Ansible Vault (gitignored)
- `vault.yml` - zaszyfrowane secrets aplikacyjne (Grafana, Alertmanager, itp.)
- `ansible/roles/gitlab-server/defaults/main.yml` - haslo root GitLaba (domyslnie `changeme123!`)
- `ansible/roles/database/defaults/main.yml` - haslo PostgreSQL (domyslnie `changeme`)

Nie commitowac secretow. `.gitignore` to pilnuje, ale warto sprawdzac przed pushem.
