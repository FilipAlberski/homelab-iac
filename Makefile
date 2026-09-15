SHELL := /bin/bash

TF_DIR := terraform/prod
ANSIBLE_DIR := ansible
PLAYBOOK := ansible-playbook
VAULT_ARGS := $(if $(wildcard $(ANSIBLE_DIR)/.vault_pass),--vault-password-file .vault_pass,)

.DEFAULT_GOAL := help

.PHONY: help init fmt validate plan apply output deps ping users bootstrap site backups vault-init check

help:
	@echo "Dostępne polecenia:"
	@echo "  make init       - pobierz provider Terraform"
	@echo "  make plan       - pokaż plan zmian VM"
	@echo "  make apply      - zastosuj zatwierdzony plan"
	@echo "  make deps       - zainstaluj kolekcje Ansible"
	@echo "  make ping       - sprawdź dostęp SSH do VM"
	@echo "  make users      - utwórz i zaktualizuj konta administracyjne"
	@echo "  make bootstrap  - skonfiguruj Rocky i Docker"
	@echo "  make site       - wdróż cały homelab"
	@echo "  make backups    - wdróż backupy VM i Paperless oraz ich monitoring"
	@echo "  make vault-init - utwórz zaszyfrowany plik sekretów"
	@echo "  make check      - sprawdź Terraform i Ansible"

init:
	terraform -chdir=$(TF_DIR) init

fmt:
	terraform fmt -recursive terraform

validate:
	terraform -chdir=$(TF_DIR) validate

plan:
	terraform -chdir=$(TF_DIR) plan -out=homelab.tfplan

apply:
	@test -f $(TF_DIR)/homelab.tfplan || (echo "Najpierw uruchom make plan."; exit 1)
	terraform -chdir=$(TF_DIR) apply homelab.tfplan

output:
	terraform -chdir=$(TF_DIR) output

deps:
	cd $(ANSIBLE_DIR) && ansible-galaxy collection install -r requirements.yml

ping:
	cd $(ANSIBLE_DIR) && ansible all $(VAULT_ARGS) -m ping

users:
	cd $(ANSIBLE_DIR) && $(PLAYBOOK) $(VAULT_ARGS) playbooks/users.yml

bootstrap:
	cd $(ANSIBLE_DIR) && $(PLAYBOOK) $(VAULT_ARGS) playbooks/bootstrap.yml

site:
	cd $(ANSIBLE_DIR) && $(PLAYBOOK) $(VAULT_ARGS) playbooks/site.yml

backups:
	cd $(ANSIBLE_DIR) && $(PLAYBOOK) $(VAULT_ARGS) playbooks/deploy-backups.yml

vault-init:
	@test -f $(ANSIBLE_DIR)/.vault_pass || (echo "Najpierw utwórz ansible/.vault_pass z prawami 0600."; exit 1)
	@test ! -e $(ANSIBLE_DIR)/inventory/group_vars/all/vault.yml || (echo "ansible/inventory/group_vars/all/vault.yml już istnieje."; exit 1)
	cd $(ANSIBLE_DIR) && ansible-vault create --vault-password-file .vault_pass inventory/group_vars/all/vault.yml

check:
	terraform fmt -check -recursive terraform
	terraform -chdir=$(TF_DIR) validate
	cd $(ANSIBLE_DIR) && $(PLAYBOOK) $(VAULT_ARGS) playbooks/site.yml --syntax-check
