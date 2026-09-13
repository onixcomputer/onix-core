# Private Bookshelf

Bookshelf serves owned EPUB and PDF files from `britton-desktop`.

## Access

Open the shelf from a Tailnet device:

`http://100.110.43.11:39300`

The same endpoint provides the OPDS catalog under `/opds`.

Bookshelf has no authentication. The NixOS firewall admits this port only through `tailscale0`.

## Add books

Copy and publish one or more owned books with this command:

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
