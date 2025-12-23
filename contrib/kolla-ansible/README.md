# OVS Exporter for Kolla-Ansible Deployments

This directory contains configuration files to run ovs-exporter with OpenStack deployments managed by Kolla-Ansible.

## Problem

Kolla-Ansible deploys OVS components (vswitchd, ovsdb-server, ovn-controller) in Docker containers. The default ovs-exporter configuration expects these components to be running on the host with standard paths. This guide explains how to configure both Kolla and ovs-exporter to work together.

## Changes Required

### 1. Configure Kolla-Ansible to Expose /run/ovn

OVN controller keeps its socket, control, and PID files in `/run/ovn/` inside the container. To allow the exporter (running on the host) to access these files, configure Kolla to mount this directory.

Copy `ovs-exporter.yml` to your Kolla configuration:

```bash
cp ovs-exporter.yml /etc/kolla/globals.d/ovs-exporter.yml
```

Or add to your existing `group_vars/all.yml`:

```yaml
ovn_controller_extra_volumes:
  - "/run/ovn:/run/ovn:rw"
```

Then reconfigure the OVN containers:

```bash
kolla-ansible -i inventory reconfigure -t ovn
```

### 2. Install the Exporter

Download and extract the exporter binary:

```bash
wget https://github.com/lucadelmonte/ovs_exporter/releases/download/v2.4.1/ovs-exporter-2.4.0.linux-amd64.tar.gz
tar -xzf ovs-exporter-2.4.0.linux-amd64.tar.gz
cd ovs-exporter-2.4.0.linux-amd64
```

Run the installation script to install the binary and default systemd service:

```bash
sudo ./install.sh
```

### 3. Configure for Kolla-Ansible

Download and install the environment file with Kolla-specific paths:

```bash
# For RHEL/CentOS
sudo wget -O /etc/sysconfig/ovs-exporter https://raw.githubusercontent.com/lucadelmonte/ovs_exporter/v2.4.1/contrib/kolla-ansible/ovs-exporter.env

# For Debian/Ubuntu
sudo wget -O /etc/default/ovs-exporter https://raw.githubusercontent.com/lucadelmonte/ovs_exporter/v2.4.1/contrib/kolla-ansible/ovs-exporter.env
```

Download and install systemd drop-in override for Kolla container dependencies:

```bash
sudo mkdir -p /etc/systemd/system/ovs-exporter.service.d/
sudo wget -O /etc/systemd/system/ovs-exporter.service.d/ovs-exporter-kolla.conf https://raw.githubusercontent.com/lucadelmonte/ovs_exporter/v2.4.1/contrib/kolla-ansible/ovs-exporter-kolla.conf
```

### 4. Start the Service

```bash
sudo systemctl daemon-reload
sudo systemctl enable ovs-exporter
sudo systemctl start ovs-exporter
```

### 5. Verify

```bash
# Check service status
systemctl status ovs-exporter

# Check metrics
curl -s http://localhost:9475/metrics | head -20

# Count available metrics
curl -s http://localhost:9475/metrics | wc -l
```

## Path Mapping Reference

| Component | Default Path | Kolla Path |
|-----------|--------------|------------|
| OVS socket | `unix:/var/run/openvswitch/db.sock` | `unix:/var/run/openvswitch/db.sock` ✓ |
| OVS data | `/etc/openvswitch/conf.db` | `/var/lib/docker/volumes/openvswitch_db/_data/conf.db` |
| OVS log | `/var/log/openvswitch/ovsdb-server.log` | `/var/log/kolla/openvswitch/ovsdb-server.log` |
| OVS PID | `/var/run/openvswitch/ovsdb-server.pid` | `/var/run/openvswitch/ovsdb-server.pid` ✓ |
| vswitchd log | `/var/log/openvswitch/ovs-vswitchd.log` | `/var/log/kolla/openvswitch/ovs-vswitchd.log` |
| vswitchd PID | `/var/run/openvswitch/ovs-vswitchd.pid` | `/var/run/openvswitch/ovs-vswitchd.pid` ✓ |
| ovn-controller log | `/var/log/openvswitch/ovn-controller.log` | `/var/log/kolla/openvswitch/ovn-controller.log` |
| ovn-controller PID | `/var/run/openvswitch/ovn-controller.pid` | `/var/run/openvswitch/ovn-controller/ovn-controller.pid` |

## Deployment Notes

### Compute Nodes vs Network Nodes

- **ovs-exporter** → Deploy on **compute nodes** (hypervisors running VMs)
  - Monitors local OVS bridges, flows, and ovn-controller
  - Port: 9475

- **ovn-exporter** → Deploy on **network/controller nodes** (OVN central)
  - Monitors OVN northbound/southbound databases and northd
  - Port: 9476

Both exporters complement each other for complete OVN/OVS visibility.

## Notes

- System information (type, version, hostname) is automatically detected from `/etc/os-release` and OVS database
- The systemd unit depends on `kolla-openvswitch_db-container.service` (required)
- OVN controller metrics require the PID file to be accessible
- Metrics are exposed on port 9475 by default
