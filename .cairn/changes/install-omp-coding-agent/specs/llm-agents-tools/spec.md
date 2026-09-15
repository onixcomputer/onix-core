# llm-agents Tools Specification Delta

## ADDED Requirements

### Requirement: The selected workstations install omp

r[onix.llm_agents.omp.scope] `britton-desktop` and `aspen3` MUST install the
`omp` agent package from the pinned `llm-agents` flake input. Every other
machine tagged `llm-client` MUST keep its current agent set.

#### Scenario: Selected machines install the agent

r[onix.llm_agents.omp.scope.selected]
- GIVEN the evaluated `environment.systemPackages` of the selected machines
- WHEN package names are rendered
- THEN `omp` MUST be present on `britton-desktop`
- AND `omp` MUST be present on `aspen3`

#### Scenario: Unselected llm-client machines stay unchanged

r[onix.llm_agents.omp.scope.unselected]
- GIVEN an `llm-client` machine outside the selection
- WHEN its evaluated package names are rendered
- THEN `omp` MUST be absent

### Requirement: The agent comes from the pinned input

r[onix.llm_agents.omp.source] The agent MUST come from the pinned
`llm-agents` flake input through the existing `llm-agents` Clan module. The
change MUST NOT add a flake input, a lock node, or an out-of-band version
pin.

#### Scenario: No second source is introduced

r[onix.llm_agents.omp.source.single]
- GIVEN the modified service inventory and the flake input list
- WHEN the agent package is resolved for the selected machines
- THEN it MUST be the `omp` package of the pinned `llm-agents` input
- AND the flake input list MUST be unchanged

### Requirement: The addition has positive and negative verification

r[onix.llm_agents.omp.verification] The repository MUST verify the scope
with both positive and negative checks, and the packaged agent MUST pass its
own smoke test.

#### Scenario: The focused scope check accepts and rejects

r[onix.llm_agents.omp.verification.focused]
- GIVEN the evaluated package lists of two selected machines and one
  unselected `llm-client` machine
- WHEN the focused check runs
- THEN it MUST accept `omp` on both selected machines
- AND it MUST reject a bogus agent name on those machines
- AND it MUST reject `omp` on the unselected machine

#### Scenario: The configured package runs

r[onix.llm_agents.omp.verification.smoke]
- GIVEN the agent package entry taken from a selected machine's evaluated
  package list
- WHEN that package is built and its smoke test runs
- THEN the smoke test MUST succeed

### Requirement: The selected machines run an agent-equipped system

r[onix.llm_agents.omp.deployment] Both selected machines MUST be deployed to
a system whose package list contains the agent, and the agent executable
MUST resolve on the target.

#### Scenario: The deployed path contains the agent

r[onix.llm_agents.omp.deployment.path]
- GIVEN the deployed system on `britton-desktop` and `aspen3`
- WHEN the agent executable is resolved on each target
- THEN each host MUST report the packaged executable
