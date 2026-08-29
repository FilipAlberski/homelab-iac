# Demo Hosting

## Outcome

`public-02` publishes static website builds at
`https://<slug>.demo.alberski.pl` with one deployment command. A single
wildcard DNS record, Cloudflare route and edge certificate cover every slug.
No per-demo DNS record, Traefik route, TLS certificate or container is needed.

The environment is deliberately separate from `public-01`:

- a dedicated Proxmox VM (`192.168.60.146`);
- a dedicated remotely managed Cloudflare Tunnel and vault token;
- a dedicated `demo-proxy` Docker network;
- a dedicated Traefik instance, site storage and lifecycle timer;
- no published HTTP or HTTPS host ports.

Cloudflare terminates public HTTPS and sends origin HTTP through the encrypted
outbound tunnel. Traefik never requests certificates itself.

## One-Time Setup

### 1. Provision the VM

Review the Terraform plan because VM catalog changes can be destructive:

```bash
make plan
make apply
make inventory
make ping
```

### 2. Create the Cloudflare edge resources

The repository's existing Cloudflare model is dashboard-managed rather than a
Terraform provider, so this environment follows the same model instead of
introducing a second source of truth.

In Cloudflare:

1. Create a remotely managed tunnel dedicated to `public-02`.
2. Add the public hostname `*.demo.alberski.pl` with origin service
   `http://traefik:80`.
3. Verify that the resulting proxied wildcard CNAME points to this tunnel, not
   the `public-01` tunnel.
4. Order an Advanced edge certificate whose SANs include
   `alberski.pl` and `*.demo.alberski.pl`, then wait for it to become active.

Cloudflare Universal SSL in a full DNS setup covers the zone apex and only
first-level names such as `demo.alberski.pl`. It does not cover the required
second-level names such as `firma.demo.alberski.pl`. Total TLS also does not
issue certificates for Cloudflare Tunnel hostnames. The explicit advanced
wildcard certificate is therefore a prerequisite for this hostname scheme.
See Cloudflare's documentation for
[Universal SSL hostname coverage](https://developers.cloudflare.com/ssl/edge-certificates/universal-ssl/limitations/),
[Advanced wildcard certificates](https://developers.cloudflare.com/ssl/edge-certificates/advanced-certificate-manager/),
and the [Total TLS tunnel limitation](https://developers.cloudflare.com/ssl/edge-certificates/additional-options/total-tls/).

Do not add `demo.alberski.pl` or its wildcard to the `public-01` tunnel.

### 3. Store the dedicated token

Edit the encrypted production vault:

```bash
cd ansible
ansible-vault edit inventories/prod/group_vars/all/vault.yml
```

Add:

```yaml
vault_demo_cloudflared_tunnel_token: REPLACE_WITH_PUBLIC_02_TOKEN
```

Never reuse `vault_cloudflared_tunnel_token` from `public-01`, and do not put a
token in an unencrypted variables file.

### 4. Reconcile services and monitoring

```bash
make demo
make monitoring
```

`make site` also deploys both public edges before monitoring agents, so a fresh
rebuild can use the full desired-state entrypoint.

## Publish A Static Demo

Build the project using its own frontend tooling, then point the deployment at
the resulting directory. It must contain `index.html`.

```bash
make demo-deploy \
  SLUG=kowalski-hydraulika \
  SOURCE=../kowalski-hydraulika/dist \
  SOURCE_REPO=https://git.example/kowalski-hydraulika
```

The command uploads an immutable release, switches the `current` symlink
atomically, writes lifecycle metadata and prints:

```text
https://kowalski-hydraulika.demo.alberski.pl
```

Redeploying the same slug replaces it without downtime. To change the default
30-day lifetime:

```bash
make demo-deploy SLUG=firma-a SOURCE=../firma-a/dist TTL_DAYS=60
```

Allowed slugs use lowercase ASCII letters, digits and internal hyphens. This
keeps host routing and filesystem paths unambiguous.

## Lifecycle

Each demo stores `created_at`, `deployed_at`, `expires_at`, `status`, release ID,
URL and optional source repository in `/srv/demos/<slug>/metadata.json`.

```bash
make demo-list
make demo-status SLUG=firma-a STATUS=inactive
make demo-status SLUG=firma-a STATUS=active
make demo-status SLUG=firma-a STATUS=sold
make demo-status SLUG=firma-a STATUS=lost
```

A systemd timer runs daily. It deactivates demos after `expires_at`; inactive
URLs show a neutral unavailable page. Release data for a non-active demo is
removed after seven days, while metadata remains for later CRM integration.
Redeploy from the source repository to restore an expired or cleaned site.

Marking a demo `sold` intentionally takes the preview offline. The same static
artifact can then be deployed by the client's normal hosting workflow and
domain, without application changes tied to `demo.alberski.pl`.

## Search Safety And Demo Disclosure

Controls are applied at the shared edge and therefore cannot be omitted by an
individual project:

- every response gets `X-Robots-Tag: noindex, nofollow, noarchive, nosnippet,
  noimageindex`;
- `/robots.txt` always returns `Disallow: /`;
- HTML responses receive a small fixed notice that the page is an unofficial
  demonstration;
- only `GET` and `HEAD` are accepted by the static backend;
- dotfiles are never served;
- responses use `Cache-Control: no-store`, so a redeploy is not masked by a
  stale Cloudflare or browser cache;
- Cloudflare hides the origin and provides its normal DDoS/WAF edge controls.

These measures strongly discourage indexing but cannot make a public URL
secret. For an unusually sensitive demo, add a dedicated Cloudflare Access
policy rather than enabling Basic Auth for every customer link.

## Monitoring

The existing Grafana/Prometheus/Loki/Alertmanager stack covers:

- host availability, CPU, RAM, filesystem space and inode exhaustion;
- Docker and system logs through Alloy;
- Cloudflare Tunnel connection count;
- Traefik metric availability;
- Traefik's active health check of the shared Nginx backend.

Relevant alerts are `HostTelemetryStale`, `HostDiskLowSpace`,
`HostDiskCritical`, `HostMemoryHigh`, `HostUnreachable`,
`DemoCloudflareTunnelDown`, `DemoTraefikDown` and `DemoStaticBackendDown`.

## Custom Runtime Projects

Static output is the default because it is cheapest and isolates deployments
from one another at the filesystem level. A project that genuinely needs a
server runtime can use a dedicated Compose stack on `public-02`, join the
external `demo-proxy` network, and add its own YAML route under
`/opt/demo-platform/traefik/dynamic/`. Traefik watches that directory.

Set explicit CPU and memory limits for custom runtime containers. Static demos
cannot execute on the server, but an unconstrained custom process could compete
with the shared proxy and static backend.

Keep such a route and Compose definition in the project's source repository or
add a dedicated Ansible role here. Do not mount the Docker socket into Traefik;
the file provider keeps container discovery and control explicit.

## Recovery

The VM is disposable. To rebuild it:

1. recreate `public-02` through Terraform;
2. regenerate inventory and run `make demo` followed by `make monitoring`;
3. redeploy active projects from their source repositories with
   `make demo-deploy`.

No HA or content backup is required for demos. The infrastructure, lifecycle
controller and platform configuration live in this repository; project content
must remain in its project repository or another reproducible artifact source.
