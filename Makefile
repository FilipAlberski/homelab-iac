SHELL := /usr/bin/env bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

ENV          ?= prod
TF_DIR       := terraform/environments/$(ENV)
ANSIBLE_DIR  := ansible
INVENTORY    := $(ANSIBLE_DIR)/inventories/$(ENV)/hosts.generated

TF       := terraform -chdir=$(TF_DIR)
ANSIBLE  := cd $(ANSIBLE_DIR) && ansible-playbook -i inventories/$(ENV)/hosts.generated

.DEFAULT_GOAL := help

##@ Help
.PHONY: help
help:  ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make \033[36m<target>\033[0m\n"} \
	/^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 } \
	/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

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
.PHONY: inventory ping update update-check lint dns proxy
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

lint:      ## Lint Terraform + Ansible playbooks
	terraform fmt -check -recursive terraform/
	$(TF) validate
	cd $(ANSIBLE_DIR) && ansible-lint playbooks/

##@ Lifecycle
.PHONY: up
up: apply inventory ping  ## apply -> regenerate inventory -> ping
