#!/usr/bin/env bash
set -eu

IFACE=$(ip route | grep default | awk '{print $5}')
IPV4_ADDR="${ipv4_address}"
GATEWAY="${ipv4_gateway}"
DNS_SERVER="${ipv4_dns}"

if [[ -n "$IPV4_ADDR" && -n "$GATEWAY" && -n "$DNS_SERVER" ]]; then
  echo "Configuring static IP using nmcli...."

  # Find the NetworkManager connection name for this interface
  CON_NAME=$(nmcli -t -f NAME,DEVICE connection show | grep ":${IFACE}$" | cut -d: -f1)

  if [[ -z "$CON_NAME" ]]; then
      echo "No NetworkManager connection found for interface: $IFACE"
      exit 1
  fi

  echo "Configuring static IPv4 for connection: $CON_NAME"

  nmcli connection modify "$CON_NAME" ipv4.addresses "$IPV4_ADDR"
  nmcli connection modify "$CON_NAME" ipv4.gateway "$GATEWAY"
  nmcli connection modify "$CON_NAME" ipv4.dns "$DNS_SERVER"
  nmcli connection modify "$CON_NAME" ipv4.method manual

  nmcli connection up "$CON_NAME"

  echo "Static IPv4 configuration applied successfully."
else
  echo "Static IP configuration not provided, skipping nmcli configuration...."
fi
