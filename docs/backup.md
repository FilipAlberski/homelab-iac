# Backup

Backup jest częścią MVP. Kopia znajdująca się wyłącznie na `tank-zfs` nie
chroni przed utratą hosta lub całej puli.

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
Przed większą zmianą wykonaj eksport dokumentów poleceniem `document_exporter`
oraz logiczny dump PostgreSQL. Samo kopiowanie działającego katalogu `pgdata`
nie gwarantuje spójnego backupu bazy.

## Test odtworzenia

Raz na kwartał odtwórz niekrytyczną VM z backupu albo wykonaj kontrolowany
rebuild. Backup bez przetestowanego restore nie jest wystarczający.

`dataV1` nie jest elementem tego planu. Do czasu osobnej migracji pozostaje
starym, nietykanym źródłem danych.
