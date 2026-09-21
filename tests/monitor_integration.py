#!/usr/bin/env python3
"""Monitor API/authentication regression and optional real-core loopback test.

Usage: python3 tests/monitor_integration.py [/path/to/hysteria]
Only temporary files and loopback listeners are used; host services are mocked.
"""
import copy
import datetime as dt
import http.server
import json
import os
import pty
import select
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import termios
import threading
import time

repo = Path(__file__).resolve().parents[1]
script = repo / 'server/hy2.sh'
code = script.read_text().split("<<'HIHY_MONITOR_PY'\n", 1)[1].split('\nHIHY_MONITOR_PY', 1)[0]
module = {'__name__': 'monitor_test'}
exec(compile(code, str(script), 'exec'), module)


def port(kind=socket.SOCK_STREAM):
    with socket.socket(type=kind) as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def stream(ip, connection, up=1024, down=4096):
    return dict(auth='hihy-ip:' + ip, connection=connection, stream=4, tx=up, rx=down,
                req_addr='203.0.113.8:443', hooked_req_addr='example.com:443', state='estab',
                initial_at='2026-09-21T01:00:00.123456789Z', last_active_at='2026-09-21T01:00:02Z')


first = ({'hihy-ip:192.0.2.1': {'tx': 2048, 'rx': 8192},
          'hihy-ip:2001:db8::1': {'tx': 512, 'rx': 256}},
         {'hihy-ip:192.0.2.1': 2, 'hihy-ip:2001:db8::1': 1},
         [stream('192.0.2.1', 1), stream('192.0.2.1', 2), stream('2001:db8::1', 3)])
monitor = module['Monitor']()
now = dt.datetime(2026, 9, 21, 1, 0, 4, tzinfo=dt.timezone.utc)
output = '\n'.join(monitor.render(first, now, 10))
assert '在线来源 IP: 2  客户端连接: 3  活动 TCP: 3' in output, output
assert 'example.com:443' in output and '203.0.113.8:443' in output
assert '累计上传: 2.0KiB  下载: 8.0KiB' in output
second = copy.deepcopy(first)
second[0]['hihy-ip:192.0.2.1'] = {'tx': 4096, 'rx': 16384}
output = '\n'.join(monitor.render(second, now, 12))
assert '↑1.0KiB/s  ↓4.0KiB/s' in output, output
output = '\n'.join(monitor.render(first, now, 14))
assert '↑0.0B/s' in output and '↑-' not in output, output
output = '\n'.join(monitor.render((first[0], {}, []), now, 16))
assert '已结束(采样)' in output and '在线来源 IP: 0' in output
assert '离线' in output
assert module['client_ip']('user') is None
assert module['client_ip']('hihy-ip:::ffff:192.0.2.1') == '192.0.2.1'
assert '\x1b' not in module['clean']('\x1b[2Jexample.com\n')
assert ''.join(module['wrap'](['网站example.com'], 6)) == '网站example.com'
for host in ['198.51.100.1:8000', 'evil.example:80', '127.0.0.1:0']:
    try:
        module['API']({'listen': host})
    except ValueError:
        pass
    else:
        raise AssertionError('accepted remote/invalid API: ' + host)
for index in range(510):
    monitor.render(({}, {}, [stream('192.0.2.1', index)]), now, index + 20)
assert len(monitor.recent) == 500


with tempfile.TemporaryDirectory(prefix='hihy-monitor-test-') as temporary:
    root = Path(temporary)
    (root / 'conf').mkdir()
    (root / 'bin').mkdir()
    config_file = root / 'conf/config.yaml'
    backup_file = root / 'conf/backup.yaml'
    state_file = root / 'service-state'
    state_file.write_text('running')
    helper = root / 'bin/monitor-auth'
    secret = 'API-only-密钥'
    wire_secret = secret.encode('utf-8').decode('latin-1')
    password = 'test "密码" \\ with spaces\n\n'
    env = dict(os.environ, HIHY_ROOT_DIR=str(root), HIHY_BIN_LINK=str(root / 'hihy'),
               HIHY_SERVICE_FILE=str(root / 'service'), HIHY_LEGACY_SERVICE=str(root / 'legacy'),
               HIHY_INIT_SERVICE=str(root / 'init'), HIHY_RC_LOCAL=str(root / 'rc.local'),
               HIHY_PID_FILE=str(root / 'pid'))

    def shell(command, check=True, extra_env=None):
        guards = '''
source "$1"
install() { echo 'unexpected installation' >&2; exit 90; }
serviceIsActive() { [ "$(cat "$HIHY_ROOT_DIR/service-state")" = running ]; }
serviceRestart() {
    printf 'restart\n' >> "$HIHY_ROOT_DIR/restarts"
    [ "${FAIL_MONITOR_RESTART:-}" != yes ] || [ "$(getYamlValue "$HIHY_CONFIG_FILE" auth.type)" = password ]
}
waitHihyServiceHealthy() { return 0; }
for unsafe in systemctl rc-service rc-update nft iptables ip6tables sysctl curl wget apt apk crontab; do
    eval "$unsafe() { echo 'unexpected host command: $unsafe' >&2; exit 90; }"
done
'''
        result = subprocess.run(['bash', '-c', guards + command, 'monitor-test', str(script)],
                                env=dict(env, **(extra_env or {})), text=True, capture_output=True, timeout=30)
        if check and result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        return result

    requests = []
    response_mode = 'normal'

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            requests.append((self.path, self.headers.get('Authorization')))
            if self.headers.get('Authorization') != wire_secret or response_mode == 'unauthorized':
                self.send_error(401)
                return
            if response_mode == 'missing':
                self.send_error(404)
                return
            if response_mode == 'redirect':
                self.send_response(302)
                self.send_header('Location', '/forbidden')
                self.end_headers()
                return
            self.send_response(200)
            self.end_headers()
            value = {'/traffic': first[0], '/online': first[1], '/dump/streams': {'streams': first[2]}}[self.path]
            self.wfile.write(b'not JSON' if response_mode == 'malformed' else json.dumps(value).encode())

    api_server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=api_server.serve_forever, daemon=True).start()
    config = dict(auth=dict(type='password', password=password),
                  trafficStats=dict(listen=f'127.0.0.1:{api_server.server_port}', secret=secret))
    config_file.write_text(json.dumps(config))
    backup_file.write_text('trafficPort: 1\n')  # Deliberately stale, must be ignored.
    original_config = config_file.read_bytes()
    original_backup = backup_file.read_bytes()
    try:
        result = shell('realtimeMonitor --once', check=False)
        assert result.returncode and config_file.read_bytes() == original_config
        result = shell('configureRealtimeMonitor enable', check=False, extra_env={'FAIL_MONITOR_RESTART': 'yes'})
        assert result.returncode, result.stdout
        assert config_file.read_bytes() == original_config and backup_file.read_bytes() == original_backup
        shell('configureRealtimeMonitor enable')
        assert helper.stat().st_mode & 0o777 == 0o700
        assert json.loads(shell('yq -o=json .auth.password "$HIHY_CONFIG_FILE"').stdout) == password
        for address, identity in [('192.0.2.1:1000', 'hihy-ip:192.0.2.1'),
                                  ('[2001:db8::1]:2000', 'hihy-ip:2001:db8::1')]:
            auth = subprocess.run([str(helper), address, password, '0'], text=True, capture_output=True)
            assert auth.returncode == 0 and auth.stdout.strip() == identity, auth
        auth = subprocess.run([str(helper), '192.0.2.1:1000', 'incorrect', '0'], capture_output=True)
        assert auth.returncode and not auth.stdout
        # Environment proxies must not receive the API credential or interfere with loopback.
        result = shell('realtimeMonitor --once', extra_env={'http_proxy': 'http://127.0.0.1:1', 'no_proxy': ''})
        assert '在线来源 IP: 2' in result.stdout and 'example.com:443' in result.stdout, result
        assert password not in result.stdout and secret not in result.stdout
        assert all(auth == wire_secret and '?' not in path for path, auth in requests), requests
        for response_mode in ('unauthorized', 'missing', 'malformed', 'redirect'):
            result = shell('realtimeMonitor --once', check=False)
            assert result.returncode and 'Traceback' not in result.stderr, result
            assert secret not in result.stdout + result.stderr
        assert not any(path == '/forbidden' for path, _ in requests)
        response_mode = 'normal'
        # Use a controlling terminal to exercise refresh, scrolling, q and terminal restoration.
        pid, terminal = pty.fork()
        if pid == 0:
            os.execvpe('bash', ['bash', '-c', 'source "$1"; realtimeMonitor', 'monitor-tty', str(script)],
                       dict(env, HIHY_MONITOR_INTERVAL='1'))
        initial_settings = termios.tcgetattr(terminal)
        terminal_output = b''
        try:
            deadline = time.monotonic() + 10
            while 'q 退出'.encode() not in terminal_output:
                assert time.monotonic() < deadline, terminal_output
                if select.select([terminal], [], [], .2)[0]:
                    terminal_output += os.read(terminal, 65536)
            os.write(terminal, b'j')
            os.write(terminal, b'q')
            while True:
                waited, status = os.waitpid(pid, os.WNOHANG)
                if waited:
                    assert os.waitstatus_to_exitcode(status) == 0
                    pid = None
                    break
                assert time.monotonic() < deadline, 'monitor failed to exit on q'
                if select.select([terminal], [], [], .1)[0]:
                    try:
                        terminal_output += os.read(terminal, 65536)
                    except OSError:
                        pass
            assert termios.tcgetattr(terminal) == initial_settings
            assert b'\x1b[?25h\x1b[?1049l' in terminal_output
        finally:
            if pid:
                os.kill(pid, 9)
                os.waitpid(pid, 0)
            os.close(terminal)
        result = shell('realtimeMonitor --once', check=False, extra_env={'HIHY_MONITOR_INTERVAL': 'nan'})
        assert result.returncode and '刷新间隔' in result.stdout
        state_file.write_text('stopped')
        restarts = (root / 'restarts').read_bytes()
        shell('configureRealtimeMonitor disable')
        assert (root / 'restarts').read_bytes() == restarts
        assert shell('getYamlValue "$HIHY_CONFIG_FILE" auth.type').stdout.strip() == 'password'
        # Older installations without an API get a local listener and a separate secret.
        config_file.write_text(json.dumps(dict(auth=dict(type='password', password=password))))
        shell('configureRealtimeMonitor enable')
        api_config = json.loads(shell('yq -o=json .trafficStats "$HIHY_CONFIG_FILE"').stdout)
        assert api_config['listen'].startswith('127.0.0.1:') and api_config['secret']
        assert api_config['secret'] != password
        helper.unlink()
        shell('configureRealtimeMonitor enable')
        assert os.access(helper, os.X_OK), 'missing authenticator was not repaired'
        shell('configureRealtimeMonitor disable')
        config['auth'] = dict(type='http', http=dict(url='http://127.0.0.1:1'))
        config_file.write_text(json.dumps(config))
        result = shell('configureRealtimeMonitor enable', check=False)
        assert result.returncode and '不会覆盖自定义认证' in result.stdout
        assert json.loads(config_file.read_text())['auth']['type'] == 'http'
    finally:
        api_server.shutdown()
        api_server.server_close()

    if len(sys.argv) > 1:
        # HTTP authentication headers cannot contain literal newlines.
        password = password.rstrip('\n')
        core = str(Path(sys.argv[1]).resolve())
        cert, key = root / 'cert.pem', root / 'key.pem'
        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
                        '-subj', '/CN=localhost', '-keyout', str(key), '-out', str(cert)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        server_port, socks_port, stats_port = port(socket.SOCK_DGRAM), port(), port()
        config = dict(listen=f'127.0.0.1:{server_port}', tls=dict(cert=str(cert), key=str(key)),
                      auth=dict(type='password', password=password),
                      trafficStats=dict(listen=f'127.0.0.1:{stats_port}', secret=secret))
        config_file.write_text(json.dumps(config))
        shell('configureRealtimeMonitor enable')
        client_file = root / 'client.json'
        client_file.write_text(json.dumps(dict(server=f'127.0.0.1:{server_port}', auth=password,
                                               tls=dict(insecure=True),
                                               socks5=dict(listen=f'127.0.0.1:{socks_port}'))))
        target = socket.socket()
        target.bind(('127.0.0.1', 0))
        target.listen()
        target.settimeout(10)
        proxy = remote = None
        with (root / 'server.log').open('w+') as server_log, (root / 'client.log').open('w+') as client_log:
            server = subprocess.Popen([core, '--disable-update-check', '-c', str(config_file), 'server'], stdout=server_log, stderr=server_log)
            client = subprocess.Popen([core, '--disable-update-check', '-c', str(client_file), 'client'], stdout=client_log, stderr=client_log)
            try:
                deadline = time.monotonic() + 10
                while True:
                    try:
                        proxy = socket.create_connection(('127.0.0.1', socks_port), timeout=1)
                        break
                    except OSError:
                        if time.monotonic() > deadline:
                            raise AssertionError('client failed to listen')
                        time.sleep(.1)
                proxy.settimeout(10)
                proxy.sendall(b'\x05\x01\x00')
                assert proxy.recv(2) == b'\x05\x00'
                proxy.sendall(b'\x05\x01\x00\x01' + socket.inet_aton('127.0.0.1')
                              + target.getsockname()[1].to_bytes(2, 'big'))
                reply = proxy.recv(10)
                assert reply[:2] == b'\x05\x00', reply
                remote, _ = target.accept()
                remote.settimeout(10)
                proxy.sendall(b'U' * 2048)
                received = b''
                while len(received) < 2048:
                    received += remote.recv(2048)
                remote.sendall(b'D' * 8192)
                received = b''
                while len(received) < 8192:
                    received += proxy.recv(8192)
                result = shell('realtimeMonitor --once')
                assert '在线来源 IP: 1' in result.stdout and '127.0.0.1 → 127.0.0.1:' in result.stdout, result.stdout
                assert '累计上传: 2.0KiB  下载: 8.0KiB' in result.stdout, result.stdout
                assert '已建立' in result.stdout and '开始:' in result.stdout, result.stdout
            except Exception:
                server_log.seek(0)
                client_log.seek(0)
                # Authentication test credentials are local fixtures only.
                print(server_log.read() + client_log.read(), file=sys.stderr)
                raise
            finally:
                for connection in (proxy, remote, target):
                    if connection:
                        connection.close()
                for process in (client, server):
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()

print('PASS: IP attribution, traffic/rates/history, API failures, credentials, auth rollback'
      + (', real-core SOCKS traffic' if len(sys.argv) > 1 else ''))
