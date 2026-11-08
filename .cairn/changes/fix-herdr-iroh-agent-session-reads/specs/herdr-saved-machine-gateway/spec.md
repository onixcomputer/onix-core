# Saved-machine Gateway Delta

## MODIFIED Requirements

### Requirement: Requested gateway source
r[onix.herdr_gateway.pin] britton-desktop and aspen3 MUST run herdr-iroh from commit `a342b855dbd6483fe6407baba69d28ecdac71501` with its saved-machine gateway enabled and existing peer authorization preserved.

#### Scenario: Gateway source is deployed
- **GIVEN** the approved gateway pin and the existing relay authorization
- **WHEN** the requested release is activated
- **THEN** the running relay executable MUST match the package built from that exact source revision.

## ADDED Requirements

### Requirement: Session reads use Herdr's AgentInfo reply
r[onix.herdr_gateway.agent_info] The relay MUST read `agent_session`, `cwd` and `name` from the `AgentInfo` object under `result.agent` in Herdr's protocol 22 `agent.get` reply, so that `relay.agent_session`, `relay.answer` and status webhooks see the pane's omp session.

#### Scenario: A live omp pane is read
- **GIVEN** an allowlisted peer and a running Herdr pane whose agent is omp with a path session
- **WHEN** the peer calls `relay.agent_session` for that pane
- **THEN** the reply MUST report `supported: true` with the session's messages and tool calls.
