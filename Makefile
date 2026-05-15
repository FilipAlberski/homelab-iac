SHELL := /usr/bin/env bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

ENV          ?= prod
TF_DIR       := terraform/environments/$(ENV)
ANSIBLE_DIR  := ansible
INVENTORY    := $(ANSIBLE_DIR)/inventories/$(ENV)/hosts.generated
PVE          ?= root@192.168.40.10

TF       := terraform -chdir=$(TF_DIR)
ANSIBLE  := cd $(ANSIBLE_DIR) && ansible-playbook -i inventories/$(ENV)/hosts.generated

.DEFAULT_GOAL := help

##@ Help
.PHONY: help
help:  ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make \033[36m<target>\033[0m\n"} \
	/^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 } \
	/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

##@ Setup (Proxmox host)
.PHONY: datastore
datastore: ## Create datav1 storage on Proxmox host (idempotent)
	@ssh $(PVE) 'pvesm list datav1 > /dev/null 2>&1 || pvesm add dir datav1 --path /mnt/pve/datav1 --content images,backup'
	@ssh $(PVE) 'grep -q datav1 /etc/fstab || echo "/dev/sda1 /mnt/pve/datav1 ext4 defaults 0 0" >> /etc/fstab'
	@ssh $(PVE) 'pvesm status | grep datav1 || true'
	@echo "✓ datav1 storage is ready"

##@ Terraform
.PHONY: init fmt validate plan apply destroy output
init:      ## terraform init
	$(TF) init

fmt:       ## terraform fmt -recursive
	terraform fmt -recursive terraform/

validate:  ## terraform validate
	$(TF) validate

plan:      ## terraform plan
	$(TF) plan

apply:     ## terraform apply
	$(TF) apply

destroy:   ## terraform destroy
	$(TF) destroy

output:    ## terraform output
	$(TF) output

##@ Ansible
.PHONY: inventory ping update update-check lint dns proxy apps paperless update-apps
inventory: ## Regenerate Ansible inventory from Terraform output
	@mkdir -p $(dir $(INVENTORY))
	$(TF) output -raw ansible_inventory > $(INVENTORY)
	@echo "✓ wrote $(INVENTORY)"
	@cat $(INVENTORY)

ping:      ## Ansible ping all hosts
	$(ANSIBLE) playbooks/ping.yml

update:    ## Run system updates (reboot if needed)
	$(ANSIBLE) playbooks/update.yml

update-check: ## Dry-run system updates
	$(ANSIBLE) playbooks/update.yml --check --diff

dns:       ## Deploy Pi-hole on dns hosts
	$(ANSIBLE) playbooks/dns.yml

proxy:     ## Deploy Traefik on proxy hosts
	$(ANSIBLE) playbooks/proxy.yml

apps:      ## Deploy apps on app-01
	$(ANSIBLE) playbooks/apps.yml

games:     ## Deploy Valheim server on games-01
	$(ANSIBLE) playbooks/games.yml

monitor:   ## Deploy monitoring stack on monitor-01
	$(ANSIBLE) playbooks/monitor.yml

monitor-agents: ## Deploy monitoring agents on all hosts
	$(ANSIBLE) playbooks/monitor-agents.yml

resize:    ## Resize root filesystem on all VMs (LVM growpart)
	$(ANSIBLE) playbooks/resize.yml

paperless: ## Deploy Paperless-ngx on app-01
	$(ANSIBLE) playbooks/paperless.yml

update-apps: ## Pull latest images & recreate app containers
	$(ANSIBLE) playbooks/update-apps.yml

lint:      ## Lint Terraform + Ansible playbooks
	terraform fmt -check -recursive terraform/
	$(TF) validate
	cd $(ANSIBLE_DIR) && ansible-lint playbooks/

##@ Lifecycle
.PHONY: up
up: apply inventory ping  ## apply -> regenerate inventory -> ping
