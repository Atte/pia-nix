#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root!" >&2
    exit 1
fi

ip -n "$PIA_NETNS" link delete dev "$PIA_INTERFACE"
