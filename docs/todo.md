# Homelab TODO

- [ ] Skonfigurować grupy Pi-hole: mocne listy dla `NEXUS-MAIN`
    (`10.10.10.0/24`) oraz brak blokad dla `NEXUS-GUEST`
    (`192.168.30.0/24`). Opcjonalnie przygotować osobną, umiarkowaną grupę
    dla `NEXUS-IOT` (`192.168.20.0/24`).
- [ ] Po przywróceniu SSH do `dns-01` uruchomić `make dns` i sprawdzić,
    czy na hoście nie został katalog/kontener `/opt/alloy`.
