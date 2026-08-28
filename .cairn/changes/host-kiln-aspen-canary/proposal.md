## Why

Onix Core currently runs the Seaglass Kiln adapter directly from the Radicle CI broker. That path does not select Aspen.

Kiln now has an explicit Aspen client and hosted extension. Aspen has a real bounded native-extension host library. The published revisions do not yet form a deployable service boundary.

The first private canary must preserve the existing Seaglass CI path until a separate Aspen path passes live checks. It must not use test support, local simulation, or automatic fallback as deployment evidence.

## What Changes

- Add a separate, disabled-by-default Kiln-on-Aspen canary module.
- Pin reviewed Aspen, Kiln, and Lattice revisions as immutable deployment inputs.
- Require a Kiln-owned host bridge for the Kiln Unix protocol and Aspen native-host composition.
- Require Aspen to deliver exact materialized provider completion values to hosted callbacks.
- Route the hosted Kiln workflow effect to Lattice through its published Unix workflow exchange.
- Keep the existing Seaglass broker adapter active during the canary.
- Add positive and negative module checks before any machine deployment.
- Run one operator-controlled canary on `britton-desktop` and retain bounded receipts.

## Impact

- **Repository:** `onix-core` gains one narrow service module, focused checks, profiles, and canary evidence.
- **Dependencies:** Aspen and Kiln need deployable contracts before module enablement can pass.
- **Authority:** The canary receives only its admitted Unix sockets, state roots, executable, and exact profiles.
- **Risk:** A false host implementation could turn process-local pilot evidence into an unsupported durability or CI claim.
- **Non-goals:** This change does not replace the current Seaglass CI route, claim production availability, or add automatic fallback.
