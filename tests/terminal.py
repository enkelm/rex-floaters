"""Bidirectional real PTY transport for the Lua test harness; no assertions live here."""
import fcntl
import os
import pty
import select
import signal
import struct
import sys
import termios

pid, fd = pty.fork()
if pid == 0:
    os.environ['TERM'] = 'xterm-256color'
    os.execvp(sys.argv[1], sys.argv[1:])

def resize(rows, columns):
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', rows, columns, 0, 0))

def stop(*_):
    try:
        os.kill(pid, signal.SIGHUP)
    except ProcessLookupError:
        pass

rows = int(os.environ.get('REX_TEST_ROWS', '40'))
columns = int(os.environ.get('REX_TEST_COLUMNS', '150'))
resize(rows, columns)
signal.signal(signal.SIGUSR1, lambda *_: resize(
    int(os.environ.get('REX_TEST_NARROW_ROWS', '12')),
    int(os.environ.get('REX_TEST_NARROW_COLUMNS', '48'))))
signal.signal(signal.SIGUSR2, lambda *_: resize(rows, columns))
signal.signal(signal.SIGTERM, stop)
inputs = [fd, 0]
try:
    while True:
        ready, _, _ = select.select(inputs, [], [], .1)
        if fd in ready:
            try:
                data = os.read(fd, 65536)
            except OSError:
                break
            if not data:
                break
            # Only synthetic fixture output is persisted; production captures never use this helper.
            with open(os.environ['REX_TEST_PTY_OUTPUT'], 'ab', buffering=0) as transcript:
                transcript.write(data)
        if 0 in ready:
            data = os.read(0, 4096)
            if data:
                os.write(fd, data)
            else:
                inputs.remove(0)
finally:
    _, status = os.waitpid(pid, 0)
    attrs = termios.tcgetattr(fd)
    restored = bool(attrs[3] & termios.ICANON and attrs[3] & termios.ECHO)
    with open(os.environ['REX_TEST_PTY_OUTPUT'], 'ab', buffering=0) as transcript:
        transcript.write(('\nPTY_RESTORED=' + str(restored) + '\n').encode())
os._exit(os.waitstatus_to_exitcode(status))
