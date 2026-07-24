# Open Notebook Bootstrap Security Specification Delta

## Purpose

Prevent Open Notebook bootstrap secrets from entering Nix derivations while preserving declarative non-secret provider and model configuration.

## ADDED Requirements

### Requirement: Bootstrap secret material stays outside the Nix store

r[onix.open_notebook.bootstrap.secret_boundary] The Open Notebook module MUST source API keys and equivalent secret bootstrap values from Clan-managed runtime secret files and MUST NOT interpolate those values into Nix derivations, store files, command arguments, or environment values.

#### Scenario: Runtime secret bootstrap succeeds

r[onix.open_notebook.bootstrap.secret_boundary.runtime]
- GIVEN non-secret provider metadata is declared in the Open Notebook settings
- AND the matching API key is present in a deployed Clan secret file
- WHEN the bootstrap service assembles and submits the credential payload
- THEN the provider receives the secret value at runtime
- AND the secret value is absent from Nix-built scripts and configuration files

#### Scenario: Inline secret is rejected

r[onix.open_notebook.bootstrap.secret_boundary.inline_rejected]
- GIVEN an operator places an `apiKey` or equivalent secret-bearing field in declarative Open Notebook settings
- WHEN the module evaluates
- THEN evaluation MUST fail with a migration diagnostic
- AND no derivation containing that value is produced

### Requirement: Non-secret bootstrap metadata remains declarative

r[onix.open_notebook.bootstrap.metadata] The Open Notebook module SHOULD preserve typed declarative configuration for credential identity, provider, endpoints, modalities, model registration, and default-model selection without treating those fields as secret transport.

#### Scenario: Metadata-only configuration evaluates

r[onix.open_notebook.bootstrap.metadata.positive]
- GIVEN a credential record contains only allowed non-secret metadata
- WHEN the module evaluates
- THEN evaluation succeeds
- AND the generated runtime bootstrap references the corresponding secret input without embedding its contents

### Requirement: Secret-boundary validation is authoritative

r[onix.open_notebook.bootstrap.validation] The repository MUST include positive and negative checks that prove runtime secret consumption and detect sentinel secret bytes in generated Nix derivations or closures.

#### Scenario: Store scan rejects sentinel leakage

r[onix.open_notebook.bootstrap.validation.sentinel]
- GIVEN a test configuration uses a unique sentinel API key
- WHEN the module and its generator derivations are evaluated
- THEN the check fails if the sentinel appears in any generated store-bound artifact
- AND the check passes when only a runtime secret-file reference is present
