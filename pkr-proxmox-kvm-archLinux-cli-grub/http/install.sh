#!/bin/bash
set -eux

# Minimal bootstrap run inside the Arch live environment.
# Usage: this script is fetched and executed by the VM during early boot.

# Wait for network to be up (DHCP)
for i in 1 2 3 4 5; do
  ip addr show | grep -q 'inet ' && break
  sleep 2
done

echo "Inside install.sh..... Exiting now"
