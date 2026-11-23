## ADDED Requirements

### Requirement: Owner upload endpoint

r[onix.bookshelf.intake] The system MUST offer an opt-in Tailnet upload endpoint that stores an owned EPUB or PDF in the source directory, publishes it, and offers it to a configured Calibre content server, admitting only untagged devices of the server's own Tailscale owner.

#### Scenario: Upload a book from an owner device

r[onix.bookshelf.intake.upload]
- GIVEN an untagged device owned by the same Tailscale user as the server
- WHEN it sends `PUT /<file name>` with a valid EPUB or PDF body
- THEN the book is published to Bookshelf and offered to Calibre
- AND the response reports each library's outcome

#### Scenario: Refuse other devices and forged requests

r[onix.bookshelf.intake.identity]
- GIVEN a tagged device, another user's device, an unidentifiable peer, a foreign `Origin` or `Host`, or a `POST`
- WHEN it sends a request to the endpoint
- THEN the endpoint refuses it from the request headers without storing anything
- AND neither library changes

#### Scenario: Never replace or duplicate a stored book

r[onix.bookshelf.intake.no_replace]
- GIVEN a source directory that already holds a book
- WHEN the same bytes arrive again, or different bytes arrive under the same name
- THEN identical bytes are reported as already present without a second copy
- AND different bytes are stored under a new numbered name

#### Scenario: Keep the source equal to the shelf

r[onix.bookshelf.intake.unreadable]
- GIVEN an upload that matches its format but that Bookshelf cannot read
- WHEN publishing skips it
- THEN the endpoint removes it from the source directory and reports the failure

#### Scenario: Serialize publishing

r[onix.bookshelf.intake.serialized]
- GIVEN the endpoint and `bookshelf-publish.service`
- WHEN either publishes
- THEN it holds the shared publish lock for the whole rebuild

### Requirement: Dedicated Calibre write address

r[onix.bookshelf.calibre_write] The Calibre content server MUST accept unauthenticated writes only from addresses listed in `trustedIps`, and the system MUST refuse to trust shared loopback addresses that local proxies use.

#### Scenario: Write through the dedicated address

r[onix.bookshelf.calibre_write.dedicated_address]
- GIVEN Calibre trusts only `127.0.0.2`
- WHEN the upload endpoint adds a book from that source address
- THEN Calibre accepts it while the server keeps running

#### Scenario: Refuse relayed writes

r[onix.bookshelf.calibre_write.relayed]
- GIVEN a local proxy that relays remote clients to Calibre from `127.0.0.1`
- WHEN a client attempts a write through it
- THEN Calibre refuses the change
- AND settings that trust `127.0.0.1`, `::1`, wildcards or networks fail evaluation
