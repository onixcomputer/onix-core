## 1. Create the clan service module

- [x] 1.1 Create `modules/buildbot/default.nix` with `_class = "clan.service"`, manifest, and two roles (`master`, `worker`)
- [x] 1.2 Implement the `master` role interface with freeformType and named options (`domain`, `buildSystems`, `admins`, `evalWorkerCount`, `evalMaxMemorySize`, `outputsPath`, `postBuildSteps`, `useHTTPS`, GitHub app/OAuth IDs)
- [x] 1.3 Implement the `master` role perInstance: import `buildbot-nix.nixosModules.buildbot-master`, wire clan vars generators (`buildbot-worker`, `buildbot-github`), map settings to `services.buildbot-nix.master.*`, add firewall and tmpfiles rules
- [x] 1.4 Implement the `worker` role interface with freeformType and named option (`workers`)
- [x] 1.5 Implement the `worker` role perInstance: import `buildbot-nix.nixosModules.buildbot-worker`, wire `workerPasswordFile` from clan vars generator

## 2. Register the module

- [x] 2.1 Add `"buildbot" = import ./buildbot { inherit inputs; };` to `modules/default.nix`

## 3. Create the inventory service instance

- [x] 3.1 Create `inventory/services/buildbot.nix` with master role assigned to aspen1 (domain, GitHub config, buildSystems, eval settings, outputsPath, postBuildSteps, admins) and worker role assigned to aspen1 (workers = 16)
- [x] 3.2 Add `buildbot = import ./buildbot.nix { inherit inputs; };` to `inventory/services/default.nix`

## 4. Remove the direct import

- [x] 4.1 Delete `machines/aspen1/buildbot.nix`
- [x] 4.2 Remove `./buildbot.nix` from the imports list in `machines/aspen1/configuration.nix`

## 5. Validate

- [x] 5.1 Run `build aspen1` to verify the configuration evaluates and builds
- [x] 5.2 Run `validate` to confirm all checks pass
