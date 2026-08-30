# Network

## Topology

The home network uses a MikroTik Chateau 5G behind an Orange FunBox 6. This
is intentionally a double-NAT layout:

```text
Internet
   |
Orange FunBox 6
  192.168.40.1/24
   |
MikroTik ether1 (DHCP: 192.168.40.151)
  primary WAN: Orange Ethernet
  backup WAN:  LTE/5G modem
   |
MikroTik ether2
   |
Proxmox vmbr0 — 192.168.60.10/24
```

`ether2` is connected directly to the Proxmox Dell Micro; there is currently
no physical switch. The port belongs to `bridge-homelab`.

## WAN and failover

- Orange/FunBox is the primary path in the MikroTik `main` routing table.
- The Orange default route has distance `1`.
- The LTE modem default route has distance `2` and is used automatically when
  the Orange route disappears.
- The MikroTik performs source masquerading towards both WAN interfaces.
- The FunBox performs the outer NAT, so inbound connections need to account
  for both the FunBox and MikroTik layers.

Under normal conditions, `NEXUS-MAIN`, `NEXUS-GUEST`, and `NEXUS-IOT` use
Orange Ethernet. They can fall back to LTE when Orange is unavailable.

## Networks and SSIDs

| SSID / purpose | MikroTik bridge | Subnet | Gateway/DNS | WAN policy |
|---|---|---:|---:|---|
| `NEXUS-MAIN` | `bridge` | `10.10.10.0/24` | `10.10.10.1`; DNS `192.168.60.141`, fallback `10.10.10.1` | Orange, then LTE failover |
| `NEXUS-IOT` | `bridge-iot` | `192.168.20.0/24` | `192.168.20.1` | Orange, then LTE failover |
| `NEXUS-GUEST` | `bridge-guest` | `192.168.30.0/24` | `192.168.30.1` | Orange, then LTE failover |
| `NEXUS-LTE`* | `bridge-lte` | `192.168.70.0/24` | `192.168.70.1` | LTE only |
| Homelab Ethernet | `bridge-homelab` | `192.168.60.0/24` | `192.168.60.1` | Orange, then LTE failover |

\* The LTE-only SSID is intended to be named `NEXUS-LTE-BACKUP`. Renaming the
SSID does not change its bridge or routing policy.

The physical radios are shared by the virtual access points:

- `NEXUS-MAIN`: 2.4 GHz and 5 GHz
- `NEXUS-IOT`: 2.4 GHz only
- `NEXUS-GUEST`: 2.4 GHz and 5 GHz
- LTE-only SSID: 2.4 GHz and 5 GHz

The logical segmentation is implemented with MikroTik bridges and virtual WiFi
interfaces, not VLANs. Guest and LTE virtual APs have client isolation enabled.

## LTE-only policy

Traffic sourced from `192.168.70.0/24` uses the dedicated `lte-only` routing
table. That table contains:

- a connected route for `192.168.70.0/24` via `bridge-lte`;
- a default route via `lte1`;
- a routing rule matching source `192.168.70.0/24`.

This keeps the LTE-only SSID on the modem even while Orange Ethernet is
healthy. Other networks use the normal `main` table.

## Firewall and DNS access

- MikroTik DNS remote requests are enabled for the local networks.
- Each segmented WiFi network is allowed to obtain DHCP and use DNS on its
  MikroTik gateway.
- `NEXUS-PRIVATE` contains RFC1918 address space and is used to isolate IoT,
  guest, and LTE-only clients from private networks.
- IoT is allowed to reach Home Assistant at `192.168.60.147:8123`.
- IoT, guest, and LTE-only clients are allowed to reach Pi-hole DNS at
  `192.168.60.141:53` over UDP and TCP.
- `NEXUS-MAIN` DHCP advertises Pi-hole (`192.168.60.141`) as the primary DNS
  and the MikroTik gateway (`10.10.10.1`) as the fallback resolver.

The MikroTik gateway remains the advertised DNS server for the other segmented
DHCP networks unless their DHCP DNS option is changed to Pi-hole. Pi-hole
access is explicitly permitted for clients or services that use it directly.

## Homelab addressing

Proxmox and the current VM catalog use `192.168.60.0/24`; the VM last octet
matches its VMID. The main addresses are documented in `architecture.md`.

The old `bridge-wan` / `192.168.50.0/24` configuration is legacy and is not
part of the target homelab path. It should be removed after confirming that no
remaining device depends on it.

## Useful checks

On the MikroTik:

```routeros
/ip dhcp-client print detail
/ip route print where dst-address=0.0.0.0/0
/interface ethernet monitor ether1 once
/interface ethernet monitor ether2 once
```

Expected WAN state while Orange is online:

```text
default via 192.168.40.1 distance 1
default via lte1 distance 2
```
