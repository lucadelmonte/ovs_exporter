# Open Virtual Switch (OVS) Exporter

<a href="https://github.com/Liquescent-Development/ovs_exporter/actions/" target="_blank"><img src="https://github.com/Liquescent-Development/ovs_exporter/workflows/build/badge.svg?branch=main"></a>

A Prometheus exporter for Open Virtual Switch (OVS) that provides comprehensive metrics from OVS and OVN components, including advanced DPDK/PMD performance metrics.

> **Note**: This is an enhanced fork of the original [greenpau/ovs_exporter](https://github.com/greenpau/ovs_exporter) with significant improvements including:
> - Updated to Go 1.24 with modernized dependencies
> - Comprehensive PMD/DPDK performance metrics
> - Prometheus naming convention compliance
> - System ID retrieval from OVS database (no config file required)
> - Flow cache performance metrics
> - Detailed drop statistics
> - Security updates and vulnerability fixes

## Table of Contents

- [Features](#features)
- [Installation](#installation)
  - [Binary Installation](#binary-installation)
  - [Building from Source](#building-from-source)
  - [Docker](#docker)
- [Configuration](#configuration)
- [Metrics](#metrics)
- [Example Queries](#example-queries)
  - [Multi-Tenant Monitoring](#multi-tenant-monitoring)
- [Grafana Dashboards](#grafana-dashboards)
- [Troubleshooting](#troubleshooting)
- [Development](#development)

## Features

- **Comprehensive Metrics**: Exports 100+ metrics from OVS components
- **DPDK/PMD Support**: Advanced performance metrics for DPDK deployments
- **Auto-Discovery**: Automatically retrieves system ID from OVS database
- **Multi-Tenant Ready**: Supports external IDs for tenant association
- **Production Ready**: Battle-tested in large-scale deployments
- **Low Overhead**: Efficient polling with configurable intervals
- **Prometheus Compliant**: Follows official naming conventions

## Installation

### Binary Installation

Download the latest release for your architecture:

```bash
# Linux AMD64
wget https://github.com/Liquescent-Development/ovs_exporter/releases/download/v2.6.0/ovs-exporter-2.6.0.linux-amd64.tar.gz
tar xvzf ovs-exporter-2.6.0.linux-amd64.tar.gz

# Linux ARM64
wget https://github.com/Liquescent-Development/ovs_exporter/releases/download/v2.6.0/ovs-exporter-2.6.0.linux-arm64.tar.gz
tar xvzf ovs-exporter-2.6.0.linux-arm64.tar.gz
```

Install as a systemd service:

```bash
cd ovs-exporter-*
sudo ./install.sh
systemctl status ovs-exporter
```

The install script will:
- Automatically detect system architecture (amd64/arm64)
- Build the binary if not present (requires Go and Make)
- Create an `ovs_exporter` user and group
- Install the binary to `/usr/sbin/ovs-exporter`
- Set up systemd service with proper capabilities
- Configure permissions for OVS socket access
- Optionally configure remote syslog forwarding

#### Remote Syslog Configuration

The install script supports forwarding logs to a remote syslog server:

```bash
# Forward logs via UDP (default)
sudo ./install.sh --syslog-server 192.168.1.100

# Forward logs via TCP with custom port
sudo ./install.sh --syslog-server syslog.example.com --syslog-port 6514 --syslog-protocol tcp

# View all options
sudo ./install.sh --help
```

Remote syslog options:
- `--syslog-server HOST` - Remote syslog server hostname or IP address
- `--syslog-port PORT` - Remote syslog server port (default: 514)
- `--syslog-protocol PROTO` - Protocol to use: udp or tcp (default: udp)

Verify the installation:

```bash
curl -s localhost:9475/metrics | grep ovs_up
# HELP ovs_up Is OVN stack up (1) or is it down (0).
# TYPE ovs_up gauge
ovs_up 1
```

### Building from Source

Requirements:
- Go 1.24 or later
- Make
- Open vSwitch installed (for testing)

```bash
git clone https://github.com/Liquescent-Development/ovs_exporter.git
cd ovs_exporter

# Build for current architecture (auto-detected)
make

# Build for specific architecture
make BUILD_OS="linux" BUILD_ARCH="arm64"

# Run quick test (requires sudo)
make qtest

# Install using the install script (recommended)
sudo ./install.sh

# Or install manually via make
sudo make deploy
```

### Docker

```bash
docker run -d \
  --name ovs-exporter \
  --net host \
  --pid host \
  -v /var/run/openvswitch:/var/run/openvswitch:ro \
  -v /var/log/openvswitch:/var/log/openvswitch:ro \
  -v /etc/openvswitch:/etc/openvswitch:ro \
  ghcr.io/liquescent-development/ovs-exporter:latest
```

## Configuration

### Command Line Flags

```bash
ovs-exporter --help
```

Key flags:

| Flag | Default | Description |
|------|---------|-------------|
| `-web.listen-address` | `:9475` | Address to listen on for metrics |
| `-web.telemetry-path` | `/metrics` | Path for metrics endpoint |
| `-ovs.poll-interval` | `15` | Seconds between metric collections |
| `-ovs.poll-timeout` | `5` | Timeout for OVS operations |
| `-log.level` | `info` | Log level (debug, info, warn, error) |
| `-database.vswitch.socket.remote` | `unix:/var/run/openvswitch/db.sock` | OVS database socket |
| `-database.vswitch.file.system.id.path` | `/etc/openvswitch/system-id.conf` | System ID file (fallback only) |

### System ID Configuration

The exporter automatically retrieves the system ID in the following order:
1. From OVS database: `ovs-vsctl get Open_vSwitch . external-ids:system-id`
2. From file: `/etc/openvswitch/system-id.conf` (fallback)
3. Uses "unknown" if both fail (non-fatal)

For newer OVS versions, no system-id.conf file is needed!

### Systemd Configuration

Edit `/etc/sysconfig/ovs-exporter` to set options:

```bash
OPTIONS="-ovs.poll-interval 10 -log.level debug"
```

## Metrics

See [METRICS.md](METRICS.md) for complete documentation of all metrics.

### Metric Categories

- **System Metrics**: Overall health, version info, total requests, failed requests
- **Process Metrics**: Component PIDs, file sizes, log events
- **Datapath Metrics**: Flows, lookups, masks, interfaces
- **Interface Metrics**: Traffic statistics, errors, configuration
- **PMD/DPDK Metrics**: CPU utilization, packet processing, cache performance
- **vHost Metrics**: Queue statistics, TX retries, contentions
- **Drop Statistics**: Detailed drop reasons and counters

### Key Metrics Examples

```prometheus
# System health
ovs_up{system_id="uuid"} 1
ovs_info{system_id="uuid", hostname="host1", ovs_version="2.17.0"} 1
ovs_requests_total{system_id="uuid"} 12345
ovs_failed_requests_total{system_id="uuid"} 2

# Interface traffic (with Prometheus naming conventions)
ovs_interface_rx_packets_total{uuid="123", name="eth0"}
ovs_interface_rx_bytes{uuid="123", name="eth0"}
ovs_interface_rx_dropped_total{uuid="123", name="eth0"}

# PMD performance (DPDK)
ovs_pmd_cpu_utilization_ratio{pmd_id="0", numa_id="0"}
ovs_pmd_cycles_per_packet{pmd_id="0", numa_id="0"}
ovs_flow_cache_emc_hit_ratio{pmd_id="0", numa_id="0"}

# External IDs (for multi-tenant)
ovs_interface_external_ids{uuid="123", key="tenant-id", value="customer-456"} 1
ovs_interface_external_ids{uuid="123", key="vm-uuid", value="vm-789"} 1
```

## Example Queries

### Basic Monitoring

```promql
# Check OVS health across all nodes
up{job="ovs-exporter"}

# Interface packet rate
rate(ovs_interface_rx_packets_total[5m])

# Interface errors
rate(ovs_interface_rx_errors_total[5m])

# Datapath flow count
ovs_dp_flows

# PMD CPU utilization (DPDK)
ovs_pmd_cpu_utilization_ratio * 100
```

### Multi-Tenant Monitoring

OVS supports external IDs on interfaces for metadata. Use Prometheus joins to aggregate by tenant:

#### Setting External IDs in OVS

```bash
# Add tenant ID to an interface
ovs-vsctl set Interface vnet0 external-ids:tenant-id="customer-123"
ovs-vsctl set Interface vnet0 external-ids:project="web-app"
ovs-vsctl set Interface vnet0 external-ids:environment="production"
```

#### Querying by Tenant

```promql
# Total bandwidth by tenant
sum by (value) (
  rate(ovs_interface_rx_bytes[5m])
  * on(uuid) group_left(value)
  ovs_interface_external_ids{key="tenant-id"}
)

# Packet rate by tenant
sum by (value) (
  rate(ovs_interface_rx_packets_total[5m])
  * on(uuid) group_left(value)
  ovs_interface_external_ids{key="tenant-id"}
)

# Errors by tenant and environment
sum by (tenant, env) (
  rate(ovs_interface_rx_errors_total[5m])
  * on(uuid) group_left(tenant)
    label_replace(ovs_interface_external_ids{key="tenant-id"}, "tenant", "$1", "value", "(.*)")
  * on(uuid) group_left(env)
    label_replace(ovs_interface_external_ids{key="environment"}, "env", "$1", "value", "(.*)")
)
```

#### Using Recording Rules for Performance

For frequently-used tenant queries, create recording rules in Prometheus:

```yaml
# prometheus-rules.yml
groups:
  - name: tenant_metrics
    interval: 30s
    rules:
      - record: tenant:ovs_interface_rx_bytes:rate5m
        expr: |
          sum by (value) (
            rate(ovs_interface_rx_bytes[5m])
            * on(uuid) group_left(value)
            ovs_interface_external_ids{key="tenant-id"}
          )

      - record: tenant:ovs_interface_rx_packets:rate5m
        expr: |
          sum by (value) (
            rate(ovs_interface_rx_packets_total[5m])
            * on(uuid) group_left(value)
            ovs_interface_external_ids{key="tenant-id"}
          )
```

Then query the pre-computed metrics:
```promql
tenant:ovs_interface_rx_bytes:rate5m
```

### Advanced Queries

```promql
# Top 5 interfaces by traffic
topk(5, rate(ovs_interface_rx_bytes[5m]))

# Interfaces with high drop rate
rate(ovs_interface_rx_dropped_total[5m]) > 100

# PMD threads with low cache hit rate (DPDK)
ovs_flow_cache_emc_hit_ratio < 0.9

# vHost queue saturation
ovs_pmd_avg_vhost_queue_length / ovs_pmd_max_vhost_queue_length > 0.8

# Datapath lookup efficiency
ovs_dp_lookups_hit_total / (ovs_dp_lookups_hit_total + ovs_dp_lookups_missed_total)

# Identify specific drop reasons
topk(10, increase(ovs_datapath_drops_total[5m]))
```

## Grafana Dashboards

### Recommended Panels

1. **System Overview**
   - OVS Up/Down status
   - Component versions
   - Failed requests rate

2. **Interface Metrics**
   - Traffic rates (in/out)
   - Error rates
   - Drop rates
   - Top interfaces by traffic

3. **PMD Performance** (DPDK only)
   - CPU utilization heatmap
   - Cycles per packet
   - Cache hit rates
   - Queue depths

4. **Multi-Tenant View**
   - Bandwidth per tenant
   - Top tenants by traffic
   - Error rates per tenant

### Import Dashboard

A sample Grafana dashboard is available at [grafana/dashboard.json](grafana/dashboard.json).

## Troubleshooting

### Exporter Issues

#### No metrics available
```bash
# Check if OVS is running
systemctl status openvswitch

# Check socket permissions
ls -l /var/run/openvswitch/db.sock

# Check exporter logs
journalctl -u ovs-exporter -f

# Test manual connection
ovs-vsctl show
```

#### System ID issues
```bash
# Check if system-id is in database (newer OVS)
ovs-vsctl get Open_vSwitch . external-ids:system-id

# Check fallback file (older OVS)
cat /etc/openvswitch/system-id.conf

# Set system-id manually if needed
ovs-vsctl set Open_vSwitch . external-ids:system-id=$(uuidgen)
```

#### PMD metrics missing
```bash
# Verify DPDK is enabled
ovs-vsctl get Open_vSwitch . other_config:dpdk-init

# Check PMD threads
ovs-appctl dpif-netdev/pmd-stats-show
```

### Performance Issues

#### High cardinality concerns
- The exporter uses external_ids as separate metrics, not labels
- Use Prometheus joins for tenant aggregation
- Consider recording rules for frequently-used queries

#### Slow queries
- Optimize PromQL queries (avoid regex where possible)
- Use recording rules for complex joins
- Consider increasing polling interval if needed

## Development

### Project Structure
```
ovs_exporter/
├── cmd/ovs_exporter/      # Main application
├── pkg/ovs_exporter/       # Core exporter logic
├── assets/systemd/         # Systemd service files
├── Makefile               # Build automation
├── METRICS.md             # Complete metrics documentation
└── CLAUDE.md              # AI assistant guidelines
```

### Building
```bash
# Standard build
make

# Cross-compilation
make BUILD_OS=linux BUILD_ARCH=arm64

# Run tests
make test

# Create distribution
make dist
```

### Testing
```bash
# Unit tests
go test ./...

# Integration test (requires OVS)
make qtest

# Coverage report
make coverage
```

### Release Process
```bash
# 1. Update VERSION file
echo "2.6.0" > VERSION

# 2. Build release artifacts
make dist

# 3. Create git tag
git tag -a v2.6.0 -m "Release v2.6.0"
git push origin v2.6.0

# 4. Upload to GitHub releases
# Use GitHub UI or gh CLI
```

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure metrics follow Prometheus naming conventions
5. Update METRICS.md for new metrics
6. Submit a pull request

## License

Apache License 2.0 - See [LICENSE](LICENSE) file

## Credits

- Original author: [Paul Greenberg](https://github.com/greenpau)
- Enhanced fork: [Liquescent Development](https://github.com/Liquescent-Development)
- Inspired by: [Red Hat's OVS observability blog](https://www.redhat.com/en/blog/amazing-new-observability-features-open-vswitch)

## Support

For issues and questions:
- GitHub Issues: [https://github.com/Liquescent-Development/ovs_exporter/issues](https://github.com/Liquescent-Development/ovs_exporter/issues)
- Metrics Documentation: [METRICS.md](METRICS.md)