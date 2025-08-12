{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # MAC address randomization scripts
    (pkgs.writeShellScriptBin "randomize-mac" ''
      #!/bin/bash

      # Get the active WiFi connection
      WIFI_CONN=$(nmcli -t -f NAME,TYPE connection show --active | grep "802-11-wireless" | cut -d: -f1)

      if [ -z "$WIFI_CONN" ]; then
      echo "No active WiFi connection found"
      exit 1
      fi

      echo "Randomizing MAC for connection: $WIFI_CONN"

      # Set random MAC address
      nmcli connection modify "$WIFI_CONN" 802-11-wireless.cloned-mac-address random

      # Reconnect to apply changes
      nmcli connection down "$WIFI_CONN"
      sleep 2
      nmcli connection up "$WIFI_CONN"

      # Show new MAC
      echo "New MAC address:"
      ip link show | grep -A1 "wl" | grep "link/ether"
    '')

    (pkgs.writeShellScriptBin "reset-mac" ''
      #!/bin/bash

      # Get the active WiFi connection
      WIFI_CONN=$(nmcli -t -f NAME,TYPE connection show --active | grep "802-11-wireless" | cut -d: -f1)

      if [ -z "$WIFI_CONN" ]; then
      echo "No active WiFi connection found"
      exit 1
      fi

      echo "Resetting MAC to default for connection: $WIFI_CONN"

      # Remove the cloned MAC setting (reverts to hardware default)
      nmcli connection modify "$WIFI_CONN" 802-11-wireless.cloned-mac-address ""

      # Reconnect to apply changes
      nmcli connection down "$WIFI_CONN"
      sleep 2
      nmcli connection up "$WIFI_CONN"

      # Show current MAC
      echo "Reset to hardware MAC address:"
      ip link show | grep -A1 "wl" | grep "link/ether"
    '')

    (pkgs.writeShellScriptBin "show-mac" ''
      #!/bin/bash
      echo "Current MAC addresses:"
      ip link show | grep -A1 "wl" | grep "link/ether"

      echo -e "\nWiFi connection MAC settings:"
      nmcli -t -f NAME,TYPE connection show | grep "802-11-wireless" | while IFS=: read -r conn type; do
        MAC_SETTING=$(nmcli -t -f 802-11-wireless.cloned-mac-address connection show "$conn" 2>/dev/null | cut -d: -f2)
        echo "$conn: ''${MAC_SETTING:-none}"
      done
    '')
  ];
}
