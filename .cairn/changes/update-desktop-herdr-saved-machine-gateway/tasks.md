## Phase 1: Gateway Configuration

- [x] [serial] Lock herdr-iroh to 1ee15bf8506a13394de2f253ee6fd8febfca1a64, publish the existing shared fleet configuration, and provide Herdr/SSH using the upstream herdrPackage option. r[onix.herdr_gateway.pin] r[onix.herdr_gateway.path]
- [x] [serial] Leave the notify webhook section unset in the generated server configuration. r[onix.herdr_gateway.notify]

## Phase 2: Compatible CLI

- [x] [serial] Select and verify Herdr >=0.9.1; retain the compatible existing 0.9.3 selection and do not replace the running server. r[onix.herdr_gateway.path] r[onix.herdr_gateway.preservation]

## Phase 3: Release

- [ ] [serial] Build the exact desktop artifact, reject unsafe activation scope, commit/push the isolated release, and run clan m u britton-desktop through the repository CLI. r[onix.herdr_gateway.release] r[onix.herdr_gateway.preservation]

## Phase 4: Relay Process

- [ ] [serial] Verify a real herdr-iroh process restart onto the new executable, unchanged service identity, and unchanged Herdr/server/agent process identities. SIGHUP alone does not complete this task. r[onix.herdr_gateway.restart] r[onix.herdr_gateway.preservation]

## Phase 5: Once-only Probe

- [ ] [serial] Run herdr --machine instant-fill status server exactly once after deployment and report its actual output, exit status, and deployed versions. r[onix.herdr_gateway.probe]
