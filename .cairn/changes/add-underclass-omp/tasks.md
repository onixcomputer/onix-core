## Phase 1: Implementation

- [x] [serial] Pin and export Underclass without advancing existing dependencies. r[onix.underclass.source]
- [x] [serial] Scope the persistent loopback service and runtime credentials to the two OMP workstations. r[onix.underclass.scope] r[onix.underclass.local-service] r[onix.underclass.secrets]
- [x] [serial] Install an additive native OMP provider with compatible Responses requests and session affinity. r[onix.underclass.omp]

## Phase 2: Verification

- [x] [serial] Build the package/provider, evaluate both selected machines and a negative control, and exercise real proxy authentication and OMP routing. r[onix.underclass.verification]
- [x] [serial] Record observed results, onboarding instructions and deployment limits, and validate the native Cairn change. r[onix.underclass.verification]

Evidence: `verification.json`. It records the desktop's device-flow enrollment and live inference. Aspen3 is Clan-deployed as a shared-pool client; the desktop remains a runtime install without a Clan deployment.
