#!/usr/bin/env python3
"""Bound one real command, logging directly so inherited daemon pipes cannot stall EOF."""
import argparse
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

parser = argparse.ArgumentParser()
parser.add_argument('--name', required=True)
parser.add_argument('--seconds', type=int, required=True)
parser.add_argument('--cwd', required=True)
parser.add_argument('--manifest', required=True)
parser.add_argument('command', nargs=argparse.REMAINDER)
args = parser.parse_args()
root = Path(__file__).resolve().parent
cfg = json.loads((root / 'session.json').read_text())
output = Path(cfg['evidence'])
command = args.command[1:] if args.command[:1] == ['--'] else args.command
assert command and args.seconds > 0
receipt = {'at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'argv': command,
           'cwd': args.cwd, 'source_manifest': args.manifest, 'deadline_seconds': args.seconds,
           'stdout_log': args.name + '.log'}
manifest_bytes = (output / args.manifest).read_bytes()
manifest = json.loads(manifest_bytes)
receipt['source_manifest_sha256'] = hashlib.sha256(manifest_bytes).hexdigest()

def source_mismatches():
    return [path for path, expected in manifest['source_sha256'].items()
            if hashlib.sha256((Path(manifest['root']) / path).read_bytes()).hexdigest() != expected]

receipt['source_mismatches_before'] = source_mismatches()
assert not receipt['source_mismatches_before'], receipt['source_mismatches_before']
environment = dict(os.environ, PATH=cfg['environment']['PATH'], VERUS_ROOT=cfg['verus'],
                   TMPDIR=str(root / 'tmp'), CARGO_TARGET_DIR='target',
                   CARGO_BUILD_JOBS='2', CARGO_INCREMENTAL='0', LC_ALL='C',
                   NIX_CONFIG=os.environ.get('NIX_CONFIG', '') + '\nmin-free = 0\nmax-free = 0')
environment.pop('RUST_TOOLCHAIN', None)
receipt['compiler_path_sha256'] = hashlib.sha256(environment['PATH'].encode()).hexdigest()

def interrupt(signum, frame):
    raise InterruptedError('Cancelled by owner')

started = time.monotonic()
with (output / receipt['stdout_log']).open('wb') as stream:
    process = subprocess.Popen(command, cwd=args.cwd, env=environment, stdout=stream,
                               stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                               start_new_session=True)
    signal.signal(signal.SIGTERM, interrupt)
    try:
        receipt['exit'] = process.wait(timeout=args.seconds)
        receipt['timed_out'] = False
    except (subprocess.TimeoutExpired, InterruptedError) as error:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        receipt['exit'] = process.returncode
        receipt['timed_out'] = isinstance(error, subprocess.TimeoutExpired)
        receipt['interrupted'] = isinstance(error, InterruptedError)
receipt['elapsed_seconds'] = time.monotonic() - started
receipt['finished_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
receipt['source_mismatches_after'] = source_mismatches()
text = (output / receipt['stdout_log']).read_text(errors='replace')
receipt['summaries'] = [line for line in text.splitlines() if re.match(
    r'verification results::|test result:|=== |[✓✗]|error[:\[]', line)]
(output / (args.name + '.json')).write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt, indent=2), flush=True)
sys.exit(0 if receipt['exit'] == 0 and not receipt['timed_out']
         and not receipt['source_mismatches_after'] else 1)
