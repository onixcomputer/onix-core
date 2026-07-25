# artifact-auth two-source deployment and probe evidence — 2026-07-25

## Bound source

- RID: `rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f`
- Reviewed commit: `799459346d5416fbd7b9f55840a7371441b55afa`
- Deterministic `git archive --format=tar` BLAKE3: `246a7cad91e7e8a158e22da21f3bff3e61aa0431a58936b5a739178bc62064c7`
- Accepted identity revision: `c22900ae6b7b5637aa0e378fe00503cf02c6d1bf`
- Author and Bonsai signed `main`; Pine remained offline. Two signatures satisfy the configured two-of-three threshold.
- Verified public bundle BLAKE3: `7f96561a705151266e83641bdc53cf692518f0e5507f10acc3074c45d6ebca5f`

## Deployment

Policy revision `a3f5a18b36a0c874c1fce0d47acee19932f4d931` derives Aspen seeding, Aspen HTTPS routes, and desktop seeding from the ordered Bounded Exec plus `artifact-auth` RID set. The separately owned CI configuration remains Bounded Exec-only.

| Role | Node | Fingerprint | Closure | Reconciled count |
|---|---|---|---|---:|
| Primary + HTTPS | `z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8` | `SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE` | `/nix/store/0j4sb2mnmmy6skiy89hy83p9lsn6rdwq-nixos-system-aspen1-26.11.20260629.7a1a647` | 2 |
| Native-only replica | `z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG` | `SHA256:JHQTPqoMr4kLqBsrAPSRNXUuzETiHAoiKBM/VWftmEg` | `/nix/store/a2md0l6n2g56xcg44v93xalyc6zcaxp1-nixos-system-britton-desktop-26.11.20260629.7a1a647` | 2 |

Both imported stores retain the author and Bonsai namespace `main`, root, and signed-reference tips. Desktop startup re-ran its private/public pairing and pinned-fingerprint verifier. Both restarted nodes reported their preserved node IDs.

## Isolated native probes

Fresh dynamic clients ran under transient systemd units with `IPAddressDeny=any`, one surviving seed `/32` allowlist, inaccessible production storage, inaccessible secrets, empty capabilities, and signed-reference feature level `parent`. Each drill stopped the opposite seed and restored it through a trap.

- Aspen-only client `z6MkkQEGLf4NPLDzwguTX7LWQYxQvWnbjFvh2mECYHzuPPvb` resolved the reviewed commit and source BLAKE3; undeclared RID access, public egress, storage access, and secret access were blocked.
- Desktop-only client `z6Mku6MfTxgiBW2gtDpAJqk6Cf6FStVbNx4JrcyDjb9bUTqQ` resolved the reviewed commit and source BLAKE3; undeclared RID access, public egress, storage access, and secret access were blocked.
- Both production node and policy services were active after restoration.

## HTTPS probes

`https://git.onix.computer/z4JGYYW7WsesXUq7MXVdx16Fawu2f.git` cloned the exact reviewed commit and reproduced the source BLAKE3. An unknown third RID, `git-receive-pack`, and the root path each returned HTTP 404. Only Aspen terminates the admitted public route; the desktop remains native-only.

## Claim boundary

This evidence proves bounded transport admission and observed availability for the supplied source identity. It does not prove source or Valence behavior correctness, live delegate replacement, third-delegate convergence, private confidentiality, automatic HTTPS failover, geographic independence, protocol-enforced mandatory CI, or release readiness.
