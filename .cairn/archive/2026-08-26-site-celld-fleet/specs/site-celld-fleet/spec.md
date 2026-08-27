# Site Celld Fleet Specification Delta

## Purpose

Adds the dedicated private Celld fleet that serves Site assets from RustFS.

## ADDED Requirements

### Requirement: Celld instances have separate runtime authority

r[onix.site_celld_fleet.isolation] Every Celld instance on one host MUST use a distinct validated runtime name, systemd service, Unix identity, state directory, listener pair, and provisioning directory.

#### Scenario: Lab and Site share a host

- GIVEN one host belongs to the lab fleet and the Site fleet
- WHEN NixOS lowers both Celld instances
- THEN the host contains separate `celld` and `celld-site` services
- AND each service uses a separate Unix identity and state directory
- AND neither instance can read the other instance's credential file

### Requirement: Site owns one dedicated fleet

r[onix.site_celld_fleet.composition] The inventory MUST compose one Site Celld fleet across `aspen3` and `britton-desktop` with a dedicated RustFS bucket, credential, state directory, and Tailnet-only ports.

#### Scenario: Site topology is generated

- GIVEN the reviewed service inventory
- WHEN Nix evaluates both Site hosts
- THEN each host has separate `celld-site` and `celld-site-ingress` services
- AND public ingress uses port `32110`
- AND Celld peer traffic uses port `32111`
- AND the loopback-only Celld backend uses `127.0.0.1:32112`
- AND the service uses bucket `onix-site-celld`
- AND only aspen3 has the Site storage provisioner
- AND the existing lab service and bucket remain unchanged

### Requirement: Publisher credentials stay at the adapter boundary

r[onix.site_celld_fleet.credentials] The module MUST deploy the Site bucket credential as standard AWS environment variables owned only by the declared publisher user and MUST NOT place secret values in Nickel, browser assets, or receipts.

#### Scenario: Site publishes through the AWS credential chain

- GIVEN the Site credential generator completed
- WHEN the publisher exports the deployed AWS environment variables for one command
- THEN Celld uses that profile to write only to the Site bucket
- AND receipt output contains no access key or secret key

#### Scenario: A publisher name is unsafe

- GIVEN a publisher user name with whitespace or path syntax
- WHEN settings validation runs
- THEN evaluation fails before Nix deploys a credential

### Requirement: Static and runtime validation reject fleet drift

r[onix.site_celld_fleet.validation] Repository checks MUST reject missing Site services, duplicate runtime resources, wrong endpoints, wrong ports, global firewall exposure, multiple provisioners, or unsafe publisher credential ownership.

#### Scenario: Valid Site fleet passes generated checks

- GIVEN the reviewed Site and lab inventory
- WHEN focused Celld checks evaluate generated NixOS configurations
- THEN both fleets have their expected isolated resources
- AND every Site listener is admitted only on `tailscale0`
- AND Site listener ports do not overlap the default Linux ephemeral range
- AND the backend listener is not reachable from a Tailnet peer

### Requirement: Serving claims require live observation

r[onix.site_celld_fleet.runtime] Rollout evidence MUST separate asset upload, Celld activation, and successful asset retrieval through each deployed Site listener.

#### Scenario: A generated trailing-slash route is requested

- GIVEN the active asset deployment contains a nested `index.html`
- WHEN a client requests its generated trailing-slash route through Site ingress
- THEN ingress removes only the final slash before it forwards the request
- AND Celld returns the expected asset bytes

#### Scenario: Site assets become active

- GIVEN an explicit Site asset upload completed
- WHEN the operator restarts both `celld-site` units
- THEN the same expected asset identity is retrieved through aspen3 and britton-desktop
- AND the evidence states that the listeners are private Tailnet endpoints
- AND the evidence makes no public Internet or node-loss tolerance claim
