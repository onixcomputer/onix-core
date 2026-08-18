## Phase 1: Package and typed sources

- [x] [serial] P1 Add the pinned `ghzinga` package output and install it in the Herdr Home Manager profile. r[onix.britton-desktop.herdr.workflow_plugins.ghzinga]
- [x] [depends:onix.britton-desktop.herdr.workflow_plugins.sources] P2 Add five typed plugin source records with exact release commits. r[onix.britton-desktop.herdr.workflow_plugins.sources]
- [x] [depends:onix.britton-desktop.herdr.workflow_plugins.sync] P3 Generate the explicit `sync-herdr-plugins` command without activation mutation. r[onix.britton-desktop.herdr.workflow_plugins.sync]

## Phase 2: Actions and editor integration

- [x] [depends:onix.britton-desktop.herdr.workflow_plugins.bindings] A1 Add shared keys and rendered actions for File Viewer, reviewr, and Vim navigation. r[onix.britton-desktop.herdr.workflow_plugins.bindings]
- [x] [depends:onix.britton-desktop.herdr.workflow_plugins.bindings] A2 Load the pinned Neovim navigation adapter. r[onix.britton-desktop.herdr.workflow_plugins.bindings]

## Phase 3: Validation

- [x] [depends:onix.britton-desktop.herdr.workflow_plugins.validation] V1 Add positive package, source, action, and adapter checks. r[onix.britton-desktop.herdr.workflow_plugins.validation]
- [x] [depends:onix.britton-desktop.herdr.workflow_plugins.validation] V2 Add negative unpinned-source, bogus-action, bogus-package, and activation-mutation checks. r[onix.britton-desktop.herdr.workflow_plugins.validation]
- [x] [depends:onix.britton-desktop.herdr.workflow_plugins.validation] V3 Build the package and focused check, evaluate the system, and run Cairn gates. r[onix.britton-desktop.herdr.workflow_plugins.validation]
