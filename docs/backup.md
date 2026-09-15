# Backup

Backup jest częścią MVP. Kopia znajdująca się wyłącznie na `tank-zfs` nie
chroni przed utratą hosta lub całej puli.

## Ustalone miejsca kopii

Plan bieżącego etapu zakłada dwie lokalne kopie:

1. główną kopię na macierzy RAID z dwóch zewnętrznych dysków po 4 TB,
2. drugą, niezależną kopię na osobnym dysku 1 TB.

Pierwszą kopię wykonano 6 września 2026:

- RAID: `/tank/backup/2026-09-06`,
- dysk 1 TB: `/mnt/pve/datav1/dump/homelab-2026-09-06`,
- zakres: VM 131, 141, 142, 143, 144 i 147,
- wynik: sześć archiwów `.vma.zst`, około 39 GB, porównanie bajt po bajcie
  zakończone sukcesem.

Po weryfikacji usunięto z dysku 1 TB stary plik RAW, stare archiwa i nieużywany
obraz QCOW2. Na `/mnt/pve/datav1` pozostał wyłącznie katalog świeżej kopii
`dump/homelab-2026-09-06`; wolne miejsce wynosi około 832 GB.

Na `jelly-01` dysk `scsi1` z biblioteką filmową ma `backup=0`; backup zawiera
tylko dysk systemowy. To nie zastępuje kopii konfiguracji i danych aplikacji.
W przebiegach do rana 8 września Proxmox nie mógł wykonać `fs-freeze` dla
`/data` na Jellyfinie ani `/srv/data` na `app-01`; archiwa powstawały poprawnie,
ale snapshoty tych filesystemów nie były wyciszone.

Przyczyną były etykiety SELinux `unlabeled_t` na punktach montowania dodatkowych
dysków. Rola `app_storage` przywraca teraz właściwą etykietę po zamontowaniu,
dzięki czemu agent QEMU może zamrozić filesystem na czas snapshotu.
Poprawkę potwierdzono 8 września ręcznym testem freeze/thaw na obu VM-ach.

Przed pierwszym zapisem trzeba potwierdzić na hoście Proxmox dokładne urządzenia
i punkty montowania, wolne miejsce, tryb RAID oraz zawartość nośników. Nie wolno
formatować ani tworzyć nowego systemu plików na podstawie samego rozmiaru dysku.
Druga kopia została wykonana po zakończeniu pierwszej i zweryfikowana bajt po
bajcie. Przy kolejnych uruchomieniach należy zachować tę kolejność oraz raport
liczby plików, rozmiaru i błędów.

## Automatyczny backup

Backup VM jest uruchamiany przez timer systemd na hoście Proxmox dwa razy
dziennie — około 07:00 i 20:00, z losowym opóźnieniem do 15 minut. Najpierw `vzdump` tworzy kopię
na `/tank/backup`, a dopiero po jej zakończeniu skrypt kopiuje ją do
`/mnt/pve/datav1/dump` i sprawdza sumy SHA-256. Objęte są VM-y 131, 141, 142,
143, 144 i 147. Dysk filmowy Jellyfina pozostaje wykluczony przez
`backup=0` w konfiguracji VM 131.

Po poprawnym sprawdzeniu obu kopii automatyzacja usuwa stare katalogi zgodnie z
retencją: 14 najnowszych kopii oraz do 4 starszych kopii niedzielnych, przy czym
tylko jedna kopia z każdej niedzieli jest zachowywana. Katalogi o nierozpoznanym formacie nazwy są pozostawiane bez zmian. Timer nie
uruchamia backupu podczas wdrożenia — pierwszy przebieg następuje zgodnie z
harmonogramem albo ręcznie przez usługę systemd.

## Automatyczny backup Paperless

Przed każdym backupem VM, około 06:00 i 19:00, timer
`paperless-backup.timer` uruchamia aplikacyjny eksport Paperless oraz logiczny
dump PostgreSQL. Wynik trafia atomowo do katalogu
`/srv/data/paperless/export/paperless-YYYY-MM-DD-HHMMSS` i zawiera manifest,
metadane, `paperless.dump` oraz `SHA256SUMS`.

Na dysku VM pozostaje jeden najnowszy automatyczny eksport. Starsze kopie są
dostępne we wcześniejszych archiwach VM na obu nośnikach Proxmoxa. Niekompletny
katalog nie zastępuje ostatniego poprawnego eksportu, a nieudana próba jest
raportowana do Prometheusa od razu, niezależnie od limitu świeżości 48 godzin.
Pierwszy automatyczny eksport wykonano i zweryfikowano 8 września 2026;
sprawdzono wszystkie sumy SHA-256 oraz odczyt katalogu obiektów dumpu przez
`pg_restore`.

## Co kopiować

| Dane | Mechanizm | Minimalne miejsce docelowe |
|---|---|---|
| Repozytorium | Git | prywatny zdalny Git |
| Terraform state | kopia `terraform.tfstate` po każdym apply | zaszyfrowany nośnik poza hostem |
| Sekrety Ansible | zaszyfrowany `vault.yml` w Git | Git oraz osobny backup hasła Vault |
| VM-y | backup Proxmox `vzdump` | fizycznie osobny dysk |
| Paperless | `document_exporter`, dump PostgreSQL i `/srv/data/paperless` | fizycznie osobny dysk |
| MikroTik | ręczny export i backup binarny | poza repozytorium |

## Terraform state

State jest lokalny i ignorowany przez Git. Po udanym `terraform apply` skopiuj:

```text
terraform/prod/terraform.tfstate
```

do zaszyfrowanego backupu. State może zawierać dane wrażliwe, dlatego nie należy
wysyłać go do zwykłego repozytorium ani przechowywać bez szyfrowania.

Przed odtworzeniem sprawdź, czy backup state odpowiada ostatniej zmianie VM.

Paperless przechowuje wszystkie jawne wolumeny pod `/srv/data/paperless`.
Automatyzacja wykonuje `document_exporter` oraz logiczny dump PostgreSQL; samo
kopiowanie działającego katalogu `pgdata` nie gwarantuje spójnego backupu bazy.

## Test odtworzenia

### Historia testów

8 września 2026 odtworzono najnowsze archiwum VM 141 z głównej kopii jako
tymczasową VM 990. Odtworzenie dysku 30 GB z archiwum 1,33 GB trwało 40 sekund.
Przed startem usunięto interfejs sieciowy i wyłączono autostart, więc VM nie
mogła wejść w konflikt z produkcyjnym adresem. Rocky Linux 10.2 uruchomił się,
agent QEMU odpowiedział po 10 sekundach, a `/` i `/boot` były dostępne.

Tego samego dnia dump PostgreSQL z automatycznego eksportu Paperless odtworzono
do tymczasowej bazy. Odtworzenie zakończyło się poprawnie, zawierało 242 wpisy
migracji i zero dokumentów, zgodnie z aktualnie pustą biblioteką. Tymczasową
bazę usunięto po teście.

Raz na kwartał odtwórz niekrytyczną VM z backupu do nowego VMID w odizolowanej
sieci albo wykonaj kontrolowany rebuild. Nie używaj istniejącego VMID i nie
podłączaj testu do domowej sieci bez sprawdzenia konfiguracji. Po odtworzeniu
zweryfikuj start systemu, dostęp do dysków, agenta QEMU i wybrane dane usługi.
Backup bez przetestowanego restore nie jest wystarczający.

Przed testem sprawdź wolny VMID i wybierz konkretne archiwum. Po zakończeniu
zatrzymaj i usuń testową VM dopiero po potwierdzeniu, że wynik testu został
zapisany w dokumentacji.

`dataV1` nie jest elementem tego planu. Do czasu osobnej migracji pozostaje
starym, nietykanym źródłem danych.
