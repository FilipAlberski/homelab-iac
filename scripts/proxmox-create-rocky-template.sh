#!/usr/bin/env bash
# Create Rocky 10 cloud-init template on Proxmox (run as root on PVE node)
set -euo pipefail

VMID="${1:-9001}"
NAME="${2:-rocky10-cloud-template}"
STORAGE="${3:-local-lvm}"
IMAGE_URL="https://dl.rockylinux.org/pub/rocky/10/images/x86_64/Rocky-10-GenericCloud-Base.latest.x86_64.qcow2"
TMP_IMAGE="/tmp/rocky10-cloud.qcow2"

echo "==> Downloading Rocky 10 cloud image..."
rm -f "$TMP_IMAGE"
wget -q --show-progress -O "$TMP_IMAGE" "$IMAGE_URL" || {
  echo "wget failed, trying curl..."
  curl -L -o "$TMP_IMAGE" "$IMAGE_URL"
}

echo "==> Creating VM ${VMID} (${NAME})..."
qm create "$VMID" \
  --name "$NAME" \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \
  --agent enabled=1

echo "==> Importing disk to ${STORAGE}..."
qm set "$VMID" --virtio0 "${STORAGE}:0,import-from=${TMP_IMAGE}"

echo "==> Attaching cloud-init drive..."
qm set "$VMID" --ide2 "${STORAGE}:cloudinit"

echo "==> Configuring boot & serial..."
qm set "$VMID" --boot order=virtio0
qm set "$VMID" --serial0 socket --vga serial0

echo "==> Converting to template..."
qm template "$VMID"

echo "==> Cleaning up..."
rm -f "$TMP_IMAGE"

echo "✓ Template ${VMID} (${NAME}) ready on ${STORAGE}."
echo "  Update your terraform.tfvars: template_id = ${VMID}"
