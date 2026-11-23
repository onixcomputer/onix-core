# shellcheck shell=bash
# Both renderers prepend these required policy variables and the tool PATH.
: "${bridge:?}" "${address:?}" "${expected_mtu:?}"
: "${link_interfaces:?}" "${link_members:?}" "${peer_names:?}" "${peer_addresses:?}"
: "${ping_count:?}" "${ping_timeout:?}" "${ping_attempts:?}" "${ping_attempt_interval_seconds:?}"
: "${settle_seconds:?}" "${repair_wait_attempts:?}" "${repair_wait_interval_seconds:?}"
: "${cooldown_seconds:?}" "${state_dir:?}" "${recovery_marker:?}" "${exit_unhealthy:?}"

log() {
  printf 'thunderbolt-link guard: %s\n' "$*"
}

set_sysctl() {
  local key="$1"
  local value="$2"
  local path="/proc/sys/${key//.//}"
  local current

  if [ ! -e "$path" ]; then
    return 0
  fi

  current="$(cat "$path")"
  if [ "$current" != "$value" ]; then
    printf '%s' "$value" >"$path"
    log "set $key=$value (was $current)"
  fi
}

# Keep the link from accepting redirects or source-routed packets from peers.
apply_sysctls() {
  local iface
  for iface in "${link_interfaces[@]}"; do
    if [ ! -e "/sys/class/net/$iface" ]; then
      continue
    fi
    set_sysctl "net.ipv4.conf.$iface.accept_redirects" 0
    set_sysctl "net.ipv4.conf.$iface.send_redirects" 0
    set_sysctl "net.ipv4.conf.$iface.accept_source_route" 0
  done
}

carrier_up() {
  [ "$(cat "/sys/class/net/$bridge/carrier" 2>/dev/null || echo 0)" = 1 ]
}

address_present() {
  ip -o -4 addr show dev "$bridge" | grep -qF -- "$address"
}

mtu_matches() {
  [ "$(cat "/sys/class/net/$bridge/mtu" 2>/dev/null || echo 0)" = "$expected_mtu" ]
}

peer_reachable() {
  local attached=()
  local path name index address attempt

  # A configured peer that is not plugged in is not a link failure.
  for path in /sys/bus/thunderbolt/devices/*/device_name; do
    if [ ! -e "$path" ]; then
      continue
    fi
    name="$(cat "$path")"
    for index in "${!peer_names[@]}"; do
      if [ "${peer_names[$index]}" = "$name" ]; then
        attached+=("${peer_addresses[$index]}")
        break
      fi
    done
  done

  if [ "${#attached[@]}" -eq 0 ]; then
    log "no configured peer is attached to the USB4 link; nothing to verify"
    return 0
  fi

  for address in "${attached[@]}"; do
    for attempt in $(seq 1 "$ping_attempts"); do
      if ping -n -q -c "$ping_count" -W "$ping_timeout" "$address" >/dev/null 2>&1; then
        break
      fi
      if [ "$attempt" = "$ping_attempts" ]; then
        log "attached peer $address did not answer after $ping_attempts attempts"
        return 1
      fi
      sleep "$ping_attempt_interval_seconds"
    done
  done
}

healthy() {
  carrier_up && address_present && mtu_matches && peer_reachable
}

apply_link_params() {
  local member
  # Raise members first: the bridge MTU is capped by its members.
  for member in "${link_members[@]}"; do
    if [ ! -e "/sys/class/net/$member" ]; then
      continue
    fi
    if [ "$(cat "/sys/class/net/$member/mtu")" != "$expected_mtu" ]; then
      ip link set dev "$member" mtu "$expected_mtu"
      log "set $member mtu=$expected_mtu"
    fi
  done
  if ! mtu_matches; then
    ip link set dev "$bridge" mtu "$expected_mtu"
    log "set $bridge mtu=$expected_mtu"
  fi
}

# Cycling members rebuilds the XDomain DMA path on physical Thunderbolt links.
repair() {
  local member attempt
  for member in "${link_members[@]}"; do
    if [ ! -e "/sys/class/net/$member" ]; then
      continue
    fi
    log "bouncing $member"
    ip link set dev "$member" down
    tc qdisc replace dev "$member" root fq
    sleep "$settle_seconds"
    ip link set dev "$member" up
  done

  for attempt in $(seq 1 "$repair_wait_attempts"); do
    if ! address_present; then
      ip addr replace "$address" dev "$bridge"
    fi
    if carrier_up && address_present; then
      log "link members came back on attempt $attempt"
      break
    fi
    sleep "$repair_wait_interval_seconds"
  done
  apply_link_params
  apply_sysctls
}

main() {
  mkdir -p "$state_dir"
  apply_sysctls
  if [ ! -e "/sys/class/net/$bridge" ]; then
    log "$bridge does not exist on this host; nothing to verify"
    exit 0
  fi
  if ! carrier_up; then
    log "$bridge has no carrier; the USB4 link is down and no host-side repair is possible"
    exit 0
  fi
  if healthy; then
    log "link healthy: $address, mtu $expected_mtu"
    exit 0
  fi

  local now last_repair=0
  now="$(date +%s)"
  if [ -r "$recovery_marker" ]; then
    last_repair="$(cat "$recovery_marker" 2>/dev/null || echo 0)"
  fi
  if [ "$last_repair" -ne 0 ] && [ $((now - last_repair)) -lt "$cooldown_seconds" ]; then
    log "link unhealthy and the last repair is inside the ${cooldown_seconds}s cooldown; not bouncing again"
    exit "$exit_unhealthy"
  fi

  printf '%s' "$now" >"$recovery_marker"
  log "link unhealthy (address, mtu, or peer reachability); repairing"
  repair
  if healthy; then
    log "link healthy again after repair"
    exit 0
  fi
  log "link still unhealthy after repair"
  exit "$exit_unhealthy"
}

main "$@"
