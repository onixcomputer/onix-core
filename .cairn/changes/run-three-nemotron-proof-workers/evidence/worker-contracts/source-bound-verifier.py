#!/usr/bin/env python3
"""Temporary source-bound verifier for the three-role campaign, not an agent framework."""
import collections
import datetime
import difflib
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
TRELLIS = Path('/home/brittonr/git/OnixResearch/trellis')
VERUS = Path('/nix/store/cb02jr7r1a2k8k2hlahmk8c90421czvq-octet-production-verus-0.2026.05.17.e479cce')
spec = importlib.util.spec_from_file_location('existing_loop', '/home/brittonr/git/onix-core/scripts/nemotron-verus/loop.py')
existing_loop = importlib.util.module_from_spec(spec)
spec.loader.exec_module(existing_loop)
BANNED = {'assume', 'admit', 'assume_specification', 'external_body', 'external', 'unsafe', 'trusted', 'unimplemented', 'todo', 'include', 'include_str', 'include_bytes', 'decreases_when', 'extern'}


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ('repair', 'composition'):
        raise ValueError('Exactly one permitted worker role is required')
    role = sys.argv[1]
    base = ROOT / role
    work = base / 'work'
    frozen = json.loads((base / 'frozen-inputs.json').read_text())
    baseline = json.loads((ROOT / 'input-identities.json').read_text())
    source_names = {name for name in frozen if name.startswith('src/')}
    actual = {str(p.relative_to(work)) for p in (work / 'src').rglob('*.rs')}
    if actual != source_names:
        raise ValueError('Source-file set changed')
    changed = {}
    patches = []
    for name, digest in frozen.items():
        path = work / name
        if path.is_symlink() or not path.is_file():
            raise ValueError('Frozen input missing or symlinked: ' + name)
        candidate_digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if candidate_digest == digest:
            continue
        if role != 'repair' or not name.startswith('src/'):
            raise ValueError('Frozen input changed: ' + name)
        original = ROOT / 'original-inputs' / name
        old = original.read_text()
        new = path.read_text()
        before = collections.Counter(existing_loop.tokens(old))
        after = collections.Counter(existing_loop.tokens(new))
        if any(after[word] > before[word] for word in BANNED) or after['#'] > before['#']:
            raise ValueError('New trust escape or attribute: ' + name)
        changed[name] = candidate_digest
        patches.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True), fromfile='before/' + name, tofile='candidate/' + name))
    # These guards check input integrity and obvious trust escapes, not theorem equivalence.
    # Parent review must separately preserve contracts and executable algorithms.
    if role == 'composition':
        candidate = work / 'composition.rs'
        if candidate.is_symlink() or not candidate.is_file():
            raise ValueError('Write a real composition.rs proof witness before verification')
        text = candidate.read_text()
        tokens = existing_loop.tokens(text)
        if BANNED.intersection(tokens) or '#' in tokens:
            raise ValueError('Composition introduces forbidden trust or attributes')
        if not re.search(r'\bpub\s+proof\s+fn\s+', text) or 'ensures' not in tokens:
            raise ValueError('Composition requires a public proof with a real postcondition')
        if re.search(r'\brequires\s+false\b|\bensures\s+true\s*\{', text):
            raise ValueError('Vacuous composition contract')
        if re.search(r'\bpub\s+(?:exec\s+)?fn\s+', text):
            raise ValueError('This role is proof-only, not a runtime feature implementation')
        changed['composition.rs'] = hashlib.sha256(candidate.read_bytes()).hexdigest()
    argv = ['bash', str(TRELLIS / 'scripts/verus.sh'), str(work / 'src/lib.rs'), '--rlimit', '20', '--triggers-mode', 'silent']
    if role == 'composition':
        argv += ['--verify-module', 'nemotron_composition']
    env = os.environ.copy()
    env.pop('RUST_TOOLCHAIN', None)
    env['VERUS_ROOT'] = str(VERUS)
    env['TMPDIR'] = str(base / 'tmp')
    identity = str(time.time_ns())
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    done = subprocess.run(argv, cwd=TRELLIS, env=env, capture_output=True, text=True, timeout=300)
    output = done.stdout + done.stderr
    (base / ('verify-' + identity + '.log')).write_text(output)
    if patches:
        (base / ('candidate-' + identity + '.diff')).write_text(''.join(patches))
    result = {'role': role, 'at': started, 'argv': argv, 'exit': done.returncode, 'changed_sha256': changed, 'frozen_inputs_unchanged': role == 'composition' or not changed, 'requires_parent_contract_review': role == 'repair', 'log': 'verify-' + identity + '.log', 'baseline_identity': baseline['sha256']['src/lib.rs']}
    (base / ('verify-' + identity + '.json')).write_text(json.dumps(result, indent=2) + '\n')
    print(output)
    return done.returncode


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
        print('Candidate rejected: ' + str(error), file=sys.stderr)
        sys.exit(1)
