## Phase 1: Implementation

- [x] [serial] Delete the unreferenced `hermes` Home Manager profile and the `hermes-agent-desktop` check with the bindings only it used. r[onix.hermes_agent.install] r[onix.hermes_agent.scope]
- [x] [serial] Drop the Hermes requirement markers from the `llm-agents-settings` check and fixture, and align the fixture's positive case with the shared `llm-client` list. r[onix.hermes_agent.validation] r[onix.hermes_desktop.validation]

## Phase 2: Verification

- [x] [serial] Run the home-manager and module checks, confirm the deployed machines' toplevels are unchanged, and run `cairn validate`. r[onix.hermes_agent.install] r[onix.hermes_desktop.install]
