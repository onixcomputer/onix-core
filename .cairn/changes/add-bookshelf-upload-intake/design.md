## Context

Bookshelf runs as the `bookshelf` account over private datapool directories, and its library mirrors `/datapool/bookshelf/source`: `bookshelf-sync` rebuilds the catalog from every file there. Calibre's content server runs as `brittonr` on `0.0.0.0:6767` without authentication, so it is read-only. A user-level Folio positions proxy on `0.0.0.0:6768` forwards GET, POST, PUT and DELETE to `127.0.0.1:6767`. The Tailnet includes other people's devices and over five hundred tagged devices.

## Decisions

### Decision: Identity from tailscaled, not configuration

Every request is resolved with tailscaled's `whois` for both the peer and the server's own listening address. The endpoint admits a peer only when neither node is tagged and both belong to the same Tailscale user. A lookup failure refuses the request. This needs no login, token or address list in this public repository, and it excludes other users and all tagged devices.

### Decision: Browser-safe uploads

Uploads use `PUT` only. A cross-origin `PUT` needs a CORS preflight that the endpoint never grants, while `POST` is answered 405 because a form can post cross-site without one. A request whose `Origin` names another site, or whose `Host` is neither the Tailnet address, a single-label MagicDNS name nor a `*.ts.net` name, is refused, which blocks DNS rebinding. Headers are checked before the body: with `Expect: 100-continue` a refused upload is never transmitted, and after other refusals the connection lingers briefly so the client reads the answer instead of a reset.

### Decision: Calibre trusts one dedicated loopback address

Calibre's `--enable-local-write` and a trusted `127.0.0.1` would admit everyone who can reach the Folio proxy. The endpoint therefore binds its Calibre connections to `127.0.0.2`, the only `--trusted-ips` entry, and calls Calibre's own add-book endpoint while the server keeps running. The `calibre-server` module rejects shared loopback addresses, wildcards and networks in `trustedIps`. Calibre reports duplicates by title and author instead of adding them.

### Decision: The source directory stays equal to what is published

The endpoint streams the body into a hidden partial file beside the source books, checks that its bytes match the claimed format, and links it in under a sanitized name without replacing any file. Identical bytes already present are not stored again. It then runs `bookshelf-sync` under the lock that `bookshelf-publish.service` also takes, and finds the book in the published catalog by size and SHA-256. A book that `bookshelf-sync` skips is removed from the source directory again; when publishing itself fails, the book stays so the next publish retries it. Uploads are added one at a time.

### Decision: Same account and sandbox as publishing

The endpoint runs as `bookshelf` with the strict sandbox used by the other Bookshelf units. Its writable paths are the source, library and sync cache directories. It listens only on the Tailnet address and the firewall admits its port only on `tailscale0`.

## Risks / Trade-offs

- Any untagged device of the owner can add books, including headless machines such as Aspen3; removing books still needs root on the host.
- Calibre and Bookshelf can disagree: Calibre deduplicates by title and author, Bookshelf by bytes, and files sharing a name stem become formats of one Bookshelf book.
- Uploads are limited to 256 MiB here and 500 MiB by validation, below Calibre's default request-body limit.
- Calibre parses uploaded files as `brittonr`; the identity check limits that exposure to the owner's devices.
