## Phase 1: Lifecycle and benchmark core

- [x] [serial] Define the managed benchmark lifecycle, restoration contract, and isolated artifact boundary. r[onix.tenstorrent.model_performance.managed_benchmark]
- [x] [serial] Add a Rust benchmark core with positive matrix/result tests and negative malformed-output, wrong-topology, and invalid-argument tests. r[onix.tenstorrent.model_performance.managed_benchmark]

## Phase 2: Nix integration

- [x] [serial] Package the bounded benchmark core and add a root-operated `britton-desktop` oneshot whose trap restores only the previously active managed P150 services. r[onix.tenstorrent.model_performance.managed_benchmark]
- [x] [serial] Add positive and negative machine checks for command wiring, service restoration, mesh orientation, and source-tree artifact isolation. r[onix.tenstorrent.model_performance.managed_benchmark]
- [x] [serial] Document the operator command and result location without changing production VibeThinker mesh policy. r[onix.tenstorrent.model_performance.managed_benchmark]

## Phase 3: Validation

- [ ] [serial] Run Rust tests, package and machine checks, formatting, pre-commit, and Cairn validation; record any hardware execution blocker without weakening restoration safety. r[onix.tenstorrent.model_performance.managed_benchmark]
