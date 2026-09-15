# Sieć

## Adresacja

| Host | VMID | Adres | Usługa |
|---|---:|---|---|
| `dns-01` | 141 | `192.168.60.141` | Pi-hole |
| `proxy-01` | 142 | `192.168.60.142` | Traefik |
| `app-01` | 143 | `192.168.60.143` | aplikacje |
| `jelly-01` | 131 | `192.168.60.131` | media stack |
| `monitor-01` | 144 | `192.168.60.144` | Nagios, Prometheus, Grafana |
| `homeassistant-01` | 147 | `192.168.60.147` | Home Assistant OS, ZHA |
| `k8s-cp1` | 151 | `192.168.60.151` | Kubernetes control plane |
| `k8s-w1` | 152 | `192.168.60.152` | Kubernetes worker |
| `k8s-w2` | 153 | `192.168.60.153` | Kubernetes worker |

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
- `paperless.lab`
- `grafana.lab`
- `jellyfin.lab`
- `seerr.lab`
- `sonarr.lab`
- `radarr.lab`
- `prowlarr.lab`
- `bazarr.lab`
- `homeassistant.lab`

Ruch HTTP do paneli przechodzi przez `proxy-01`. Pierwsza wersja świadomie nie
konfiguruje TLS; usługi są przeznaczone wyłącznie dla zaufanego LAN-u.

Porty `9100` (node_exporter) i `8081` (cAdvisor) są otwarte wyłącznie dla
`monitor-01`. Grafana na porcie `3000` przyjmuje ruch wyłącznie z `proxy-01`;
Prometheus i eksportery centralne nie mają publicznych tras w Traefiku.
