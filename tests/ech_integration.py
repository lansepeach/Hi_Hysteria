#!/usr/bin/env python3
"""Loopback-only ECH integration test. Usage: python3 tests/ech_integration.py /path/to/hysteria
Requires yq v4 and openssl. Does not change the installed service.
Set HIHY_TEST_UDP_PORT to a free port outside any existing NAT/port-hopping rules.
"""
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import time
from urllib.parse import parse_qs

repo = Path(__file__).resolve().parents[1]
core = Path(sys.argv[1]).resolve()
processes = []
logs = []


def port(sock_type):
    with socket.socket(type=sock_type) as sock:
        requested = int(os.environ.get('HIHY_TEST_UDP_PORT', '0')) if sock_type == socket.SOCK_DGRAM else 0
        sock.bind(('127.0.0.1', requested))
        return sock.getsockname()[1]


def shell(code, *args, input=None):
    return subprocess.run(['bash', '-c', 'source "$1"; ' + code,
                           'ech-test', str(repo / 'server/hy2.sh'), *map(str, args)],
                          env=env, input=input, text=True, check=True,
                          capture_output=True).stdout.strip()


def launch(config, mode, name):
    log = open(root / f'{name}.log', 'w+')
    logs.append(log)
    proc = subprocess.Popen([str(core), '--disable-update-check', '-c', str(config), mode], stdout=log, stderr=log)
    processes.append(proc)
    return proc, log


def read_exact(conn, size):
    data = b''
    while len(data) < size:
        chunk = conn.recv(size - len(data))
        if not chunk:
            raise AssertionError('unexpected EOF')
        data += chunk
    return data


with tempfile.TemporaryDirectory(prefix='hihy-ech-test-') as temporary:
    root = Path(temporary)
    (root / 'bin').mkdir()
    (root / 'bin/appS').symlink_to(core)
    env = dict(os.environ, HIHY_ROOT_DIR=str(root))
    try:
        # Exercise the script's actual generation path and preserve existing keys.
        shell('prepareECH ""', input='2\ndecoy.example.com\n')
        key = root / 'cert/ech.pem'
        before = hashlib.sha256(key.read_bytes()).digest()
        shell('prepareECH "$2"', key, input='\n')
        assert before == hashlib.sha256(key.read_bytes()).digest()
        assert key.stat().st_mode & 0o777 == 0o600
        public = shell('getECHConfigList "$2"', key)
        query = shell('encodeECHQuery "$2"', public)
        assert parse_qs('ech=' + query)['ech'] == [public]

        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                        '-keyout', str(root / 'tls.key'), '-out', str(root / 'tls.crt'),
                        '-subj', '/CN=real.example.com', '-addext', 'subjectAltName=DNS:real.example.com',
                        '-days', '1'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        udp_port = port(socket.SOCK_DGRAM)
        socks_port = port(socket.SOCK_STREAM)
        server_file = root / 'server.yaml'
        server_file.write_text(json.dumps({
            'listen': f'127.0.0.1:{udp_port}',
            'tls': {'cert': str(root / 'tls.crt'), 'key': str(root / 'tls.key'), 'sniGuard': 'strict'},
            'auth': {'type': 'password', 'password': 'local-integration-only'},
            'ech': {'keyPath': str(key)},
        }))
        client = {
            'server': f'127.0.0.1:{udp_port}', 'auth': 'local-integration-only',
            'tls': {'sni': 'real.example.com', 'insecure': True},
            'socks5': {'listen': f'127.0.0.1:{socks_port}'},
        }
        client_file = root / 'client.yaml'
        client_file.write_text(json.dumps(client))
        shell('exportClientECH "$2" "$3"', server_file, client_file)
        exported = json.loads(subprocess.check_output(['yq', '-o=json', '.', str(client_file)]))
        assert exported['tls']['ech'] == public
        assert 'ECH KEYS' not in client_file.read_text()
        server_proc, _ = launch(server_file, 'server', 'server')
        time.sleep(0.5)
        assert server_proc.poll() is None
        client_proc, _ = launch(client_file, 'client', 'client')
        deadline = time.monotonic() + 10
        while True:
            try:
                conn = socket.create_connection(('127.0.0.1', socks_port), timeout=2)
                break
            except OSError:
                assert client_proc.poll() is None, 'client failed to start'
                if time.monotonic() >= deadline:
                    raise
                time.sleep(0.1)
        with socket.socket() as target:
            target.bind(('127.0.0.1', 0))
            target.listen()
            target.settimeout(5)
            target_port = target.getsockname()[1]

            def echo():
                peer, _ = target.accept()
                with peer:
                    peer.settimeout(5)
                    peer.sendall(peer.recv(1024))

            worker = threading.Thread(target=echo)
            worker.start()
            with conn:
                conn.settimeout(5)
                conn.sendall(b'\x05\x01\x00')
                assert read_exact(conn, 2) == b'\x05\x00'
                conn.sendall(b'\x05\x01\x00\x01' + socket.inet_aton('127.0.0.1') + target_port.to_bytes(2, 'big'))
                response = read_exact(conn, 4)
                assert response[:2] == b'\x05\x00', response
                length = {1: 4, 4: 16}[response[3]]
                read_exact(conn, length + 2)
                conn.sendall(b'ECH loopback verified')
                assert read_exact(conn, 21) == b'ECH loopback verified'
            worker.join(timeout=6)
            assert not worker.is_alive()

        # Standard TLS reports ECHAccepted directly. The 2.12.3 ChromeParrot
        # adapter omits that field when copying connection state (logs say false).
        standard = dict(client, tls=dict(client['tls'], ech=public),
                        quic={'disableChromeParrot': True},
                        socks5={'listen': f'127.0.0.1:{port(socket.SOCK_STREAM)}'})
        standard_file = root / 'standard.yaml'
        standard_file.write_text(json.dumps(standard))
        standard_proc, standard_log = launch(standard_file, 'client', 'standard-client')
        deadline = time.monotonic() + 8
        while True:
            standard_log.seek(0)
            if '"ech": true' in standard_log.read():
                break
            assert standard_proc.poll() is None, 'standard ECH handshake failed'
            assert time.monotonic() < deadline, 'ECH acceptance was not reported'
            time.sleep(0.1)

        # A mismatched public configuration must fail even with insecure=true.
        subprocess.run([str(core), 'ech', '--public-name', 'other.example.com',
                        '--output', str(root / 'other.pem')], check=True, stdout=subprocess.DEVNULL)
        client['tls']['ech'] = shell('getECHConfigList "$2"', root / 'other.pem')
        client['socks5']['listen'] = f'127.0.0.1:{port(socket.SOCK_STREAM)}'
        bad_file = root / 'bad.yaml'
        bad_file.write_text(json.dumps(client))
        bad_proc, bad_log = launch(bad_file, 'client', 'bad-client')
        assert bad_proc.wait(timeout=10) != 0, 'mismatched ECH accepted'
        bad_log.seek(0)
        assert 'failed to initialize client' in bad_log.read()
        print('PASS: real ECH generation, key reuse, export, URI encoding, tunnel traffic, fail-closed')
    except Exception:
        for log in logs:
            log.flush()
            log.seek(0)
            print(log.name, log.read(), file=sys.stderr)
        raise
    finally:
        for proc in reversed(processes):
            if proc.poll() is None:
                proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
        for log in logs:
            log.close()
