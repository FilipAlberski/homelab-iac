# Home Assistant

## Architecture

Home Assistant runs as a dedicated Home Assistant OS VM rather than a Docker
container on one of the Rocky Linux hosts. This keeps Supervisor, apps,
updates, backups, USB coordinators, and local discovery inside the supported
Home Assistant appliance model.

| Setting | Value |
|---------|-------|
| VM | `homeassistant-01` |
| VMID | `147` |
| Address | `192.168.60.147` |
| DHCP MAC | `02:00:00:00:00:93` |
| Resources | 2 vCPU, 4 GB RAM, 64 GB disk |
| Firmware | q35 with OVMF/UEFI |
| URL | `http://homeassistant.lab:8123` |

The VM is protected in Proxmox. To intentionally remove it, disable the
`protection` setting in Terraform and apply that change before destroying the
resource.

## First Deployment

1. Confirm that `192.168.60.147` is unused. Optionally reserve it for
   `02:00:00:00:00:93` in DHCP; this makes the address deterministic even
   before HAOS receives its static configuration.
2. Confirm that `proxmox_ssh_private_key_file` points at the key that can
   connect to `root@192.168.60.10` (the default is `~/.ssh/id_ed25519`).
   Terraform reads this key only while importing the compressed HAOS image; the
   key contents are not stored in the repository or Terraform state.
3. Review the full plan carefully, then create the VM:

   ```bash
   make plan
   make apply
   ```

4. Wait until Supervisor finishes the initial setup, then configure the static
   address inside HAOS:

   ```bash
   make homeassistant-network
   ```

5. Deploy the internal DNS record and Homepage/monitoring integrations:

   ```bash
   make dns
   make apps
   make monitoring
   ```

6. Wait several minutes for the initial Home Assistant preparation, then open
   `http://homeassistant.lab:8123`. If DNS has not refreshed yet, use
   `http://192.168.60.147:8123`.
7. Complete onboarding and set the time zone to `Europe/Warsaw`.

The pinned `home_assistant_os_version` is only the seed image for a new VM.
Update Home Assistant OS, Supervisor, Core, and apps from the Home Assistant UI.
Changing the Terraform image version is not the update path for an existing
installation and may propose replacing its disk.

## USB Coordinators

For a Zigbee, Z-Wave, Thread, or Bluetooth USB adapter, first create a stable
USB resource mapping in Proxmox under **Datacenter -> Resource Mappings**. Add
its mapping name to `terraform.tfvars`, for example:

```hcl
home_assistant_usb_mappings = ["zigbee-coordinator"]
```

Review and apply the Terraform plan. Prefer a mapping based on the USB device's
vendor/product identity or physical port rather than a transient bus/device
number.

## Backup And Recovery

- Enable automatic Home Assistant backups and copy them to storage outside the
  VM, such as a NAS. A backup stored only on the VM does not protect against a
  lost virtual disk.
- Include VM 147 in the Proxmox/PBS backup schedule. Application backups are
  the primary portable recovery method; the VM backup is a fast whole-machine
  fallback.
- Create an on-demand Home Assistant backup before major Core, OS, or app
  updates and before changing USB coordinators.
- Test restoring a Home Assistant backup to a disposable VM before relying on
  it for disaster recovery.
