# Registers the agents' MCP servers (swarm-news and any other module's, such
# as Kiln's fleet API) with OMP, Antigravity and Claude Code, and the swarm
# brief as an Antigravity session hook. These entries live in files the
# agents also write, so they are merged in rather than linked. It changes only
# its own entries, and re-running it changes nothing. A failure is reported
# and skipped; it never fails the Home Manager activation.
#
# Usage: swarm-news-agent-setup <MCP servers JSON> <swarm-news-brief command>
# where the JSON maps each server name to {"command": ..., "args": [...]}.
servers=$1
brief=$2
export PATH="$PATH:/etc/profiles/per-user/${USER:-$(id -un)}/bin:/run/current-system/sw/bin"

note() {
  printf 'swarm-news-agent-setup: %s\n' "$*" >&2
}

# Set one JSON path in a file, creating the file if needed.
ensure_json() {
  local file=$1 path=$2 value=$3 next
  mkdir -p "$(dirname "$file")"
  [ -s "$file" ] || printf '{}\n' >"$file"
  if jq -e --argjson p "$path" --argjson v "$value" 'getpath($p) == $v' "$file" >/dev/null 2>&1; then
    return 0
  fi
  if ! next=$(jq --argjson p "$path" --argjson v "$value" 'setpath($p; $v)' "$file" 2>/dev/null); then
    note "$file is not valid JSON; left unchanged"
    return 0
  fi
  printf '%s\n' "$next" >"$file.swarm-news-tmp"
  chmod --reference="$file" "$file.swarm-news-tmp"
  mv "$file.swarm-news-tmp" "$file"
  note "updated $file"
}

claude=$(command -v claude || true)
while IFS= read -r name; do
  server=$(jq -c --arg n "$name" '.[$n] | {command, args}' "$servers")
  key=$(jq -cn --arg n "$name" '["mcpServers", $n]')
  ensure_json "$HOME/.omp/agent/mcp.json" "$key" "$server"
  ensure_json "$HOME/.gemini/config/mcp_config.json" "$key" "$server"

  # Claude Code rewrites ~/.claude.json while it runs; let its own command
  # change the entry. `claude mcp get` would start the server to check it.
  [ -n "$claude" ] || continue
  current=$(jq -c --arg n "$name" '.mcpServers[$n] | if . == null then null else {command, args} end' "$HOME/.claude.json" 2>/dev/null || echo null)
  [ "$current" = "$server" ] && continue
  if [ "$current" != null ] && [ -n "$current" ]; then
    timeout 60 "$claude" mcp remove --scope user "$name" >/dev/null 2>&1 || true
  fi
  mapfile -t args < <(jq -r --arg n "$name" '.[$n].args[]' "$servers")
  command=$(jq -r --arg n "$name" '.[$n].command' "$servers")
  if timeout 60 "$claude" mcp add --scope user "$name" -- "$command" "${args[@]}" >/dev/null 2>&1; then
    note "added $name to Claude Code"
  else
    note "could not add $name to Claude Code"
  fi
done < <(jq -r 'keys[]' "$servers")

hook=$(jq -cn --arg c "$brief --format antigravity" '{SessionStart: [{type: "command", command: $c, timeout: 20}]}')
ensure_json "$HOME/.gemini/config/hooks.json" '["swarm-news-brief"]' "$hook"
