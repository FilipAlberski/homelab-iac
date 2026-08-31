# Rebuild homelabu

## Warunki wstępne

Przed rozpoczęciem potrzebne są:

- działający Proxmox z bridge `vmbr0`,
- ręcznie utworzona pula/storage `tank-zfs`,
- template Rocky Linux z cloud-init i VMID `9000`,
- dostęp do API Proxmox,
- prywatny klucz SSH odpowiadający kluczowi publicznemu w `terraform.tfvars`,
- backup Terraform state, Vaulta i danych usług.

## Odtworzenie

1. Sklonuj repozytorium.
2. Odtwórz `terraform/prod/terraform.tfstate` z backupu, jeśli odbudowujesz
   istniejące zasoby. Nie uruchamiaj `apply` z pustym state przeciwko istniejącym VM.
3. Utwórz `terraform/prod/terraform.tfvars` z przykładu.
4. Uruchom `make init` i `make plan`.
5. Sprawdź każdą operację create, replace i destroy w planie.
6. Uruchom `make apply`.
7. Utwórz `ansible/.vault_pass`, odtwórz zaszyfrowany `vault.yml` i uruchom
   `make deps`.
8. Sprawdź SSH przez `make ping`.
9. Uruchom `make bootstrap`, a następnie `make site`.
10. Dla Paperless odtwórz `/srv/data/paperless`, sekrety z Vaulta i — zależnie
    od rodzaju kopii — import `document_exporter` albo dump PostgreSQL.
11. Sprawdź DNS, routing Traefika, aplikacje i widoczność hostów w Nagiosie.

## Bezpieczny test

Pierwszy test wykonaj na `monitor-01` albo innej niekrytycznej VM. Nie zaczynaj
od `dns-01`. `dataV1` nie może być montowany,
formatowany ani dodawany do Terraform podczas rebuilda.
