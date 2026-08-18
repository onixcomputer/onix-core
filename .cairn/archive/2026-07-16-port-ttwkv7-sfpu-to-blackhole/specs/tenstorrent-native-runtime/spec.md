# tenstorrent-native-runtime Delta

## ADDED Requirements

### Requirement: ttWKV7 architecture-selected SFPU lifecycle
r[onix.tenstorrent.native_runtime.ttwkv7.architecture_sfpu] The packaged ttWKV7 constant-tile generator MUST use the pinned Metalium runtime's architecture-selected SFPU start and finish helpers instead of invoking a Wormhole-only address-modifier primitive directly.

#### Scenario: Blackhole compiles the constant-tile generator
- GIVEN the packaged ttWKV7 chunked kernel and the pinned Blackhole Metalium LLK
- WHEN TT-Metal JIT-compiles the constant-tile generator for a P150
- THEN the SFPU lifecycle resolves through the Blackhole helper implementation
- AND the source does not require `math::set_addr_mod_base()`

#### Scenario: Wormhole lifecycle remains delegated to Metalium
- GIVEN the packaged ttWKV7 chunked kernel and the pinned Wormhole Metalium LLK
- WHEN TT-Metal JIT-compiles the constant-tile generator for Wormhole
- THEN the same helper calls select the Wormhole-specific address-modifier setup and cleanup
- AND ttWKV7 does not duplicate that architecture policy

#### Scenario: Portable helper regression is detected
- GIVEN the installed ttWKV7 chunked kernel source
- WHEN package validation inspects the SFPU prologue and epilogue
- THEN validation requires the architecture-selected start and finish helper calls
- AND validation fails if the direct Wormhole-only primitive is present
