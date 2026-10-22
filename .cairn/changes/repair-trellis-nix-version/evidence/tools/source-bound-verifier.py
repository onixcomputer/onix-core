#!/usr/bin/env python3
"""Source-bound partial verifier for one isolated actual-model attempt."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
CFG = json.loads((ROOT / 'session.json').read_text())
WORK = Path(CFG['work'])
OUT = Path(CFG['evidence']) / 'verifier-receipts'
OUT.mkdir(exist_ok=True)
MANIFEST = json.loads((Path(CFG['evidence']) / 'input-identities.json').read_text())['source_sha256']
ALLOWED = set(CFG['allowed'])


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check():
    changed = []
    for relative, expected in MANIFEST.items():
        path = WORK / relative
        if relative not in ALLOWED and (not path.is_file() or sha(path) != expected):
            changed.append(relative)
    expected_sources = {relative for relative in MANIFEST if relative.startswith('src/')}
    sources = {str(path.relative_to(WORK)) for path in (WORK / 'src').rglob('*') if path.is_file()}
    if sources != expected_sources:
        changed += sorted(sources ^ expected_sources)
    if changed:
        raise RuntimeError('Frozen inputs changed: ' + ', '.join(changed))
    identities = {relative: sha(WORK / relative) for relative in sorted(ALLOWED)}
    for relative in ALLOWED:
        original = (ROOT / 'original' / relative).read_text()
        candidate = (WORK / relative).read_text()
        for escape in ['external_body', 'assume_specification', 'assume(', 'admit(', 'unimplemented!', 'todo!']:
            if candidate.count(escape) > original.count(escape):
                raise RuntimeError('New trust escape in ' + relative + ': ' + escape)
    return identities


def main():
    assert len(sys.argv) == 1, 'No verifier arguments are permitted'
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    actor = os.environ.get('NVR_VERIFIER_ACTOR', 'model-tool')
    receipt = {'at': stamp, 'actor': actor, 'scope': ['nix_version', 'properties'],
               'partial_not_full_acceptance': True, 'source_manifest': 'input-identities.json'}
    started = time.monotonic()
    try:
        receipt['source_sha256_before'] = check()
        command = ['bash', str(WORK / 'scripts/verus.sh'), str(WORK / 'src/lib.rs'),
                   '--verify-module', 'nix_version', '--verify-module', 'properties',
                   '--rlimit', '20', '--triggers-mode', 'silent']
        receipt['argv'] = command
        environment = os.environ.copy()
        environment['VERUS_ROOT'] = CFG['verus']
        environment['TMPDIR'] = str(ROOT / 'tmp')
        environment.pop('RUST_TOOLCHAIN', None)
        log = OUT / (stamp + '.log')
        with log.open('wb') as stream:
            process = subprocess.Popen(command, cwd=WORK, env=environment, stdout=stream,
                                       stderr=subprocess.STDOUT, start_new_session=True,
                                       stdin=subprocess.DEVNULL)
            try:
                receipt['exit'] = process.wait(timeout=240)
                receipt['timed_out'] = False
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
                receipt['exit'] = process.returncode
                receipt['timed_out'] = True
        receipt['source_sha256_after'] = check()
        assert receipt['source_sha256_before'] == receipt['source_sha256_after'], 'Inputs changed during the solver run'
        text = log.read_text(errors='replace')
        summaries = re.findall(r'verification results::[^\n]*', text)
        receipt['summaries'] = summaries
        receipt['raw_log'] = 'verifier-receipts/' + log.name
        receipt['passed_partial_verification'] = receipt['exit'] == 0 and bool(re.search(r'verification results::\s*[1-9][0-9]* verified,\s*0 errors', text))
        print(text)
        print(json.dumps(receipt))
        return 0 if receipt['passed_partial_verification'] else 1
    except (OSError, RuntimeError, AssertionError) as error:
        receipt['error'] = str(error)
        print('Source-bound verifier failed: ' + str(error), file=sys.stderr)
        return 1
    finally:
        receipt['elapsed_seconds'] = time.monotonic() - started
        (OUT / (stamp + '.json')).write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    sys.exit(main())
