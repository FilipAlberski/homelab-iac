# Notatki do świeżego media stacku

Ten dokument zachowuje użyteczne elementy usuwanej VM `jelly-01`. Nie jest
instrukcją odtworzenia starej VM 1:1. Nowa instalacja ma powstać od zera, bez
starych konfiguracji i bez zachowywania mediów.

## Potwierdzona konfiguracja starej VM

| Element | Wartość |
|---|---|
| Nazwa / VMID / IP | `jelly-01` / `131` / `192.168.60.131` |
| CPU / RAM | 4 vCPU / 24 GiB |
| Dysk systemowy | 50 GiB, `local-lvm`, `scsi0` |
| Dysk danych | 1 TiB, `tank-zfs:vm-131-disk-0`, `scsi1` |
| Kontroler | `virtio-scsi-single` |
| Sieć | VirtIO na `vmbr0`, MAC `BC:24:11:46:F9:18` |
| Autostart | włączony |
| GPU | mapping `jellyfin-igpu`, legacy IGD, `rombar=1`, `vga: none` |

Po zaniku zasilania system gościa zatrzymał się przed uruchomieniem sieci i
QEMU Guest Agenta. Proxmox widział VM jako uruchomioną, ale karta gościa nie
wysyłała ruchu. Nie odzyskujemy tego systemu — budujemy nowy.

Na `dataV1` istniał dodatkowy, odłączony plik VM. Przed usunięciem VM został
on zabezpieczony przed automatycznym kasowaniem providera przez odwracalne
przeniesienie do
`/mnt/pve/datav1/archive/jelly-legacy-datav1-2026-08-31.raw`. Nie jest częścią
nowego projektu ani pełnoprawnym backupem; pozostaje do osobnej decyzji o
wyczyszczeniu `dataV1`.

## Historyczny stack aplikacji

Stare repo opisywało jeden projekt Compose `/opt/media-stack` z następującymi
kontenerami:

| Usługa | Historyczny obraz | Port hosta |
|---|---|---:|
| Jellyfin | `jellyfin/jellyfin:10.11.11` | 8096 |
| Seerr | `ghcr.io/seerr-team/seerr:v3.3.0` | 5055 |
| Sonarr | `lscr.io/linuxserver/sonarr:latest` | 8989 |
| Radarr | `lscr.io/linuxserver/radarr:latest` | 7878 |
| Prowlarr | `lscr.io/linuxserver/prowlarr:latest` | 9696 |
| FlareSolverr | `ghcr.io/flaresolverr/flaresolverr:v3.5.0` | tylko sieć Compose, 8191 |
| Bazarr | `lscr.io/linuxserver/bazarr:latest` | 6767 |
| qBittorrent | `lscr.io/linuxserver/qbittorrent:latest` | 8080 przez Gluetun |
| Gluetun | `qmcgaw/gluetun:v3.41.1` | 8080 i health 9999 |

Nowe wdrożenie ma przypinać obrazy digestami po sprawdzeniu aktualnych wersji.
Gluetun i qBittorrent pozostają na początku wyłączone — obecna konfiguracja VPN
nie jest gotowa do użycia.

## Układ danych, który warto zachować

Cały dysk danych był jednym filesystemem ext4 zamontowanym jako `/data`:

```text
/data
├── torrents
│   ├── movies
│   └── tv
└── media
    ├── movies
    └── tv
```

qBittorrent, Sonarr, Radarr i Bazarr widziały identyczne `/data:/data`.
Jellyfin widział tylko `/data/media:/data/media:ro`. Dzięki jednemu filesystemowi
Sonarr i Radarr mogły importować pliki przez hardlinki. Tego układu nie należy
rozbijać na osobne filesystemy ani niezależne wolumeny Dockera.

Konfiguracje aplikacji znajdowały się na dysku systemowym:

```text
/opt/media-stack/config/{gluetun,qbittorrent,sonarr,radarr,prowlarr,bazarr,jellyfin,seerr}
/opt/media-stack/cache/jellyfin
```

Kontenery działały jako UID/GID `1000:1000`, z `UMASK=002` i strefą
`Europe/Warsaw`.

## Historyczne integracje

- qBittorrent współdzielił namespace sieciowy Gluetuna; zatrzymanie VPN miało
  odcinać wyłącznie qBittorrenta.
- Kategorie qBittorrenta: `tv` i `movies`.
- Sonarr importował do `/data/media/tv`, Radarr do `/data/media/movies`.
- Sonarr i Radarr miały włączone `copyUsingHardlinks`.
- Prowlarr synchronizował indexery do Sonarra i Radarra.
- FlareSolverr był prywatnym proxy Prowlarra z tagiem `flaresolverr`.
- Bazarr łączył się z Sonarr/Radarr i używał profilu napisów PL+EN `polen`.
- Seerr łączył się z Jellyfinem, Sonarrem i Radarrrem.
- Jellyfin miał biblioteki Movies i TV z monitoringiem zmian w czasie
  rzeczywistym.
- Recyclarr był świadomie wyłączony.

## Intel Quick Sync

Host ma Intel HD 630 (`8086:5912`, `0000:00:02.0`, subsystem `1028:07a1`).
Działający wariant wymagał mapowania Proxmox `jellyfin-igpu`, maszyny i440fx,
legacy IGD, `rombar=1` i `vga: none`. W gościu należy potwierdzić obecność
`/dev/dri/renderD128`, przekazać `/dev/dri` do kontenera, dodać GID grup
`render` i `video`, a następnie sprawdzić `vainfo` oraz rzeczywisty transcode.

Nie wolno zakładać, że samo dodanie ogólnego `hostpci` w Terraform odtworzy
`legacy-igd=1`. Ten parametr może nadal wymagać jawnej konfiguracji po stronie
Proxmoxa.

## Założenia dla nowej wersji

1. Świeża VM, świeży system i świeże konfiguracje aplikacji.
2. Nowy pusty dysk danych na `tank-zfs`; stare media nie są odtwarzane.
3. Dysk identyfikowany stabilnie przez UUID/label, nie wyłącznie `/dev/sdb`.
4. Mount w `/etc/fstab` odporny na brak dysku (`nofail` i timeout), aby problem
   z dyskiem danych nie blokował startu systemu i SSH.
5. Osobne role lub wyraźne sekcje dla Jellyfin, Servarr i download stacku.
6. Gluetun/qBittorrent wdrażane dopiero po przygotowaniu nowych danych VPN.
7. Authentik jako źródło użytkowników; Jellyfin przez plugin LDAP, panele webowe
   przez OIDC albo `forwardAuth`, zależnie od możliwości aplikacji.
8. Lokalne konto administracyjne Jellyfina pozostaje jako konto awaryjne.
9. Testy końcowe: health wszystkich kontenerów, hardlink, integracje API,
   dostęp bibliotek, restart całego Compose i sprzętowy transcode QSV.

## Nazwy, które można później przywrócić

`jellyfin.lab`, `seerr.lab`, `sonarr.lab`, `radarr.lab`, `prowlarr.lab`,
`bazarr.lab` i `qbittorrent.lab`. Do czasu uruchomienia nowego stacku rekordy,
trasy Traefika i kafelki Homepage powinny pozostać usunięte.
