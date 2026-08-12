# Design

## Goal

Deploy the accepted P150x2 runtime and collect one bounded, privacy-safe production-selected observation without changing admission.

## Package boundary

`onix-core` consumes the accepted `tenstorrent.nix` commit through its generated `flake.lock`. The local package re-export list fails evaluation if either required output disappears. `britton-desktop` installs both outputs in its system closure.

## Observation boundary

The observation uses only physical devices `0` and `1` after competing services are stopped and ownership is checked. The run uses the installed production profile with admitted windows `[2, 4]`. It has finite sample, request, and wall-time bounds.

The monitor receives an explicit ordered list of regular worker receipt files. It does not scan a directory, watch a path, fetch a network resource, or include source paths, prompts, token IDs, request IDs, or binding identities in its output.

## Failure behavior

Any malformed input, duplicate event, parity failure, cleanup failure, timeout, terminal failure, or unsupported admission fails closed. The observation does not mutate the installed profile. Window `8` remains disabled.

## Validation

Validation requires the package re-export, exact host system build, activation, free-device preflight, bounded physical run, per-receipt telemetry validation, aggregate monitoring status `0`, and restoration of inactive competing services.
