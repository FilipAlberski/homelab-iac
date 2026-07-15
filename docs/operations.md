# Operations

## Provision Or Reconcile Infrastructure

```bash
make plan
make apply
make inventory
make ping
```

## Bootstrap Hosts

```bash
make bootstrap
```

This applies common OS configuration, grows disks, and installs Docker on hosts tagged with `docker`.

## Deploy Everything

```bash
make site
```

## Deploy Individual Services

```bash
make dns
make proxy
make apps
make monitoring
make paperless
make seafile
make actual
make games
make update-apps
```

`make update-apps` pulls and recreates the Uptime Kuma, Portainer, Homepage,
Paperless-ngx, Actual Budget, and Seafile Compose stacks on `app-01`.

## Game Server

The 7 Days to Die server runs on `games-01` from the `vinanrra/7dtd-server` container image.

Useful endpoints:

- Server DNS: `7dtd.lab`
- Game port: `26900/tcp` and `26900/udp`
- Query ports: `26901/udp`, `26902/udp`

## Validation

```bash
make fmt
make validate
cd ansible && ansible-playbook -i inventories/prod/hosts.generated playbooks/site.yml --syntax-check
cd ansible && ansible-lint playbooks/
```
