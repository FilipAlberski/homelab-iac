# Home Assistant OS i Zigbee

Home Assistant działa jako osobna maszyna HAOS na Proxmoxie. Nie jest to
kontener Docker ani klon szablonu Rocky Linux.

| Parametr | Wartość |
|---|---|
| VM / VMID | `homeassistant-01` / `147` |
| Docelowy adres | `192.168.60.147/24` |
| MAC | `BC:24:11:00:01:47` |
| CPU / RAM / dysk | 2 vCPU / 4 GiB / 64 GiB |
| Dysk | `tank-zfs` |
| Panel bezpośredni | `http://192.168.60.147` |

VM startuje automatycznie po Proxmoxie i jest chroniona zarówno flagą
`protection` w Proxmoxie, jak i `prevent_destroy` w Terraformie. HAOS aktualizuje
się z własnego panelu. Podniesienie bazowej wersji obrazu w Terraformie nie jest
normalną metodą aktualizacji już utworzonej maszyny.

## SMLIGHT SLZB-06P10

Bramka pozostaje urządzeniem sieciowym PoE na MikroTiku; nie wymaga USB
passthrough do Proxmoxa. Dla stabilności należy nadać jej rezerwację DHCP albo
statyczny adres poza pulą DHCP.

Konfiguracja ZHA dla tego modelu:

- typ radia: `ZNP` (Texas Instruments Z-Stack),
- adres portu: `socket://<IP-SMLIGHT>:6638`,
- prędkość: `115200`,
- sterowanie przepływem: brak,
- tryb SLZB: Zigbee Coordinator oraz Zigbee-to-Ethernet.

Jednocześnie tylko jedna usługa może sterować koordynatorem. Nie uruchamiaj
Zigbee2MQTT i ZHA na tym samym porcie. Przy świeżej instalacji ZHA wybierz
utworzenie nowej sieci. Jeśli bramka zawiera istniejącą sieć Zigbee, najpierw
wykonaj jej kopię i nie kasuj ustawień radia.

## Kopie zapasowe

W Home Assistant włącz automatyczne kopie zapasowe i przechowuj co najmniej
jedną kopię poza dyskiem VM. Snapshot Proxmoxa jest wygodny przed zmianami, ale
nie zastępuje kopii HAOS przechowywanej na innym nośniku.
