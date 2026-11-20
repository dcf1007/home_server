#!/usr/bin/env python3
"""Sequential test of home_server's zram-pressure.service. Disposable VM only.
Run: sudo python3 test_zram.py
No package installation, service changes, swapoff, or writes to ZRAM sysfs.
Internal worker modes are launched only by the controller in transient units.
"""
import hashlib
import json
import mmap
import os
from pathlib import Path
import queue
import re
import signal
import subprocess
import sys
import threading
import time
import uuid

MIB = 1024**2
Z = Path('/sys/block/zram0')
SERVICE = 'zram-pressure.service'
NORMAL_SECONDS = 360
EMERGENCY_SECONDS = 240
READBACK_SECONDS = 180
AGE_SECONDS = 65
POLL = 1.0
PAGE = os.sysconf('SC_PAGE_SIZE')
# Linux UAPI values: Python builds do not always export these constants.
MADV_COLD = getattr(mmap, 'MADV_COLD', 20)
MADV_PAGEOUT = getattr(mmap, 'MADV_PAGEOUT', 21)
START = time.monotonic()


class Inconclusive(Exception):
    pass


class Failure(Exception):
    pass


def say(message):
    print(f'[{time.monotonic()-START:6.1f}s] {message}', flush=True)


def run(*args, timeout=10, check=True):
    return subprocess.run(args, text=True, capture_output=True, timeout=timeout,
                          check=check)


def fields(path):
    return [int(x) for x in Path(path).read_text().split()]


def meminfo():
    return {s.split(':')[0]: int(s.split()[1])*1024
            for s in Path('/proc/meminfo').read_text().splitlines()
            if s.endswith(' kB')}


def swaps():
    items = []
    for line in Path('/proc/swaps').read_text().splitlines()[1:]:
        name, _, size, used, priority = line.split()
        items.append((os.path.realpath(name), int(size)*1024,
                      int(used)*1024, int(priority)))
    return items


def service_identity():
    out = run('systemctl', 'show', SERVICE, '-p', 'ActiveState', '-p',
              'InvocationID', '-p', 'NRestarts').stdout
    data = dict(line.split('=', 1) for line in out.splitlines() if '=' in line)
    if data.get('ActiveState') != 'active' or not data.get('InvocationID'):
        raise Failure(f'{SERVICE} is not active: {data}')
    return data['InvocationID'], data.get('NRestarts')


def snapshot():
    original, compressed, used, limit, *_ = fields(Z/'mm_stat')
    backing, reads, writes, *_ = fields(Z/'bd_stat')
    errors = tuple(fields(Z/'io_stat')[:2])
    if limit <= 0:
        raise Failure('ZRAM resident limit is zero or was removed')
    psi = re.search(r'^some avg10=(\d+\.\d+)',
                    Path('/proc/pressure/memory').read_text(), re.M)
    if not psi:
        raise Failure('System memory PSI unavailable')
    swap = next((x for x in swaps() if x[0] == '/dev/zram0'), None)
    if swap is None:
        raise Failure('/dev/zram0 is no longer active swap')
    return dict(original=original, compressed=compressed, used=used,
                limit=limit, occupancy=used*100//limit, psi=float(psi[1]),
                backing=backing, reads=reads, writes=writes, errors=errors,
                available=meminfo()['MemAvailable'], swap_used=swap[2],
                swap_free=swap[1]-swap[2])


class Journal:
    def __init__(self):
        self.since = f'@{time.time():.6f}'
        self.cursor = None
        self.messages = []
        self.cycles = []
        self.pending = None

    def poll(self):
        position = (['--after-cursor', self.cursor] if self.cursor else
                    ['--since', self.since])
        out = run('journalctl', '-b', '-u', SERVICE, '--no-pager',
                  '-o', 'json', *position).stdout
        for line in out.splitlines():
            if not line.startswith('{'):
                continue
            entry = json.loads(line)
            self.cursor = entry['__CURSOR']
            msg = entry.get('MESSAGE', '')
            if not isinstance(msg, str):
                continue
            self.messages.append(msg)
            say('SERVICE | '+msg)
            if 'writeback failed' in msg.lower() or 'cannot read psi/zram' in msg.lower():
                raise Failure('Service reported an error: '+msg)
            match = re.fullmatch(r'Writeback triggered: zram=(\d+)% PSI=(\d+)bp', msg)
            if match:
                self.pending = dict(index=len(self.messages)-1,
                                    occ=int(match[1]), psi=int(match[2]),
                                    emergency=False, ages=[], delta=None)
            elif self.pending is not None:
                if msg == 'Emergency writeback: all remaining eligible entries':
                    self.pending['emergency'] = True
                age = re.fullmatch(r'Writeback completed: age=(\d+)s', msg)
                if age:
                    self.pending['ages'].append(int(age[1]))
                end = re.fullmatch(r'Cycle complete; backing writes delta=(-?\d+)', msg)
                if end:
                    self.pending['delta'] = int(end[1])
                    self.cycles.append(self.pending)
                    self.pending = None


def private_mapping(length):
    return mmap.mmap(-1, length, flags=mmap.MAP_PRIVATE | mmap.MAP_ANONYMOUS,
                     prot=mmap.PROT_READ | mmap.PROT_WRITE)


def cold_worker():
    """Keep mappings untouched until ordered verification and release."""
    blocks = []
    def reply(**data):
        print('ZTEST '+json.dumps(data), flush=True)
    reply(ready=True)
    for line in sys.stdin:
        command = json.loads(line)
        if command['op'] == 'alloc':
            n = command['n']
            m = private_mapping(n)
            # Each page is 75% random, 25% zero, not a same-element page.
            # The random bytes are different for each page and allocation.
            try:
                random_bytes = os.urandom(n//4*3)
                span = PAGE//4*3
                for i in range(n//PAGE):
                    m[i*PAGE:i*PAGE+span] = random_bytes[i*span:(i+1)*span]
                del random_bytes
                digest = hashlib.sha256(m).hexdigest()
                m.madvise(MADV_COLD)
                m.madvise(MADV_PAGEOUT)
                blocks.append((m, digest, n))
            except BaseException:
                m.close()
                raise
            reply(allocated=n)
        elif command['op'] == 'verify':
            if not blocks:
                reply(done=True)
                continue
            m, expected, n = blocks.pop(0)
            actual = hashlib.sha256(m).hexdigest()
            m.close()
            reply(verified=n, match=actual == expected)
        elif command['op'] == 'exit':
            break
        else:
            raise ValueError('Invalid internal command')
    for m, _, _ in blocks:
        m.close()


def hot_worker(n):
    """A separate cgroup's memory.high induces real reclaim stalls."""
    m = private_mapping(n)
    # Nonuniform random data; touch all pages continuously.
    for offset in range(0, n, PAGE):
        m[offset:offset+PAGE] = os.urandom(PAGE)
    while True:
        for offset in range(0, n, PAGE):
            m[offset] = (m[offset]+1) % 256


class Worker:
    def __init__(self, units, mode, resident, swap, n=None, high=None):
        self.unit = f'zram-test-{mode}-{uuid.uuid4().hex[:12]}.service'
        units.append(self.unit)  # Register before launch, including failed starts.
        cmd = ['systemd-run', '--quiet', '--wait', '--pipe', '--collect',
               '--unit='+self.unit, '-p', 'MemoryAccounting=yes',
               '-p', f'MemoryMax={resident}', '-p', f'MemorySwapMax={swap}',
               '-p', 'OOMPolicy=stop', '-p', 'RuntimeMaxSec=900s',
               '-p', 'TimeoutStopSec=5s']
        if high is not None:
            cmd += ['-p', f'MemoryHigh={high}']
        cmd += [sys.executable, '-u', str(Path(__file__).resolve()), '--'+mode+'-worker']
        if n is not None:
            cmd.append(str(n))
        self.proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     text=True, bufsize=1)
        self.messages = queue.Queue()
        def reader():
            for line in self.proc.stdout:
                if line.startswith('ZTEST '):
                    try:
                        self.messages.put(json.loads(line[6:]))
                    except ValueError:
                        self.messages.put({'error': line.rstrip()})
                else:
                    say('WORKER | '+line.rstrip())
        self.thread = threading.Thread(target=reader, daemon=True)
        self.thread.start()

    def check(self):
        if self.proc.poll() is not None:
            raise Failure(f'{self.unit} exited unexpectedly ({self.proc.returncode})')

    def send(self, **command):
        self.check()
        self.proc.stdin.write(json.dumps(command)+'\n')
        self.proc.stdin.flush()

    def stop(self):
        result = run('systemctl', 'stop', self.unit, timeout=15, check=False)
        if self.proc.poll() is None:
            try:
                self.proc.wait(timeout=8)
            except subprocess.TimeoutExpired:
                self.proc.terminate()
                try:
                    self.proc.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    self.proc.kill()
                    self.proc.wait(timeout=3)
        state = run('systemctl', 'show', self.unit, '-p', 'ActiveState',
                    '--value', check=False).stdout.strip()
        if state not in ('inactive', 'failed') and state != '':
            raise Failure(f'Cleanup could not confirm stopped unit {self.unit}: {state}')
        if result.returncode and state not in ('inactive', 'failed'):
            # A collected unit is absent; distinguish that from a bus error.
            if not any(s in result.stderr.lower() for s in ('not loaded', 'not found')):
                raise Failure(f'Cleanup of {self.unit}: {result.stderr.strip()}')


class Test:
    def __init__(self):
        self.units = []
        self.workers = []
        self.cold = None
        self.hot = None
        self.journal = Journal()
        self.total = 0
        self.verified = 0
        self.phase = 'PREFLIGHT'
        self.last_display = 0
        self.last_check = 0
        self.deadline = time.monotonic()+30
        self.results = {}

    def preflight(self):
        if os.geteuid() != 0:
            raise Failure('Run with sudo python3 test_zram.py')
        if not Path('/sys/fs/cgroup/cgroup.controllers').is_file():
            raise Failure('cgroup v2 is required')
        if not {'memory'} <= set(Path('/sys/fs/cgroup/cgroup.controllers').read_text().split()):
            raise Failure('cgroup memory controller is unavailable')
        if sys.platform != 'linux' or not hasattr(mmap.mmap, 'madvise'):
            raise Failure('Linux Python mmap.madvise is required')
        for name in ('idle', 'writeback', 'mm_stat', 'bd_stat', 'io_stat'):
            if not (Z/name).exists():
                raise Failure(f'Missing {Z/name}')
        if (Z/'compressed_writeback').read_text().strip() != '1':
            raise Failure('Compressed writeback is not enabled')
        if (Z/'writeback_limit_enable').read_text().strip() != '0':
            raise Failure('Writeback limit is enabled; no configuration changed')
        backing = (Z/'backing_dev').read_text().strip()
        if backing in ('', 'none', '[none]'):
            raise Failure('No backing device configured')
        entries = swaps()
        zswap = Path('/sys/module/zswap/parameters/enabled')
        if zswap.exists() and zswap.read_text().strip().lower() in ('y', '1', 'yes'):
            raise Failure('zswap is enabled and can intercept the intended workload')
        z = next((x for x in entries if x[0] == '/dev/zram0'), None)
        if z is None:
            raise Failure('zram0 is not active swap')
        if any(x[0] != z[0] and x[3] >= z[3] for x in entries):
            raise Inconclusive('Another swap has equal/higher priority; cannot isolate zram0')
        if os.path.realpath(backing) in [x[0] for x in entries]:
            raise Failure('Backing device is also active ordinary swap')
        self.identity = service_identity()
        self.base = snapshot()
        s = self.base
        ram = meminfo()['MemTotal']
        # Reserve other system memory and swap. Bounded test-only allocation.
        self.reserve = max(128*MIB, ram//16)
        self.resident = min(256*MIB, s['available']//4, ram//8)
        self.hot_size = min(96*MIB, max(16*MIB, s['limit']//25))//PAGE*PAGE
        self.hot_max = self.hot_size+48*MIB
        self.budget = min(s['swap_free']*85//100, s['limit']*3)
        self.budget = self.budget//PAGE*PAGE
        self.chunk = min(32*MIB, max(PAGE, self.resident//8))//PAGE*PAGE
        if s['occupancy'] >= 70:
            raise Inconclusive('Baseline occupancy >=70%; use a quiet VM')
        if self.resident < 64*MIB or s['available'] < self.reserve+self.resident+self.hot_max:
            raise Inconclusive('Insufficient available RAM for bounded worker cgroups')
        if self.budget < s['limit']:
            raise Inconclusive('Insufficient free logical swap for a meaningful run')
        say(f'Kernel={os.uname().release}; backing={backing}; '
            f'RAM={ram/MIB:.0f} MiB; resident limit={s["limit"]/MIB:.0f} MiB')
        say(f'Cold allocation cap={self.budget/MIB:.0f} MiB; cold RAM cap={self.resident/MIB:.0f} MiB; '
            f'hot working set={self.hot_size/MIB:.0f} MiB; reserve={self.reserve/MIB:.0f} MiB')
        say('WARNING: deliberate memory/swap pressure and SSD writes; disposable VM only.')
        self.cold = Worker(self.units, 'cold', self.resident, self.budget)
        self.workers.append(self.cold)
        if not self.receive(self.cold).get('ready'):
            raise Failure('Cold worker did not initialize')

    def tick(self):
        if time.monotonic() >= self.deadline:
            raise Inconclusive(f'{self.phase} timed out')
        s = snapshot()
        if s['limit'] != self.base['limit']:
            raise Failure('ZRAM resident limit changed during test')
        if s['errors'] != self.base['errors']:
            raise Failure(f'ZRAM I/O error counters changed: {self.base["errors"]} -> {s["errors"]}')
        if s['available'] < self.reserve:
            raise Inconclusive('System RAM headroom fell below test reserve')
        for worker in (self.cold, self.hot):
            if worker:
                worker.check()
        if time.monotonic()-self.last_check >= 2:
            if service_identity() != self.identity:
                raise Failure('Pressure monitor restarted during test')
            self.journal.poll()
            self.last_check = time.monotonic()
        if time.monotonic()-self.last_display >= 2:
            say(f'{self.phase:12} occ={s["occupancy"]:3}% '
                f'PSI={s["psi"]:5.2f}% resident={s["used"]/MIB:7.1f}/{s["limit"]/MIB:.1f} MiB '
                f'swap={s["swap_used"]/MIB:.1f} MiB avail={s["available"]/MIB:.0f} MiB '
                f'backing={s["backing"]/256:.1f} MiB '
                f'W+={(s["writes"]-self.base["writes"])/256:.1f} '
                f'R+={(s["reads"]-self.base["reads"])/256:.1f} MiB '
                f'held={(self.total-self.verified)/MIB:.1f} MiB '
                f'verified={self.verified/MIB:.1f} MiB '
                f'left={max(0,self.deadline-time.monotonic()):.0f}s')
            self.last_display = time.monotonic()
        return s

    def receive(self, worker):
        while True:
            self.tick()
            try:
                msg = worker.messages.get(timeout=POLL)
            except queue.Empty:
                continue
            if 'error' in msg:
                raise Failure(msg['error'])
            return msg

    def alloc(self, s, target):
        # Near a threshold, use smaller steps. Never allocate blindly above it.
        gap = max(PAGE, (target*s['limit']//100)-s['used'])
        n = min(self.chunk, max(PAGE, gap//2), self.budget-self.total,
                max(0, s['swap_free']-self.hot_size-32*MIB))//PAGE*PAGE
        if n <= 0:
            return False
        self.cold.send(op='alloc', n=n)
        msg = self.receive(self.cold)
        if msg.get('allocated') != n:
            raise Failure(f'Unexpected allocation reply: {msg}')
        self.total += n
        return True

    def sleep(self, seconds):
        end = time.monotonic()+seconds
        while time.monotonic() < end:
            self.tick()
            time.sleep(min(POLL, max(0, end-time.monotonic())))

    def normal(self):
        self.phase = 'NORMAL'
        self.deadline = time.monotonic()+NORMAL_SECONDS
        self.journal.poll()
        marker = len(self.journal.messages)
        before = snapshot()['writes']
        say('1/3 NORMAL: prefill to 76%, age cold pages for 65s, then apply hot pressure.')
        def passed():
            return any(c['index'] >= marker and 80 <= c['occ'] < 95 and c['psi'] >= 500
                       and not c['emergency'] and c['ages'] and c['delta'] > 0
                       for c in self.journal.cycles)
        while True:
            s = self.tick()
            if s['occupancy'] >= 76:
                break
            if not self.alloc(s, 77):
                raise Inconclusive('Allocation budget exhausted before normal prefill')
        say('Cold pages aging; no test pages are accessed during this interval.')
        self.sleep(AGE_SECONDS)
        try:
            self.hot = Worker(self.units, 'hot', self.hot_max, self.hot_size+16*MIB,
                              n=self.hot_size, high=max(16*MIB, self.hot_size//2))
            self.workers.append(self.hot)
            while True:
                s = self.tick()
                if passed() and s['writes'] > before:
                    say('PASS NORMAL: journal-confirmed normal trigger and positive backing writes.')
                    return
                if s['occupancy'] < 89 and self.alloc(s, 87 if s['occupancy'] < 87 else 90):
                    continue
                time.sleep(POLL)
        finally:
            if self.hot:
                self.hot.stop()
                self.workers.remove(self.hot)
                self.units.remove(self.hot.unit)
                self.hot = None

    def emergency(self):
        self.phase = 'EMERGENCY'
        self.deadline = time.monotonic()+EMERGENCY_SECONDS
        say('2/3 EMERGENCY: stop hot pressure; allow 35s for PSI/retry cooldown.')
        self.sleep(35)
        self.journal.poll()
        marker = len(self.journal.messages)
        before = snapshot()['writes']
        seen_trigger = False
        while True:
            s = self.tick()
            cycles = [c for c in self.journal.cycles if c['index'] >= marker and c['occ'] >= 95]
            if cycles and not seen_trigger:
                say('Emergency threshold observed in service journal; checking all-eligible fallback.')
                seen_trigger = True
            if any(c['emergency'] and c['delta'] > 0 for c in cycles) and s['writes'] > before:
                say('PASS EMERGENCY: >=95% trigger, explicit emergency branch and positive cycle writes.')
                return
            # Keep newly swapped pages young. If old entries reclaim enough first,
            # refill and try again without artificially modifying idle timestamps.
            if s['occupancy'] < 96 and self.alloc(s, 97):
                continue
            time.sleep(POLL)

    def readback(self):
        self.phase = 'READBACK'
        self.deadline = time.monotonic()+READBACK_SECONDS
        before = snapshot()['reads']
        say(f'3/3 READBACK: SHA-256 verify all {self.total/MIB:.1f} MiB of retained cold data.')
        if not self.total:
            raise Inconclusive('No cold data allocated')
        while self.verified < self.total:
            self.cold.send(op='verify')
            msg = self.receive(self.cold)
            if msg.get('match') is not True or not msg.get('verified'):
                raise Failure(f'Cold data checksum mismatch or invalid response: {msg}')
            self.verified += msg['verified']
        s = self.tick()
        if self.verified != self.total:
            raise Failure('Verified byte count does not match allocation')
        if s['reads'] <= before:
            raise Inconclusive('All checksums match, but no new backing-device reads observed')
        say(f'PASS READBACK: all SHA-256 checks passed; backing reads +{(s["reads"]-before)/256:.1f} MiB.')

    def cleanup(self):
        say('CLEANUP: terminating only transient test units; no global swapoff.')
        errors = []
        for worker in reversed(self.workers):
            try:
                worker.stop()
            except Exception as e:
                errors.append(str(e))
        registered = {w.unit for w in self.workers}
        for unit in self.units:
            if unit not in registered:
                try:
                    result = run('systemctl', 'stop', unit, timeout=15, check=False)
                    if result.returncode and 'not loaded' not in result.stderr.lower():
                        errors.append(result.stderr.strip())
                except Exception as e:
                    errors.append(str(e))
        if errors:
            say('Cleanup needs attention: '+'; '.join(errors))
            return False
        say('Transient test units stopped.')
        return True

    def execute(self):
        code = 1
        try:
            self.preflight()
            for name, function in [('NORMAL', self.normal), ('EMERGENCY', self.emergency),
                                   ('READBACK', self.readback)]:
                try:
                    function()
                    self.results[name] = 'PASS'
                except Inconclusive as e:
                    self.results[name] = 'INCONCLUSIVE: '+str(e)
                    say(self.results[name])
                    # A resource-limit/timeout result is not a service failure.
                    # Stop on low available RAM; do not escalate an unsafe workload.
                    if 'headroom' in str(e):
                        break
                except Exception as e:
                    self.results[name] = 'FAIL: '+str(e)
                    raise
            code = 0 if all(self.results.get(x) == 'PASS' for x in ('NORMAL','EMERGENCY','READBACK')) else 2
        except Inconclusive as e:
            say('INCONCLUSIVE: '+str(e))
            code = 2
        except KeyboardInterrupt:
            say('INTERRUPTED: stopping test.')
            code = 130
        except Exception as e:
            say('FAIL: '+str(e))
            code = 1
        finally:
            if not self.cleanup():
                code = 1
            for name in ('NORMAL','EMERGENCY','READBACK'):
                say(f'{name}: {self.results.get(name, "NOT RUN")}')
            if hasattr(self, 'base'):
                try:
                    s = snapshot()
                    say(f'TOTAL: backing writes +{(s["writes"]-self.base["writes"])/256:.1f} MiB; '
                        f'reads +{(s["reads"]-self.base["reads"])/256:.1f} MiB; '
                        f'final resident={s["used"]/MIB:.1f} MiB; '
                        f'verified={self.verified/MIB:.1f} MiB.')
                except Exception as e:
                    say('Final statistics unavailable: '+str(e))
            say(f'Exit status {code} (0=all pass, 1=failure, 2=inconclusive, 130=interrupted)')
        return code


def interrupt(signum, frame):
    raise KeyboardInterrupt


if __name__ == '__main__':
    if sys.argv[1:] == ['--cold-worker']:
        cold_worker()
    elif len(sys.argv) == 3 and sys.argv[1] == '--hot-worker':
        hot_worker(int(sys.argv[2]))
    elif len(sys.argv) == 1:
        signal.signal(signal.SIGTERM, interrupt)
        signal.signal(signal.SIGHUP, interrupt)
        sys.exit(Test().execute())
    else:
        sys.exit('Usage: sudo python3 test_zram.py')
