## ADDED Requirements

### Requirement: Fail-closed Claude quota recovery

r[onix.underclass.claude_readmission] Britton's generation-managed
Underclass service MUST use a locked fork revision whose Claude usage poll
readmits a cooling account only after observing valid headroom in every
reported quota window. Missing or exhausted usage MUST NOT clear a cooldown;
an exhausted window MAY extend but MUST NOT shorten its future reset deadline.
The poll MUST NOT redeem a banked reset credit or require a new OAuth login.

#### Scenario: Externally reset account

- GIVEN a persisted Claude cooldown and a fresh usage snapshot with valid
  seven-day headroom
- WHEN the service polls the account's first-party usage endpoint
- THEN it MUST persist `healthy` and serve a request via the existing OMP
  provider on Britton and its Aspen3 and Mac clients
- AND it MUST leave another exhausted Claude account cooling

#### Scenario: Unknown or exhausted usage

- GIVEN a failed usage poll, unknown utilization or any exhausted window
- WHEN the pool reconciles its Claude account statuses
- THEN the account MUST NOT be readmitted and no reset credit MUST be redeemed

#### Scenario: Scoped deployment

- GIVEN the running Britton generation and its persistent account state
- WHEN this pin advances
- THEN only Underclass-related runtime paths MAY change
- AND the listener, state directory, key, SSH tunnels and unrelated services
  MUST remain unchanged

### Requirement: Managed multi-backend OMP provider

r[onix.underclass.claude_omp] The managed Underclass OMP provider MUST
discover only the pool's Codex, OpenCode Go and Claude models using the
current per-machine proxy key. It MUST preserve the working Codex and
OpenCode Go request shapes and use Anthropic Messages with the Claude Code
request identity and headers for Claude models. It MUST NOT send any
credential or OAuth token into a Nix store path.

#### Scenario: Multi-backend catalog

- GIVEN the pool advertises a Codex, OpenCode Go and Claude model
- WHEN OMP refreshes its Underclass model catalog
- THEN it MUST expose all three with their backend-specific API shapes
- AND it MUST NOT advertise Copilot-only models through this provider

#### Scenario: Claude subscription request

- GIVEN OMP selects `underclass/claude-haiku-5-5`
- WHEN it constructs an Anthropic Messages request through the proxy
- THEN it MUST attach the Claude Code identity and headers
- AND it MUST use the existing pool key without modifying the direct
  Anthropic provider login
