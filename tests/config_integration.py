#!/usr/bin/env python3
"""Exercise the interactive generator and certificate migration with a real core.
Usage: python3 tests/config_integration.py /path/to/hysteria
All files are temporary; networking is loopback-only; host mutation helpers are blocked.
"""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

repo = Path(__file__).resolve().parents[1]
core = Path(sys.argv[1]).resolve()


def free_port(kind):
    with socket.socket(type=kind) as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


with tempfile.TemporaryDirectory(prefix='hihy-config-test-') as temporary:
    root = Path(temporary)
    (root / 'bin').mkdir()
    (root / 'bin/appS').symlink_to(core)
    env = dict(os.environ, HIHY_ROOT_DIR=str(root), HIHY_BIN_LINK=str(root / 'hihy'))

    def shell(code, input=None):
        guards = '''
source "$1"
# Only configuration/core processes may run: no packages, firewall, services, or sysctls.
for unsafe in systemctl rc-service rc-update nft iptables ip6tables netfilter-persistent curl wget apt apk; do
    eval "$unsafe() { echo 'unexpected host command: $unsafe' >&2; exit 90; }"
done
sysctl() { return 0; }
allowPort() { return 0; }
lsof() { return 0; }
countdown() { sleep 1; }
serviceIsActive() { return 1; }
generate_qr() { return 0; }
# Keep the actual validation helper, restricting the generated listener to loopback.
eval "$(declare -f startInstallValidationProcess | sed '1s/startInstallValidationProcess/validateOnLoopback/')"
startInstallValidationProcess() {
    yq -i '.listen = "127.0.0.1" + .listen' "$1" || return 1
    validateOnLoopback "$@"
}
'''
        proc = subprocess.run(['bash', '-c', guards + code, 'config-test', str(repo / 'server/hy2.sh')],
                              input=input, text=True, capture_output=True, env=env, cwd=root, timeout=30)
        if proc.returncode:
            raise AssertionError(proc.stdout + proc.stderr)
        return proc.stdout

    def certificate(name, hostname):
        cert, key = root / f'{name}.crt', root / f'{name}.key'
        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                        '-keyout', str(key), '-out', str(cert), '-subj', f'/CN={hostname}',
                        '-addext', f'subjectAltName=DNS:{hostname}', '-days', '3'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        return cert, key

    def yaml(path):
        return json.loads(subprocess.check_output(['yq', '-o=json', '.', str(path)]))

    def connect(ca, expected_sni):
        shell('addOrUpdateYaml "$HIHY_BACKUP_FILE" serverAddress 127.0.0.1 string; generate_client_config')
        client = yaml(root / 'Hy2-integration-v2rayN.yaml')
        assert client['server'].startswith('127.0.0.1:'), client['server']
        assert client['tls']['sni'] == expected_sni
        assert client['tls']['insecure'] is False
        client['tls']['ca'] = str(ca)  # Test certificates use a local CA.
        client['lazy'] = False
        client['fastOpen'] = False
        client['socks5']['listen'] = f'127.0.0.1:{free_port(socket.SOCK_STREAM)}'
        client_path = root / 'client.json'
        client_path.write_text(json.dumps(client))
        with (root / 'server.log').open('w+') as server_log, (root / 'client.log').open('w+') as client_log:
            server = subprocess.Popen([str(core), '-c', str(root / 'conf/config.yaml'), 'server'],
                                      stdout=server_log, stderr=server_log)
            client_proc = None
            try:
                time.sleep(.4)
                assert server.poll() is None, 'generated server config failed'
                client_proc = subprocess.Popen([str(core), '-c', str(client_path), 'client'],
                                               stdout=client_log, stderr=client_log)
                deadline = time.monotonic() + 8
                while True:
                    client_log.seek(0)
                    log = client_log.read()
                    if 'connected to server' in log:
                        break
                    assert client_proc.poll() is None, log
                    assert time.monotonic() < deadline, log
                    time.sleep(.1)
            except Exception:
                server_log.seek(0)
                client_log.seek(0)
                print(server_log.read(), client_log.read(), file=sys.stderr)
                raise
            finally:
                for proc in (client_proc, server):
                    if proc is not None and proc.poll() is None:
                        proc.terminate()
                        try:
                            proc.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            proc.kill()
                            proc.wait()

    cert, key = certificate('initial', 'helloworld.com')
    for mode in ('brutal', 'bbr', 'reno'):
        port = free_port(socket.SOCK_DGRAM)
        answers = ['', '1', '2', str(cert), str(key), 'helloworld.com', str(port), '2']
        # Enter the original failure case then correct it within the same interaction.
        answers += {'brutal': ['3', '200', '10.5', '50', '10'], 'bbr': ['2', '2'], 'reno': ['1']}[mode]
        answers += ['test-password', '1', '1', 'Hello', 'Hello', '2', '2', 'integration']
        shell('setHysteriaConfig', '\n'.join(answers) + '\n')
        config = yaml(root / 'conf/config.yaml')
        if mode == 'brutal':
            assert config['bandwidth'] == {'up': '55mbps', 'down': '11mbps'}
        else:
            assert config['congestion']['type'] == mode
            assert 'bandwidth' not in config
        assert not list((root / 'conf').glob('.configure.*')), 'staging directory leaked'
        connect(cert, 'helloworld.com')

    cert, key = certificate('shared', '*.example.com')
    shell('publishSharedCertificate "$HIHY_ROOT_DIR/shared.crt" "$HIHY_ROOT_DIR/shared.key" example.com; '
          'migrateLocalHysteriaToSharedCertificate example.com node.example.com')
    connect(cert, 'node.example.com')
    print('PASS: real Brutal/BBR/Reno configuration, corrected numeric input, native clients and migrated certificate handshake')
