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
