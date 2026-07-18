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
make public
make paperless
make seafile
make actual
make games
make update-apps
```

`make update-apps` pulls and recreates the Uptime Kuma, Portainer, Homepage,
Paperless-ngx, Actual Budget, and Seafile Compose stacks on `app-01`.

## Deploy Public Web Edge

First create a remotely managed Cloudflare Tunnel and public hostnames for
`alberski.pl` and `*.alberski.pl`, both pointing to `http://traefik:80`.
Store the tunnel token in the encrypted production vault as
`vault_cloudflared_tunnel_token`, then run:

```bash
make public
```

The public edge does not expose host ports. The starter website in
`sites/coming-soon` is deployed directly to `public-01` as an Nginx Docker
container and is available at `alberski.pl` and `blog.alberski.pl`. Its
container joins `public-proxy`; Traefik routes both hostnames to it.

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
