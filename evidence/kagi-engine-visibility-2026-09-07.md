# Visible locked Kagi engine

The user reported that Kagi was still absent from the engine list.
The previous UI omitted unauthorized engines entirely. That behavior confused an unavailable engine with one that required authorization.

`modules/searxng/kagi-locked-engine.html` now shows `kagi-private` at the top of Engines → General before authorization.
The row says **Locked** and links to the existing unlock form. It contains no enable input.
An unavailable engine uses the same row with an **Unavailable** status.
After authorization, the placeholder disappears and the normal engine row remains.
The native engine-access check was not changed.

The baseline check found an existing whitespace-sensitive assertion after HTML formatting.
The form test now checks parsed HTML attributes and normalized text instead of raw attribute spacing.
New positive and negative cases cover the locked and unavailable rows, absence of an enable control, and omission of the placeholder for authorized users and other categories.

Task 1201 passed Ruff, scoped Statix, module checks, the packaged Python/JavaScript suite, and `git diff --check`, then deployed the change.
The deployed system is `/nix/store/0hq8xf1jvfp13xi07v2xi3ahn09qk5qs-nixos-system-aspen1-26.11.20260819.afe3d8a`.

An anonymous Obscura fetch verified:

- the engine row is present;
- its name is `kagi-private`;
- its state is `Locked`;
- it links to `#kagi-access-status`;
- it has zero enable inputs.

Obscura did not toggle the radio tab through a label click. The second probe selected the tab directly through its checked property.
These checks prove the deployed row is present. They do not claim a successful submission in the user's own browser.
No credential was used or printed for the visibility probes. No push occurred.
