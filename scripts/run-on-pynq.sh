#!/usr/bin/env bash
# ============================================================================
#  run-on-pynq.sh - run the baseline AES on a directly-connected PYNQ-Z2
# ----------------------------------------------------------------------------
#  Assumes:
#    - PYNQ-Z2 plugged to laptop via Ethernet + USB (power).
#    - Laptop has 192.168.2.1/24 on enp0s31f6 and dnsmasq giving DHCP leases.
#    - PYNQ already has /home/xilinx/jupyter_notebooks/riscy/{overlays,mem_files}/
#
#  Run: ./scripts/run-on-pynq.sh
#  Optional override: PYNQ_IP=192.168.2.117 ./scripts/run-on-pynq.sh
# ============================================================================
set -euo pipefail
PYNQ_IP="${PYNQ_IP:-192.168.2.119}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Sanity: is the board up?
if ! timeout 3 ping -c 1 -W 1 "$PYNQ_IP" >/dev/null 2>&1; then
    echo "error: $PYNQ_IP not reachable. Check: VPN off matters? No. Check:" >&2
    echo "  - ethernet UP:      ip link show enp0s31f6" >&2
    echo "  - laptop IP set:    sudo ip addr add 192.168.2.1/24 dev enp0s31f6" >&2
    echo "  - dnsmasq running:  sudo dnsmasq --listen-address=192.168.2.1 \\" >&2
    echo "                        --bind-interfaces --no-resolv --port=0 \\" >&2
    echo "                        --dhcp-range=192.168.2.50,192.168.2.150,255.255.255.0,5m" >&2
    exit 1
fi

echo ">>> ship runner to PYNQ"
sshpass -p xilinx scp -o StrictHostKeyChecking=accept-new \
    "$WORKSPACE_ROOT/pynq/run_aes_on_pynq.py" \
    "xilinx@$PYNQ_IP:/tmp/run_aes_on_pynq.py"

echo ">>> execute (needs root for pynq.Overlay)"
sshpass -p xilinx ssh "xilinx@$PYNQ_IP" \
    'echo xilinx | sudo -S python3 /tmp/run_aes_on_pynq.py'
