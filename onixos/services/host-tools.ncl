# Retained system-wide CLI package profile for the OnixOS aspen2 host.
# Home Manager user packages remain in their own /etc/profiles/per-user profile.
fun onix =>
  let host_impl = fun args =>
    let tools = args.package_paths."system-tools" in
    {
      output.host = {
        packages = [tools],
        users.mandb = { group = "mandb", description = "man-db indexer" },
        groups.mandb = {},
        files."man_db.conf".text = m%"
          MANPATH_MAP /run/current-system/sw/bin /run/current-system/sw/share/man
          MANPATH_MAP /run/wrappers/bin /run/current-system/sw/share/man
          MANDB_MAP /run/current-system/sw/share/man /var/cache/man/nixos-mandb
        "%,
        files."onixos/mandb-refresh.sh" = {
          mode = "0755",
          text = m%"
            #!%{tools}/bin/bash
            set -euo pipefail
            %{tools}/bin/mkdir -p "$CACHE_DIRECTORY/nixos-manpages"
            %{tools}/bin/rsync \
              --checksum --recursive --copy-links --delete --no-times --no-perms --chmod=+w \
              /run/current-system/sw/share/man/ "$CACHE_DIRECTORY/nixos-manpages"
            printf 'MANDB_MAP %s/nixos-manpages %s/nixos-mandb\n' \
              "$CACHE_DIRECTORY" "$CACHE_DIRECTORY" > "$RUNTIME_DIRECTORY/man.conf"
            %{tools}/bin/mandb -C "$RUNTIME_DIRECTORY/man.conf" -q
          "%,
        },
        units."mandb.service" = {
          sections = {
            Unit = {
              Description = "Build the manual-page search index",
              After = "local-fs.target",
            },
            Service = {
              Type = "oneshot",
              User = "mandb",
              Group = "mandb",
              ExecStart = "%{tools}/bin/bash /etc/onixos/mandb-refresh.sh",
              CacheDirectory = "man",
              RuntimeDirectory = "mandb",
              BindReadOnlyPaths = ["/dev/null:/etc/man_db.conf"],
              ProtectSystem = "strict",
            },
          },
          wanted_by = ["multi-user.target"],
        },
      },
    }
  in
  (
    {
      interface = {
        manifest = {
          name = "onix-core/host-tools",
          description = "Retained system CLI tools, package manuals, completions, and man-db support for OnixOS hosts.",
          categories = ["system", "tools"],
        },
        portability = {
          status = 'platform_specific,
          platform_leaves = [
            {
              namespace = "host",
              targets = ["onixos"],
              rationale = "The retained package profile is produced from the selected NixOS machine's evaluated system package set.",
            },
          ],
        },
        packages = ["system-tools"],
        roles.host = {},
      },
      impl = host_impl,
    } | onix.ServiceModule
  )
