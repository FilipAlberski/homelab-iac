# Sieć

## Adresacja

| Host | VMID | Adres | Usługa |
|---|---:|---|---|
| `dns-01` | 141 | `192.168.60.141` | Pi-hole |
| `proxy-01` | 142 | `192.168.60.142` | Traefik |
| `app-01` | 143 | `192.168.60.143` | aplikacje |
| `monitor-01` | 144 | `192.168.60.144` | Nagios |

Sieć VM to `192.168.60.0/24`, a domyślna brama to `192.168.60.1`.
Terraform ustawia adresy statyczne przez cloud-init. MikroTik nadal odpowiada
za routing, reguły sieciowe i DNS przekazywany klientom LAN.

Podczas bootstrapu VM używają routera i publicznego resolvera, dlatego awaria
lub rebuild `dns-01` nie blokuje Ansible. Po uruchomieniu Pi-hole należy ręcznie
ustawić `192.168.60.141` jako DNS dla klientów na MikroTiku.

Lokalne nazwy usług:

- `pihole.lab`
- `app.lab`
- `nagios.lab`
- `traefik.lab`
- `homepage.lab`
- `portainer.lab`
- `actual.lab`
- `paperless.lab`

Ruch HTTP do paneli przechodzi przez `proxy-01`. Pierwsza wersja świadomie nie
konfiguruje TLS; usługi są przeznaczone wyłącznie dla zaufanego LAN-u.
