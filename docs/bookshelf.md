# Private Bookshelf

Bookshelf serves owned EPUB and PDF files from `britton-desktop`.

## Access

Open the shelf from a Tailnet device:

`http://100.110.43.11:39300`

The same endpoint provides the OPDS catalog under `/opds`.

Bookshelf has no authentication. The NixOS firewall admits this port only through `tailscale0`.

## Upload books

Send owned EPUB and PDF files to the upload endpoint from your own Tailnet devices:

`http://100.110.43.11:39301`

Open it in a browser to choose or drop books, or upload from a terminal:

```console
curl -T book.epub http://100.110.43.11:39301/
```

Each upload is stored in the source directory, published, and added to Calibre. The JSON answer reports each library as `added`, `already-present` or `failed` with a reason. Identical bytes are never stored twice. A different file with an existing name gets a numbered name instead of replacing it. Bookshelf treats files that share a name stem, such as `book.epub` and `book.pdf`, as two formats of one book. A file that Bookshelf cannot read is removed from the source directory again; Calibre answers for itself. Uploads are limited to 256 MiB. The shelf page can take about a minute to show a change; downloads and Calibre change at once.

Only untagged devices owned by the same Tailscale user as `britton-desktop` may use the endpoint. For every request it asks tailscaled who owns the connecting device and who owns this machine, and it refuses anything it cannot identify. Uploads must use `PUT` and name the machine (its Tailnet address or MagicDNS name), so a web page open in your browser cannot send books through it.

Calibre's content server accepts these writes because they come from `127.0.0.2`, its only `--trusted-ips` entry. Do not trust `127.0.0.1` or enable `--enable-local-write`: the Folio positions proxy on port 6768 relays LAN clients to Calibre from `127.0.0.1`, so either setting would let anyone on the LAN change or delete books.

## Add books

On the machine itself, copy and publish one or more owned books with this command:

```console
sudo bookshelf-import /path/to/book.epub /path/to/manual.pdf
```

The command rejects missing files and unsupported extensions before it copies any input. It then rebuilds and publishes the catalog.

## Fetch books

Download a book from a catalog and publish it with the fetch command:

```console
sudo bookshelf-fetch gutenberg "pride and prejudice"
```

List catalog hits first, then pick one that matches the query:

```console
sudo bookshelf-fetch gutenberg "the rust programming language" --match 1
```

The `gutenberg` provider searches Project Gutenberg and downloads the chosen EPUB. It needs no API key and works without any account.

The `anna` provider searches Anna's Archive through the `annas-mcp` CLI:

```console
sudo bookshelf-fetch anna "some technical book"
sudo ANNAS_SECRET_KEY=... bookshelf-fetch anna "some technical book" --md5 <hash>
```

Anna's Archive search does not need a key. Downloading needs `ANNAS_SECRET_KEY`, a donation API key, and a reachable Anna's Archive mirror. If the provider cannot reach a mirror it reports an error and keeps the shelf unchanged.

Source files remain in `/datapool/bookshelf/source`. Published files and reading state remain in `/datapool/bookshelf/library`.

The upload endpoint and `bookshelf-publish.service` take the same lock, `/var/cache/bookshelf-sync/publish.lock`, so two publishes never rebuild the library at once.

## Remove books

Remove the source file as root. Then rebuild the catalog:

```console
sudo rm /datapool/bookshelf/source/book.epub
sudo systemctl start --wait bookshelf-publish.service
```

## Back up data

Back up both Bookshelf directories. Source books can rebuild the catalog, but profiles and reading positions exist in the library directory.

Bookshelf stores this data in cleartext on the mounted datapool. Host and backup access controls protect it.

## Runtime choice

This deployment uses the upstream Node filesystem mode. Celld v0.3.0 does not support the R2 bindings required by Bookshelf's Worker bundle.
