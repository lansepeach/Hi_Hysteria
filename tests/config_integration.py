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
    (root / 'legacy').touch()  # Installation marker; all service calls are mocked.
    env = dict(os.environ, HIHY_ROOT_DIR=str(root), HIHY_BIN_LINK=str(root / 'hihy'),
               HIHY_SERVICE_FILE=str(root / 'service'), HIHY_INIT_SERVICE=str(root / 'init'),
               HIHY_LEGACY_SERVICE=str(root / 'legacy'), HIHY_PID_FILE=str(root / 'pid'))

    def shell(code, input=None):
        guards = '''
source "$1"
# Only configuration/core processes may run: no packages, firewall, services, or sysctls.
for unsafe in systemctl rc-service rc-update nft iptables ip6tables netfilter-persistent curl wget apt apk; do
    eval "$unsafe() { echo 'unexpected host command: $unsafe' >&2; exit 90; }"
done
sysctl() { echo 'unexpected global sysctl change' >&2; exit 90; }
allowPort() { return 0; }
lsof() { if serviceIsActive; then echo 424242; fi; }
getHihyServicePID() { echo 424242; }
countdown() { sleep 1; }
serviceIsActive() { [ -f "$HIHY_ROOT_DIR/service-running" ]; }
serviceStop() { rm -f "$HIHY_ROOT_DIR/service-running"; }
serviceStart() { touch "$HIHY_ROOT_DIR/service-running"; }
waitHihyServiceHealthy() { serviceIsActive; }
removeOwnedFirewallRules() { return 0; }
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
            server = subprocess.Popen([str(core), '--disable-update-check', '-c', str(root / 'conf/config.yaml'), 'server'],
                                      stdout=server_log, stderr=server_log)
            client_proc = None
            try:
                time.sleep(.4)
                assert server.poll() is None, 'generated server config failed'
                client_proc = subprocess.Popen([str(core), '--disable-update-check', '-c', str(client_path), 'client'],
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
    retained_outbounds = None
    port = free_port(socket.SOCK_DGRAM)
    for mode in ('brutal', 'bbr', 'reno', 'brutal-low'):
        answers = ['', '1', '2', str(cert), str(key), 'helloworld.com', str(port), '2']
        # Enter the original failure case then correct it within the same interaction.
        answers += {'brutal': ['3', '200', '10.5', '50', '10'], 'bbr': ['2', '2'],
                    'reno': ['1'], 'brutal-low': ['3', '10', '1', '1']}[mode]
        if mode == 'bbr':
            answers += ['test-password', '1', '2', 'http://127.0.0.1:9', '1', '1', '2', '2', 'integration']
        else:
            answers += ['test-password', '1', '1', 'Hello', 'Hello', '2', '2', 'integration']
        if mode == 'brutal':
            shell('setHysteriaConfig', '\n'.join(answers) + '\n')
        else:
            # Check the actual wizard: every input must happen before serviceStop.
            (root / 'service-running').touch()
            shell('''
read() { serviceIsActive || { echo 'service stopped during input' >&2; exit 91; }; builtin read "$@"; }
changeServerConfig
''', '\n'.join(answers) + '\n')
            assert (root / 'service-running').exists()
            (root / 'service-running').unlink()
            assert list((root / 'result/snapshots').glob('reconfigure.*/config.yaml'))
        config = yaml(root / 'conf/config.yaml')
        if mode == 'brutal':
            assert config['bandwidth'] == {'up': '55mbps', 'down': '11mbps'}
        elif mode == 'brutal-low':
            assert config['quic']['initStreamReceiveWindow'] >= 16384
            assert config['quic']['maxConnReceiveWindow'] <= 96 * 1024 * 1024
        else:
            assert config['congestion']['type'] == mode
            assert 'bandwidth' not in config
        assert config['sniff']['enable'] is True
        assert 'enabled' not in config['sniff']
        if mode != 'brutal':
            assert config['auth']['type'] == 'command', 'reconfiguration disabled IP monitoring'
            assert config['auth']['password'] == 'test-password'
            assert config['outbounds'] == retained_outbounds, 'reconfiguration lost SOCKS/direct outbounds'
            assert config['resolver']['udp']['addr'] == '127.0.0.1:5353'
            assert config['sniff']['timeout'] == '3s', 'custom sniff settings were reset'
            assert 'reject(suffix:blocked.example.com)' in (root / 'acl/acl.txt').read_text()
            assert yaml(root / 'conf/backup.yaml')['socks5_status'] is True
        assert config['trafficStats']['listen'].startswith('127.0.0.1:')
        assert config['trafficStats']['secret'] != config['auth']['password']
        assert not list((root / 'conf').glob('.configure.*')), 'staging directory leaked'
        connect(cert, 'helloworld.com')
        if mode == 'brutal':
            shell('configureRealtimeMonitor enable')
            shell('configureSocks5Outbound custom 127.0.0.1:1080; '
                  'updateACLRule add blocked.example.com reject; '
                  'addOrUpdateYaml "$HIHY_CONFIG_FILE" resolver.type udp string; '
                  'addOrUpdateYaml "$HIHY_CONFIG_FILE" resolver.udp.addr 127.0.0.1:5353 string; '
                  'addOrUpdateYaml "$HIHY_CONFIG_FILE" sniff.timeout 3s string')
            retained_outbounds = yaml(root / 'conf/config.yaml')['outbounds']

    # Let the real core parse and re-export a native URI; ranges must survive.
    shell('addOrUpdateYaml "$HIHY_BACKUP_FILE" portHoppingStatus true bool; '
          'addOrUpdateYaml "$HIHY_BACKUP_FILE" portHoppingStart 47000 number; '
          'addOrUpdateYaml "$HIHY_BACKUP_FILE" portHoppingEnd 48000 number; '
          'generate_client_config >/dev/null; printf "%s" "$native_url" > "$HIHY_ROOT_DIR/native-uri"')
    uri = (root / 'native-uri').read_text()
    uri_config = root / 'uri.json'
    uri_config.write_text(json.dumps({'server': uri}))
    shared = subprocess.check_output([str(core), '--disable-update-check', '-c', str(uri_config), 'share'], text=True)
    assert ',47000-48000/' in shared, shared
    shell('addOrUpdateYaml "$HIHY_BACKUP_FILE" portHoppingStatus false bool')

    cert, key = certificate('shared', '*.example.com')
    shell('publishSharedCertificate "$HIHY_ROOT_DIR/shared.crt" "$HIHY_ROOT_DIR/shared.key" example.com; '
          'migrateLocalHysteriaToSharedCertificate example.com node.example.com')
    connect(cert, 'node.example.com')
    print('PASS: real Brutal/BBR/Reno and low-bandwidth handshakes, ACL/outbound retention, '
          'input before stop, snapshots, native URI and certificate migration')
