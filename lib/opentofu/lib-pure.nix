# Pure OpenTofu Library Functions - Lightweight Wrapper
#
# This file provides backward compatibility for the legacy lib-pure.nix interface.
# All functionality has been moved to the modular pure/ directory.
#
# For new code, prefer importing from ./pure/default.nix directly.
# This wrapper ensures existing tests and consumers continue to work.
{ lib }:

# Import the new modular pure functions and re-export them
# This maintains exact API compatibility while using the new structure
import ./pure/default.nix { inherit lib; }
