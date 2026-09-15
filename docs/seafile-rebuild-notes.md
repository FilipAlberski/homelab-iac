# Notatki do świeżego Seafile

Stare wdrożenie Seafile na `app-01` zostało przeznaczone do całkowitego
usunięcia wraz z bazą i plikami. Nowa wersja ma powstać od zera i korzystać z
osobnego dysku danych na `tank-zfs`, a nie ze współdzielonego dysku `app-01`.

## Historyczny stack

Stary projekt Compose znajdował się w `/srv/data/seafile`, zajmował około
167 MiB i składał się z czterech kontenerów:

| Usługa | Historyczny obraz | Dane |
|---|---|---|
| Seafile | `seafileltd/seafile-mc:latest` | `./seafile-data:/shared` |
| MariaDB | `mariadb:10.11` | `./mysql-data:/var/lib/mysql` |
| Redis | `redis` | dane nietrwałe |
| Memcached | `memcached` | dane nietrwałe |

Seafile był wystawiony jako `app-01:8002`, a Traefik obsługiwał nazwę
`seafile.lab`. Stare hasła administratora, bazy i klucz JWT nie powinny być
ponownie używane.

## Wymagania nowej wersji

1. Świeży system aplikacji, świeża baza i nowe sekrety w Ansible Vault.
2. Osobny dysk danych utworzony na `tank-zfs`.
3. Dysk montowany po UUID/label z wpisem `nofail` i timeoutem startu.
4. Obrazy przypięte digestami po sprawdzeniu aktualnie wspieranych wersji.
5. HTTPS przez Traefika od pierwszego uruchomienia.
6. Integracja z Authentikiem dopiero po sprawdzeniu mechanizmu obsługiwanego
   przez wybraną edycję Seafile.
7. Backup bazy i bibliotek opisany oraz przetestowany przed użyciem produkcyjnym.
8. Lokalny administrator awaryjny przechowywany w Vault lub menedżerze haseł.

Preferowany wariant to osobna VM `files-01` z małym dyskiem systemowym i
oddzielnym dyskiem danych `tank-zfs`. Dzięki temu Seafile nie współdzieli
filesystemu ani cyklu życia z Paperless na `app-01`.
