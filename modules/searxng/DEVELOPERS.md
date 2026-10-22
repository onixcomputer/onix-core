# Developer search engines

Set `enableDeveloperEngines = true` to configure these engines under the **IT** category.
Aspen1 enables this setting. Kagi remains enabled for ordinary general searches.
All four developer engines passed live browser checks after deployment from the published forge-preserving baseline.

| Engine | Example | Scope |
| --- | --- | --- |
| GitHub | `!gh searxng` | Public repository search through SearXNG's native GitHub engine |
| NixOS options | `!nixopts services.openssh.enable` | Upstream unstable NixOS options |
| Home Manager | `!hm programs.git.enable` | Upstream unstable Home Manager options |
| Noogle | `!noogle lib.mkIf` | Nix function names, aliases, and documentation from a pinned catalog |

These engines require neither your Kagi session nor its engine access token.
GitHub code search and private repository search are not configured.
The option catalogs do not include every Onix-specific service option.

## Sources and bounds

The NixOS and Home Manager engines use the public NixOS Search backend, schema version 51, with separate document-type filters.
The backend's read-only frontend credentials are publicly shipped by its web client. They are not personal credentials.
Requests use HTTPS, reject redirects, and return at most 20 results. Malformed, timed-out, and partial responses fail instead of appearing as empty searches.
Result links are constructed from validated option names and the fixed search.nixos.org origin.
The parser limits response size. As with the Kagi adapter, this does not bound the SearXNG HTTP receive buffer.

Noogle searches locally after initialization. The Nix build fetches the catalog from `https://noogle.dev/api/v1/data` with a fixed content hash.
Queries do not trigger downloads. Initialization bounds the input size and the number of normalized entries.
The catalog has 2,148 source records and identifies Nixpkgs revision `07d363370177d2b7e91f9031e52317c6f72316eb`.
Names rank before description-only matches. Exact names rank first. Alias results link to the canonical function page.

The Nix fixed-output SHA-256 is `1pbipq5f2d3j7yyz9ffhwqqjsqvjdvd5v2vb5lg8x1v4qp988g0q`.
SHA-256 is used because this is a Nix fixed-output fetch. No new general-purpose hashing scheme is introduced.
To update the snapshot, fetch the API again with `nix-prefetch-url`, review its metadata, update the hash, and rerun the packaged catalog tests.
If upstream changes the catalog and the pinned output is absent from the cache, the fetch fails rather than silently using new data.
The packaged `noogle-notices.txt` preserves the Noogle and Nixpkgs notices.

## Verification

```console
nix build .#checks.x86_64-linux.searxng-module .#checks.x86_64-linux.searxng-developer-engines .#checks.x86_64-linux.searxng-kagi-session --no-link --option allow-import-from-derivation true
```

Tests cover source separation, malformed data, query bounds, unsafe paths, URL parameter encoding, aliases, ranking, missing results, and the real engine loader.
The developer-only package is tested without the Kagi patch or credentials.
A live search from each engine remains required before a deployment is reported as verified.

## References

- [NixOS Search protocol source](https://github.com/NixOS/nixos-search/tree/3a7f0dcc6d2071602e90616a62422bdea9094e62).
- [Noogle source and MIT license](https://github.com/nix-community/noogle/tree/bdba2c8085ab4756f3bbb789574c705cab8f42a1).
- [Nixpkgs catalog revision and license](https://github.com/NixOS/nixpkgs/tree/07d363370177d2b7e91f9031e52317c6f72316eb).
