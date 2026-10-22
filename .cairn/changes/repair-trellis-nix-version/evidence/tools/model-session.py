#!/usr/bin/env python3
"""One owned Spark maintenance window and actual bounded model attempt."""
import concurrent.futures
import datetime
import hashlib
import json
import os
from pathlib import Path
import shlex
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.request

CFG = json.loads(Path(sys.argv[1]).read_text())
ROOT = Path(CFG['root'])
OUT = Path(CFG['evidence'])
HOSTS = ['spark-e442.local', 'spark-a0a0.local', '192.168.1.233']
LAUNCHER = '/home/brittonr/.local/share/onix-nemotron35/nemotron-spark.sh'
STATE = '/home/brittonr/.local/share/onix-nemotron35'
MODEL = 'nemotron-3.5-super-vl'
SSH = ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10']


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def save(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2) + '\n')


def remote(host, command, seconds=180):
    result = subprocess.run(SSH + ['brittonr@' + host, command], text=True,
                            capture_output=True, timeout=seconds)
    if result.returncode:
        raise RuntimeError(f'{host}: {command}: {result.stderr.strip()}')
    return result.stdout


def inspect(host, identity='vllm_dsv41'):
    return json.loads(remote(host, 'docker inspect ' + shlex.quote(identity)))[0]


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def completion(host, wait):
    code = '''import json,time,urllib.request,urllib.error
end=time.monotonic()+WAIT
request={"model":"deepseek-v4.1-flash","messages":[{"role":"user","content":"Compute 6 * 7. Reply with only the integer."}],"temperature":0,"max_tokens":32}
last=None
while True:
 try:
  r=urllib.request.Request("http://127.0.0.1:8888/v1/chat/completions",data=json.dumps(request).encode(),headers={"Content-Type":"application/json"})
  with urllib.request.urlopen(r,timeout=35) as stream: answer=json.load(stream)
  break
 except (urllib.error.URLError,TimeoutError,ConnectionError) as error:
  last=str(error)
  if time.monotonic()>=end: raise RuntimeError(last)
  time.sleep(3)
assert answer["choices"][0]["message"]["content"].strip()=="42",answer
print(json.dumps({"request":request,"response":answer}))
'''.replace('WAIT', str(wait))
    return json.loads(remote(host, 'python3 -c ' + shlex.quote(code), wait + 90))


def stop_process(process):
    if process is not None and process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()


def restore(original, owned):
    result = {'started_at': now(), 'owned_replica_id': owned}
    if owned:
        active = inspect(HOSTS[0], owned)
        assert active['Id'] == owned
        assert active['Config']['Labels']['org.onix.nemotron35.state'] == STATE
        result['model_stop'] = remote(HOSTS[0], 'docker stop --timeout 60 ' + owned)
        result['model_remove'] = remote(HOSTS[0], 'docker rm ' + owned)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        result['worker_starts'] = list(pool.map(
            lambda item: {'host': item['host'], 'output': remote(item['host'], 'docker start ' + item['container']['Id'])},
            original[1:]))
    result['head_start'] = remote(HOSTS[0], 'docker start ' + original[0]['container']['Id'])
    comparisons = []
    for saved in original:
        old = saved['container']
        current = inspect(saved['host'], old['Id'])
        checks = {key: old[key] == current[key] for key in ['Id', 'Image', 'Config', 'HostConfig']}
        checks['Mounts'] = sorted(old['Mounts'], key=lambda x: x['Destination']) == sorted(current['Mounts'], key=lambda x: x['Destination'])
        comparisons.append({'host': saved['host'], 'id': old['Id'], 'running': current['State']['Running'], 'matches': checks})
        assert current['State']['Running'] and all(checks.values()), comparisons[-1]
    result['comparisons'] = comparisons
    result['completion'] = completion(HOSTS[0], 900)
    result['verified'] = True
    result['finished_at'] = now()
    save('restoration.json', result)
    print(json.dumps({'stage': 'restored', 'verified': True, 'completion': '42', 'comparisons': comparisons}), flush=True)


def wait_model_logs():
    process = subprocess.Popen(SSH + ['brittonr@' + HOSTS[0], 'docker logs --follow onix-nemotron35'],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, bufsize=1, start_new_session=True)
    timer = threading.Timer(1200, lambda: stop_process(process))
    timer.start()
    ready = False
    try:
        with (OUT / 'nemotron-startup.log').open('w') as stream:
            for line in process.stdout:
                stream.write(line)
                stream.flush()
                if 'Application startup complete' in line:
                    ready = True
                    break
    finally:
        timer.cancel()
        stop_process(process)
    if not ready:
        raise RuntimeError('No actual Nemotron application-startup marker within the bounded log stream')


def tunnel():
    command = SSH + ['-v', '-o', 'ExitOnForwardFailure=yes', '-N',
                     '-L', '127.0.0.1:18000:127.0.0.1:8000', 'brittonr@' + HOSTS[0]]
    process = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                               text=True, bufsize=1, start_new_session=True)
    stream = (OUT / 'tunnel.log').open('w')
    timer = threading.Timer(30, lambda: stop_process(process))
    timer.start()
    ready = False
    for line in process.stderr:
        stream.write(line)
        stream.flush()
        if 'Local forwarding listening on 127.0.0.1 port 18000' in line:
            ready = True
            break
    timer.cancel()
    if not ready:
        stop_process(process)
        stream.close()
        raise RuntimeError('Authenticated SSH forwarding did not become ready')
    def drain():
        for line in process.stderr:
            stream.write(line)
        stream.close()
    threading.Thread(target=drain, daemon=True).start()
    return process


def main():
    original = []
    owned = None
    displaced = False
    forwarding = None
    attempt = {'started_at': now(), 'actual_model_attempt': False}
    try:
        with socket.socket() as check:
            check.bind(('127.0.0.1', 18000))
        assert remote(HOSTS[0], 'sha256sum ' + LAUNCHER).split()[0] == CFG['launcher_sha256'], 'Remote launcher differs from the inspected pinned source'
        existing = remote(HOSTS[0], "docker ps -a --format '{{.Names}}'").splitlines()
        assert 'onix-nemotron35' not in existing, 'Refusing a pre-existing named replica'
        for host in HOSTS:
            current = inspect(host)
            assert current['State']['Running'], 'Original rank was not running: ' + host
            original.append({'host': host, 'container': current})
        private = ROOT / 'original-containers-private.json'
        private.write_text(json.dumps(original))
        private.chmod(0o600)
        preflight = completion(HOSTS[0], 0)
        save('cutover.json', {'at': now(), 'preflight_completion': preflight,
            'containers': [{'host': item['host'], 'id': item['container']['Id'], 'image': item['container']['Image'],
                            'config_sha256': digest(item['container']['Config']),
                            'host_config_sha256': digest(item['container']['HostConfig'])} for item in original]})
        print('Original three-rank inference recorded; beginning the owned temporary cutover.', flush=True)
        displaced = True
        remote(HOSTS[0], 'docker stop --timeout 60 ' + original[0]['container']['Id'])
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(lambda item: remote(item['host'], 'docker stop --timeout 60 ' + item['container']['Id']), original[1:]))
        launch = remote(HOSTS[0], 'bash ' + LAUNCHER + ' start')
        replica = inspect(HOSTS[0], 'onix-nemotron35')
        owned = replica['Id']
        assert replica['Config']['Labels']['org.onix.nemotron35.state'] == STATE
        save('nemotron-launch.json', {'at': now(), 'id': owned, 'image': replica['Image'], 'output': launch})
        print('Pinned replica launched; waiting on its real startup log stream.', flush=True)
        wait_model_logs()
        forwarding = tunnel()
        with urllib.request.urlopen('http://127.0.0.1:18000/v1/models', timeout=30) as stream:
            save('models.json', json.load(stream))
        request = {'model': MODEL, 'messages': [{'role': 'user', 'content': 'Compute 6 * 7. Reply with only the integer.'}],
                   'temperature': 0, 'max_tokens': 64, 'chat_template_kwargs': {'enable_thinking': False}}
        query = urllib.request.Request('http://127.0.0.1:18000/v1/chat/completions', data=json.dumps(request).encode(), headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(query, timeout=180) as stream:
            response = json.load(stream)
        assert response['choices'][0]['message']['content'].strip() == '42', response
        save('actual-completion.json', {'at': now(), 'request': request, 'response': response})
        print('Actual Nemotron completion established; starting the bounded isolated worker.', flush=True)
        attempt['actual_model_attempt'] = True
        process = None
        try:
            with (OUT / 'transcript.jsonl').open('wb') as transcript:
                process = subprocess.Popen(CFG['argv'], cwd=CFG['work'], env=CFG['environment'],
                                           stdout=transcript, stderr=subprocess.STDOUT, start_new_session=True,
                                           stdin=subprocess.DEVNULL)
                attempt['exit'] = process.wait(timeout=1800)
                attempt['timed_out'] = False
        except subprocess.TimeoutExpired:
            attempt['timed_out'] = True
            stop_process(process)
            attempt['exit'] = process.returncode
        finally:
            for relative in CFG['allowed']:
                source = Path(CFG['work']) / relative
                destination = OUT / 'model-candidate' / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                if source.is_file():
                    destination.write_bytes(source.read_bytes())
            if (Path(CFG['work']) / 'findings.md').is_file():
                (OUT / 'model-findings.md').write_bytes((Path(CFG['work']) / 'findings.md').read_bytes())
        final_env = os.environ.copy()
        final_env['NVR_VERIFIER_ACTOR'] = 'parent-check-of-raw-model-final'
        checked = subprocess.run([sys.executable, str(ROOT / 'source-bound-verifier.py')], cwd=CFG['work'], env=final_env,
                                 capture_output=True, text=True, timeout=300)
        (OUT / 'raw-model-final-check.log').write_text(checked.stdout + checked.stderr)
        attempt['raw_model_final_verifier_exit'] = checked.returncode
        attempt['raw_model_candidate_sha256'] = {relative: hashlib.sha256((OUT / 'model-candidate' / relative).read_bytes()).hexdigest() for relative in CFG['allowed']}
    except BaseException as error:
        attempt['error'] = repr(error)
        print('Campaign error: ' + repr(error), flush=True)
    finally:
        attempt['finished_at'] = now()
        save('attempt.json', attempt)
        stop_process(forwarding)
        save('tunnel-cleanup.json', {'at': now(), 'owned_tunnel_closed': forwarding is not None})
        if displaced:
            restore(original, owned)
    print(json.dumps(attempt), flush=True)
    return 0 if attempt.get('actual_model_attempt') else 1


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, lambda signum, frame: (_ for _ in ()).throw(RuntimeError('Session terminated')))
    if len(sys.argv) > 2 and sys.argv[2] == '--restore':
        original = json.loads((ROOT / 'original-containers-private.json').read_text())
        launch = json.loads((OUT / 'nemotron-launch.json').read_text()) if (OUT / 'nemotron-launch.json').exists() else {}
        restore(original, launch.get('id'))
    else:
        sys.exit(main())
