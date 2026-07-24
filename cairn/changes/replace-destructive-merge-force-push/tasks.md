## Phase 1: Safe push policy

- [ ] [serial] Extract pure push-mode and command-argument construction from subprocess orchestration. r[onix.merge_when_green.push.validation]
- [ ] [serial] Use normal pushes for new and fast-forward branch updates. r[onix.merge_when_green.push.default_safe]
- [ ] [serial] Require explicit operator intent before any rewritten-history push. r[onix.merge_when_green.push.lease]
- [ ] [serial] Observe the remote branch object and bind rewritten pushes to an exact force-with-lease value. r[onix.merge_when_green.push.lease]
- [ ] [serial] Report stale-lease rejection without retrying as an unconditional force push. r[onix.merge_when_green.push.lease]

## Phase 2: Validation

- [ ] [serial] Add positive command tests for new, fast-forward, and exact-lease pushes. r[onix.merge_when_green.push.validation]
- [ ] [serial] Add negative local-remote tests for concurrent updates and absent explicit rewrite intent. r[onix.merge_when_green.push.validation]
- [ ] [serial] Assert no supported command path emits bare `--force`. r[onix.merge_when_green.push.default_safe]
- [ ] [serial] Run focused pytest plus Cairn validation and gates. r[onix.merge_when_green.push.validation]
