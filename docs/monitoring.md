# Monitoring homelabu

Stack działa na `monitor-01` i jest opisany w dwóch rolach Ansible:

- `metrics_agent` uruchamia `node_exporter` i cAdvisor na każdej VM,
- `monitoring` uruchamia Prometheusa, Grafanę, blackbox_exporter, opcjonalny
  Alertmanager oraz opcjonalne eksportery Proxmoxa, MikroTika i Pi-hole.

Grafana jest dostępna jako `http://grafana.lab`. Prometheus i eksportery nie są
wystawiane przez Traefika. Retencja Prometheusa jest ograniczona jednocześnie
do 30 dni i 20 GB, żeby monitoring nie zapełnił dysku `monitor-01`.

Centralny przepływ danych wygląda tak:

```text
VM-y i usługi → eksportery → Prometheus → Grafana
                                      ├→ Alertmanager → Telegram
                                      └→ Homepage: Aktywne alerty
```

Najważniejsze endpointy:

| Usługa | Endpoint | Rola |
|---|---|---|
| Prometheus | `monitor-01:9090` | metryki i reguły alertów |
| Grafana | `grafana.lab` / `monitor-01:3000` | dashboardy |
| Alertmanager | `127.0.0.1:9093` | grupowanie i Telegram |
| blackbox-exporter | `monitor-01:9115` | testy HTTP/ICMP |
| pve-exporter | `monitor-01:9221` | metryki Proxmoxa |
| pihole-exporter | `monitor-01:9617` | statystyki Pi-hole |
| node_exporter | każdy Docker host `:9100` | hosty i filesystemy |
| cAdvisor | każdy Docker host `:8081` | kontenery Docker |
| Diun | każdy Docker host `:9095` | aktualizacje obrazów |

Monitorowane hosty:

| Host | Adres | Usługi |
|---|---:|---|
| `dns-01` | `192.168.60.141` | Pi-hole, Docker |
| `proxy-01` | `192.168.60.142` | Traefik, Docker |
| `app-01` | `192.168.60.143` | Homepage, Portainer, Paperless, Docker |
| `monitor-01` | `192.168.60.144` | Prometheus, Grafana, Alertmanager, Nagios |
| `jelly-01` | `192.168.60.131` | Jellyfin i media stack, Docker |
| Proxmox | `192.168.60.10` | VM-y, storage i backup |

## Co jest zbierane

| Źródło | Eksporter | Stan początkowy |
|---|---|---|
| Linux VM | node_exporter | gotowy |
| Docker | cAdvisor | gotowy |
| ping i HTTP | blackbox_exporter | gotowy |
| Pi-hole | pihole-exporter | włączony razem ze stackiem |
| Proxmox API | prometheus-pve-exporter | gotowy |
| MikroTik | snmp_exporter (`if_mib` + `system`) | opcjonalny |
| własna aplikacja `/metrics` | bez pośrednika | lista konfigurowalna |
| eksport Paperless | textfile collector na `app-01` | gotowy |

Grafana dostaje automatycznie źródło Prometheus oraz dashboard „Homelab
overview” z kondycją celów, CPU, RAM, filesystemami, kontenerami i czasami
odpowiedzi HTTP. Prometheus ma też reguły dla niedostępnych celów, wysokiego
CPU, małej ilości RAM, kończącego się dysku i wygasających certyfikatów.
Dashboard zawiera również wykres ruchu DNS Pi-hole oraz historię dziennych
zapytań i zablokowanych zapytań. Dane pochodzą z `pihole-exporter` i są
przechowywane w retencji Prometheusa.

Główne reguły alertów to: `TargetDown`, `HostHighCpuUsage`,
`HostLowAvailableMemory`, `HostFilesystemAlmostFull`, `ProbeFailed`,
`HttpCertificateExpiringSoon`, `ContainerImageUpdateAvailable`,
`PaperlessBackupMissing`, `PaperlessBackupIncomplete`,
`PaperlessBackupStale`, `PaperlessBackupJobFailed`, `HostFilesystemReadOnly`,
`HostFilesystemInodesAlmostFull`, `ProxmoxNodeUnavailable`,
`ProxmoxStorageUnavailable` oraz `HomelabVmUnavailable`.

Testy HTTP celują w lokalne nazwy `*.lab`, dlatego `monitor-01` oraz kontener
`blackbox-exporter` korzystają z Pi-hole (`dns-01`) jako podstawowego DNS i z
`1.1.1.1` jako fallbacku. Rola monitoringu zapisuje ustawienie hosta w
NetworkManagerze i przekazuje DNS do kontenera; bez lokalnego DNS wszystkie
probe’y HTTP mogłyby zgłosić awarię jednocześnie mimo sprawnych usług.
Nagios używa osobnego modułu, który uznaje `401 Unauthorized` za oczekiwaną
odpowiedź dostępnego panelu chronionego logowaniem.

## Powiadomienia Telegram

Alertmanager wysyła alerty i wiadomości o ich ustąpieniu do Telegrama. Jest
uruchamiany tylko po ustawieniu `monitoring_alertmanager_enabled: true` oraz
dodaniu do zaszyfrowanego Vaulta:

```yaml
vault_monitoring_telegram_bot_token: "token od BotFather"
vault_monitoring_telegram_chat_id: "123456789"
```

Alertmanager nasłuchuje wyłącznie na `127.0.0.1:9093`; nie jest wystawiony przez
Traefika. Powiadomienia są grupowane po nazwie alertu, ważności i zadaniu,
krótkie przerwy czekają 30 sekund, a powtórzenie następuje po 4 godzinach.
Alert o niedostępności eksportera Linux wycisza alerty usług przypisanych do tej
samej VM. W czasie planowanych prac należy wyciszyć grupę w Alertmanagerze albo
tymczasowo wyłączyć odpowiedni alert, a po zakończeniu sprawdzić także wiadomość
`RESOLVED`.

## Aktualizacje obrazów kontenerów

Na każdej VM z Dockerem działa Diun (`container_updates`). Sprawdza co 6 godzin
zmiany tagów i digestów wszystkich obrazów oraz wysyła informację do tego samego
czatu Telegrama. Pracuje wyłącznie w trybie informacyjnym: nie podmienia usług
ani nie restartuje kontenerów. Dzięki temu aktualizacja Paperlessa, Pi-hole albo
media stacku nadal odbywa się kontrolowanie przez zmianę digestu w repozytorium
i wdrożenie Ansible.

Diun wystawia także metryki Prometheusa. Prometheus tworzy z nich alert
`ContainerImageUpdateAvailable`, więc dostępna aktualizacja jest widoczna w
Homepage razem z pozostałymi aktywnymi alertami i trafia do Telegrama. Alert
znika po zmianie digestu i ponownym wdrożeniu.

## Backup Paperless i filesystemy

Na `app-01` timer systemd co 5 minut sprawdza najnowszy katalog w
`/srv/data/paperless/export`. Eksport jest uznany za kompletny tylko wtedy, gdy
zawiera `manifest.json`, `metadata.json` oraz `paperless.dump`. Stan i wiek
kopii są wystawiane przez textfile collector `node_exporter`.

Osobny timer wykonuje eksport aplikacyjny i logiczny dump bazy około 06:00 oraz
19:00, przed backupami całej VM. Ostatnia próba jest raportowana niezależnie od
wieku poprzedniej poprawnej kopii.

Prometheus zgłasza:

- brak jakiegokolwiek eksportu Paperless,
- niekompletny eksport,
- kopię starszą niż 48 godzin,
- błąd ostatniej automatycznej próby eksportu,
- filesystem zamontowany tylko do odczytu,
- mniej niż 10% wolnych inode’ów.

Eksporter Proxmoxa zbiera również stan noda, storage i ważnych VM. Alerty
obejmują niedostępny node, storage oraz wyłączenie VM 131, 141, 142, 143, 144
lub 147. Template VM 9000 jest celowo pominięty.

Alerty trafiają do tego samego widoku aktywnych alertów Homepage i do Telegrama.
Nie zastępuje to jeszcze kontroli fizycznego SMART dysków Proxmoxa.

## Automatyczny backup VM

Na hoście Proxmox działa timer `homelab-vzdump-backup.timer`. Uruchamia backup
dwa razy dziennie — około 07:00 i 20:00, z losowym opóźnieniem do 15 minut.

Kolejność jest celowa:

1. `vzdump` tworzy kopię na RAID w `/tank/backup`,
2. po sukcesie kopia trafia do `/mnt/pve/datav1/dump`,
3. druga kopia jest sprawdzana przez SHA-256.

Backup obejmuje VM-y `131`, `141`, `142`, `143`, `144` i `147`. Dysk z filmami
na VM `131` ma `backup=0`, więc nie jest kopiowany. Retencja przechowuje 14
najnowszych kopii oraz do 4 starszych kopii niedzielnych, po jednej na niedzielę.

Backup VM zawiera Paperless jako całą VM oraz najnowszy spójny eksport
aplikacyjny z logicznym dumpem PostgreSQL.

## Uruchomienie po powrocie labu

Alertmanager jest włączony w `group_vars/all/main.yml`, a sekrety Telegrama są
przechowywane w zaszyfrowanym Vault. Sam monitoring i eksportery pozostają
zarządzane przez repo.

```yaml
monitoring_alertmanager_enabled: true
```

W Vault znajdują się:

```yaml
vault_grafana_admin_password: "długie-losowe-hasło"
vault_monitoring_telegram_bot_token: "token od BotFather"
vault_monitoring_telegram_chat_id: "identyfikator czatu"
```

Po zmianie sekretów uruchom `make site`; nie trzeba ręcznie importować dashboardu
ani konfigurować źródła danych.

## Proxmox

Na Proxmoxie działa osobne konto `prometheus@pve` z tokenem `exporter`.
Użytkownik i token mają wyłącznie rolę `PVEAuditor` na `/`; token działa z
niezależnymi uprawnieniami (`privsep`), dlatego rola jest przypisana również
bezpośrednio do tokena. Sekret znajduje się wyłącznie w zaszyfrowanym Vaultcie:

```yaml
vault_pve_exporter_token_name: "nazwa-tokena"
vault_pve_exporter_token_value: "wartość-tokena"
```

Konfiguracja jest aktywna przez `monitoring_pve_enabled: true`. Prometheus
scrapuje endpoint `/pve` przez `monitor-01:9221`, a target `proxmox` powinien
mieć `up = 1`.

Dla obecnego samopodpisanego certyfikatu `monitoring_pve_verify_ssl` jest
ustawione na `false`; po wdrożeniu zaufanego certyfikatu należy zmienić je na
`true`.

Eksporter zbiera stan noda, storage i VM. Alerty Proxmoxa obejmują node,
storage oraz VM-y `131`, `141`, `142`, `143`, `144` i `147`. Template `9000`
jest celowo pominięty, ponieważ zwykle pozostaje wyłączony.

Eksporter nie zastępuje jeszcze monitoringu SMART fizycznych dysków Proxmoxa.
Stan puli RAID jest sprawdzany przed rozpoczęciem automatycznego backupu.

## MikroTik

Eksporter używa SNMPv2c wyłącznie do odczytu standardowych metryk interfejsów i
systemu. Na MikroTiku ogranicz community do adresu `192.168.60.144/32`, dodaj je
do Vaulta jako `vault_mikrotik_snmp_community` i ustaw
`monitoring_mikrotik_snmp_enabled: true`. SNMPv2c nie szyfruje community; jeśli
segment przestanie być zaufany, przejdź na SNMPv3.

## Własne aplikacje

Endpointy w formacie Prometheusa dopisuje się bez nowego eksportera:

```yaml
monitoring_custom_metrics_targets:
  - name: moja-aplikacja
    target: 192.168.60.143:8088
```

Prometheus pobierze z każdego celu `/metrics`. Port aplikacji nadal powinien być
dopuszczony na firewallu wyłącznie z `192.168.60.144`.

## Operacyjne sprawdzenie monitoringu

Walidacja konfiguracji Ansible:

```bash
cd ansible
ansible-playbook --syntax-check --vault-password-file .vault_pass \
  playbooks/site.yml
```

Walidacja konfiguracji i reguł Prometheusa na `monitor-01`:

```bash
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml
docker exec prometheus promtool check rules /etc/prometheus/rules/alerts.yml
```

Status targetów i alertów jest dostępny pod:

```text
http://monitor-01:9090/targets
http://monitor-01:9090/alerts
```

Status automatycznego backupu na Proxmoxie:

```bash
systemctl list-timers homelab-vzdump-backup.timer --all
journalctl -u homelab-vzdump-backup.service
```

Status aplikacyjnego backupu Paperless:

```bash
systemctl list-timers paperless-backup.timer --all
journalctl -u paperless-backup.service
```

Po zmianie sekretów lub konfiguracji uruchom `make site`; dashboard i źródło
Prometheusa są wdrażane automatycznie.

## Granice bezpieczeństwa

- Grafana nie dopuszcza anonimowego dostępu ani rejestracji użytkowników.
- Sekrety trafiają wyłącznie do pliku `.env` z prawami `0600`.
- Eksportery VM nasłuchują w sieci hosta, więc ich dostęp kontroluje firewalld.
- Publiczny routing istnieje tylko dla Grafany; Prometheus pozostaje wewnętrzny.
- Bez włączonego Alertmanagera alerty są widoczne w Grafanie/Prometheusie;
  po jego włączeniu Telegram jest kanałem pierwszego wyboru.
