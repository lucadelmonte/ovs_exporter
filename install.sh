#!/bin/bash
# Install wrapper for ovs-exporter
# This script calls the actual installation script from assets/systemd/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "${SCRIPT_DIR}/assets/systemd/add_service.sh" ]; then
    exec "${SCRIPT_DIR}/assets/systemd/add_service.sh" "$@"
else
    echo "Error: Installation script not found at assets/systemd/add_service.sh"
    exit 1
fi
