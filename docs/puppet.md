# Puppet

## Current topology

| Component | Host | Address | Role |
|---|---|---:|---|
| Puppet Server / CA | `puppet-01` | `192.168.60.148` (`puppet.lab`) | Catalog compiler and certificate authority |
| Puppet agent | `monitoring-01` | `192.168.60.144` | First managed node |

Puppet Server listens on TCP port `8140`. The port is allowed in the
`public` firewalld zone on `puppet-01`.

## Versions in the lab

- Puppet Server: `8.7.0`
- Puppet agent: `8.10.0`
- Java: OpenJDK `17.0.20.1`

The lab currently uses the public Puppet 8 EL9 RPMs on Rocky Linux 10. This
is a compatibility choice for testing. Puppet Core 9 is the supported path
for Rocky Linux 10, but its package repository requires a Puppet Forge API
key.

## Agent provisioning

`monitoring-01` is enabled with `puppet_agent_enabled = true` in
`terraform/environments/prod/vms.tf`. Terraform uploads a cloud-init snippet
and attaches it to the VM. On first boot the snippet:

1. installs the pinned Puppet agent RPM;
2. configures `puppet.lab` as the Puppet Server;
3. configures Pi-hole (`192.168.60.141`) as the primary resolver;
4. enables and starts the Puppet service.

The reusable snippet is at
`terraform/environments/prod/templates/puppet-agent-cloud-config.yaml.tftpl`.

## Certificate workflow

New agents request a certificate automatically. On the CA host, inspect and
sign requests with:

```text
sudo /opt/puppetlabs/bin/puppetserver ca list --all
sudo /opt/puppetlabs/bin/puppetserver ca sign --certname <agent-certname>
```

Then test the agent:

```text
sudo /opt/puppetlabs/bin/puppet agent --test --color=false
```

The initial `site.pp` is intentionally empty, so the first successful run
only verifies connectivity, certificate trust, catalog compilation, and
agent execution. Puppet code can be added later under
`/etc/puppetlabs/code/environments/production` on `puppet-01`.

Ansible remains in the repository and continues to manage the existing
service fleet during the migration.
