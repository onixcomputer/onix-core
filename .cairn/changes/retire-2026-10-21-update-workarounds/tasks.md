## Phase 1: Retire workarounds

- [ ] [parallel] Drop the `llm-agents-herdr` input and its Zig override once onixpkgs' static-plugin-registry patch applies to the `llm-agents` herdr. r[onix.update_workarounds.retired]
- [ ] [parallel] Point `tigerstyle` back at `nixpkgs` and drop `nixpkgs-octet` once `cargo-llvm-cov`'s tests pass. r[onix.update_workarounds.retired]
- [ ] [parallel] Remove `withoutTypeshareTests` from ki-editor once nixpkgs' typeshare doctests pass. r[onix.update_workarounds.retired]
- [ ] [parallel] Remove the `llamacpp-rocm-rpc` patch and test override once onixpkgs' llama.cpp pin builds with the nixpkgs recipe. r[onix.update_workarounds.retired]
- [ ] [parallel] Remove the hermes-agent `pythonRelaxDeps` additions once its pins accept the nixpkgs releases. r[onix.update_workarounds.retired]
- [ ] [parallel] Remove `modules/buildbot/effects-package.nix` once buildbot-nix passes the `--prefix` words separately. r[onix.update_workarounds.retired]
- [ ] [parallel] Remove `splitMakeWrapperArgs` from the dev shell once clan-core and mics-skills pass each `makeWrapperArgs` word separately. r[onix.update_workarounds.retired]
- [ ] [parallel] Remove `withModuleCertificates` once `gcadapter-oc-kmod` installs its own certificate. r[onix.update_workarounds.retired]
- [ ] [parallel] Restore cutter and iaito once nixpkgs builds them with Qt 6.12. r[onix.update_workarounds.retired]
- [ ] [parallel] Remove the minio-client permits once nixpkgs drops the insecure marking or the modules stop using `mc`. r[onix.update_workarounds.retired]
