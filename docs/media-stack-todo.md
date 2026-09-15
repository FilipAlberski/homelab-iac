# Media stack — pozostałe kroki do pełnego uruchomienia

> Stan na 31 sierpnia 2026 (koniec dnia): VM `jelly-01` wdrożona, pełny stack
> działa, GPU (Quick Sync) zweryfikowany przez `vainfo` (H264 EncSlice/LP),
> wszystkie integracje API ustawione, VPN dla downloadu aktywny, hasła paneli
> w `vault.yml`. Poniżej pozostała, ręczna część.

## 1. Pierwszy setup aplikacji (kreatorzy webowe)

> ✅ 31 sierpnia 2026: integracje skonfigurowane przez API — Prowlarr
> (FlareSolverr proxy, aplikacje Sonarr/Radarr z pełną synchronizacją
> indexerów), Sonarr/Radarr (root foldery `/data/media/*`, klient
> qBittorrent na `gluetun:8080`, test połączenia OK), Bazarr (Sonarr+Radarr),
> qBittorrent (kategorie `tv` i `movies` → `/data/torrents/*`), Jellyfin
> (biblioteki Movies i TV z monitoringiem realtime). Hasła wszystkich paneli
> są w `vault.yml`. Pozostaje ręcznie:

- [ ] Dodanie kolejnych indexerów w Prowlarr (The Pirate Bay działa; sync do
      arr-i potwierdzony)
- [x] `seerr.lab` — admin utworzony z konta Jellyfin (`admin@lab.local`),
      biblioteki Movies i TV Shows włączone, zewnętrzny URL `jellyfin.lab`
      (31.08.2026)
- [x] Seerr → arr: pełny łańcuch potwierdzony (31.08.2026) — request filmu
      i serialu 4K trafia do Radarr/Sonarr, grab z The Pirate Bay do
      qBittorrent w VPN, pobieranie działa. Uwaga: konfiguracje Sonarr muszą
      być w `/api/v1/settings/sonarr`, a Radarr w `/settings/radarr`;
      każdy serwis wymaga flagi `isDefault` w swojej grupie (4K vs non-4K)
- [ ] Weryfikacja profili jakości w Sonarr/Radarr według preferencji

## 2. Download stack (Gluetun + qBittorrent)

> ✅ 31 sierpnia 2026: VPN wdrożony z `pl-waw-wg-101` (sekrety w vault,
> plik źródłowy usunięty). Gluetun `healthy`, qBittorrent widzi IP VPN
> (`45.134.212.78`), `qbittorrent.lab` odpowiada 200 przez Traefika.

- [x] Sekrety VPN w vault, `media_download_enabled: true`
- [x] Kategorie qBittorrenta: `tv` i `movies` → `/data/torrents/{tv,movies}`;
      Sonarr używa `tvCategory=tv`, a Radarr `movieCategory=movies`
      (wyrównane 1.09.2026; stare puste kategorie usunięte)
- [x] Podłączenie Sonarr/Radarr do qBittorrenta (`gluetun:8080`)
- [x] Hardlink import potwierdzony 1 września 2026: dwa ukończone torrenty
      mają po dwa wpisy wskazujące ten sam inode w `/data/torrents` i `/data/media`.
- [x] Radarr: `Skip free space check when importing` włączone 1 września 2026,
      aby duże pliki na tym samym XFS mogły być importowane hardlinkiem.
- [ ] Test odcina VPN → qBittorrent stoi, reszta stacku działa

> Uwaga operacyjna: w `qBittorrent.conf` wyłączono `CSRFProtection` i
> `HostHeaderValidation` (homelab LAN); hasło WebUI wstrzykiwane hashem
> PBKDF2 z vault przy zmianie.

## 3. Transkodowanie sprzętowe

- [x] QSV/iHD włączone 1 września 2026 dla kodeków raportowanych przez iGPU
      (H.264, HEVC/10-bit, MPEG-2, VC-1, VP8 i VP9).
- [ ] Test rzeczywistego transcode H264 i HEVC (playback w przeglądarce + `intel_gpu_top`
      na VM podczas odtwarzania)

## 4. Konta i dostęp (decyzja, nie pilne)

- [ ] Authentik jako źródło użytkowników; Jellyfin przez plugin LDAP,
      panele webowe przez OIDC albo `forwardAuth` — osobna decyzja projektowa
- [ ] Rozważyć TLS na Trasie (obecnie świadomie HTTP na LAN)

## 5. Operacje

- [x] `make site` idempotentny dla całego labu (dwa pełne przebiegi, 0 failures)
- [x] Nagios: jelly-01 w hostgroup `homelab` (config wdrożony)
- [ ] Panel `nagios.lab` — potwierdzić wzrokowo, że jelly-01 odpowiada PING
- [ ] Kopia `terraform.tfstate` poza hostem (dotyczy też nowego zasobu jelly-01)
- [ ] Commit zmian z dnia: rebuild całego labu, wdrożenie jelly-01, rola media,
      poprawka `growpart` w `common`, integracje API
- [ ] Decyzja o hasłach dla Seerr/Bazarr → dopisać do vault
      (`vault_seerr_admin_password`, `vault_bazarr_admin_password`)

## Artefakty gotowe do użycia

| Element | Gdzie |
|---|---|
| Compose (wszystkie usługi) | `ansible/roles/media/templates/compose.yml.j2` |
| Rola Ansible media | `ansible/roles/media/` |
| Flagi i digesty obrazów | `ansible/inventory/group_vars/all/main.yml` |
| Sekrety VPN i paneli | `ansible/inventory/group_vars/all/vault.yml`; dedykowany klucz widgetu Jellyfina w zaszyfrowanym `media_vault.yml` |
| Dysk danych | `/data` (XFS po UUID, `nofail`) na `jelly-01` |
| Konfiguracje aplikacji | `/opt/media-stack/config/*` na `jelly-01` |
| GPU legacy-IGD | jednorazowo `qm set 131 --hostpci0 host=0000:00:02.0,legacy-igd=1,rombar=1 --vga none` |

## Szybka ściąga API (na przyszłość)

- Sonarr/Radarr v3: `X-Api-Key`, downloadclient `QBittorrent` (host `gluetun`)
- Prowlarr v1: `/api/v1/applications` (wymaga pełnego obiektu przy PUT), `/api/v1/indexerProxy`
- Bazarr 1.6: `?apikey=` w query, settings przez `/api/system/settings` (pełny obiekt)
- Jellyfin 10.11: access token w nagłówku `X-Emby-Token`, biblioteki przez `POST /Library/VirtualFolders`
- qBittorrent 5.x: login zwraca 204 + cookie `QBT_SID_<port>`, kategorie przez `POST /api/v2/torrents/createCategory`
